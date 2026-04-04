import sys
import os

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None

# -----------------------------------------------------------
# 1. 强制设置路径：让 Python 能找到旁边的文件
# -----------------------------------------------------------
base_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(base_dir)
if load_dotenv is not None:
    load_dotenv(os.path.join(base_dir, ".env"))

# 2. 解决潜在的表情符号报错 (顺手加上，防止等会儿又报 Emoji 错)
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
"""
简约课表系统 - 主应用文件
实时爬取教务系统课表并以黑白简约风格展示
"""
from datetime import datetime, timezone

from flask import Flask, jsonify, redirect, render_template, request, url_for

from config import DEBUG, HOST, PORT, SEMESTER_START_DATE
from utils.crawler import login_and_get_schedule
from utils.credential_store import CredentialStore
from utils.crypto import decrypt_password, encrypt_password
from utils.parser import get_current_week, get_next_week, parse_weeks
from utils.token_generator import generate_token

app = Flask(__name__)


DB_PATH_ENV = "KCBPRO_DB_PATH"
PUBLIC_BASE_URL_ENV = "PUBLIC_BASE_URL"
DEFAULT_DB_PATH = os.path.join(base_dir, "kcbpro.db")
credential_store = CredentialStore(os.environ.get(DB_PATH_ENV, DEFAULT_DB_PATH))
credential_store.initialize()


def get_stored_password_for_display(record):
    try:
        return decrypt_password(record["encrypted_password"])
    except Exception:
        return ""


def build_public_timetable_link(token):
    public_base_url = os.environ.get(PUBLIC_BASE_URL_ENV, "").strip().rstrip("/")
    if public_base_url:
        return f"{public_base_url}/t/{token}"
    return url_for("timetable_page", token=token, _external=True)


@app.route('/api/schedule')
def get_schedule_api_placeholder():
    # Task 5 will introduce token-backed schedule API. Keep this endpoint from crashing,
    # but don't implement token logic here.
    return jsonify({"error": "Not implemented. Use /login to get a token."}), 501


@app.route("/api/schedule/<token>")
def get_schedule_api(token):
    record = credential_store.get_record(token)
    if not record:
        return jsonify({"error": "链接无效，请重新登录"}), 404

    password = decrypt_password(record["encrypted_password"])
    data, error = login_and_get_schedule(record["username"], password)
    if error:
        return jsonify({"error": "登录失效，请重新登录"}), 400

    credential_store.touch_record(token, datetime.now(timezone.utc).isoformat())
    semester_start_date = record.get("semester_start_date") or SEMESTER_START_DATE
    current_week = get_current_week(semester_start_date)
    week_param = request.args.get("week")
    is_weekend = request.args.get("is_weekend") == "true"

    if week_param == "all":
        week_param = None
    elif week_param == "current":
        week_param = current_week
    elif week_param:
        try:
            week_param = int(week_param)
        except ValueError:
            return jsonify({"error": "周次参数无效"}), 400
    else:
        week_param = current_week

    weekend_message = None
    if is_weekend and week_param == current_week:
        next_week = get_next_week(semester_start_date)
        if next_week and next_week != current_week:
            week_param = next_week
            weekend_message = f"当前为周末，为您显示第 {next_week} 周课表"

    filtered_courses = []
    for course in data["courses"]:
        if week_param is None:
            filtered_courses.append(course)
        else:
            course_weeks = parse_weeks(course.get("weeks", ""))
            if week_param in course_weeks:
                filtered_courses.append(course)

    grid = {}
    for course in filtered_courses:
        key = f"{course['row']}-{course['col']}"
        if key not in grid:
            grid[key] = []
        grid[key].append(course)

    return jsonify(
        {
            "semester_info": data["semester_info"],
            "generated_at": data["generated_at"],
            "grid": grid,
            "current_week": current_week,
            "selected_week": week_param,
            "weekend_message": weekend_message,
        }
    )


@app.route("/api/tokens/<token>/link-hint-seen", methods=["POST"])
def mark_link_hint_seen_api(token):
    record = credential_store.get_record(token)
    if not record:
        return jsonify({"error": "链接无效，请重新登录"}), 404

    credential_store.mark_link_hint_seen(token)
    return jsonify({"ok": True})


@app.route("/api/tokens/<token>/settings", methods=["GET"])
def get_token_settings_api(token):
    record = credential_store.get_record(token)
    if not record:
        return jsonify({"error": "链接无效，请重新登录"}), 404

    return jsonify(
        {
            "username": record["username"],
            "password": get_stored_password_for_display(record),
            "semester_start_date": record.get("semester_start_date") or SEMESTER_START_DATE,
            "saved_link": build_public_timetable_link(token),
        }
    )


@app.route("/api/tokens/<token>/settings", methods=["PATCH"])
def update_token_settings_api(token):
    record = credential_store.get_record(token)
    if not record:
        return jsonify({"error": "链接无效，请重新登录"}), 404

    payload = request.get_json(silent=True) or {}
    username = payload.get("username", "").strip()
    password = payload.get("password", "")
    semester_start_date = payload.get("semester_start_date", "").strip()

    if not username or not password:
        return jsonify({"error": "学号和密码不能为空"}), 400

    try:
        datetime.strptime(semester_start_date, "%Y-%m-%d")
    except ValueError:
        return jsonify({"error": "开学日期格式无效"}), 400

    credential_store.update_record_settings(
        token=token,
        username=username,
        encrypted_password=encrypt_password(password),
        semester_start_date=semester_start_date,
    )
    credential_store.touch_record(token, datetime.now(timezone.utc).isoformat())
    return jsonify({"ok": True})


@app.route('/')
def index():
    current_week = get_current_week()
    is_weekend = datetime.now().weekday() >= 5
    return render_template("index.html", current_week=current_week, selected_week=current_week, is_weekend=is_weekend)


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        return render_template("login.html")

    username = request.form.get("username", "").strip()
    password = request.form.get("password", "")

    data, error = login_and_get_schedule(username, password)
    if error:
        return render_template("login.html", error=error), 400

    token = generate_token()
    encrypted_password = encrypt_password(password)
    now = datetime.now(timezone.utc).isoformat()
    credential_store.save_record(token, username, encrypted_password, now, now)

    return redirect(url_for("timetable_page", token=token))


@app.route("/t/<token>")
def timetable_page(token):
    record = credential_store.get_record(token)
    if not record:
        return render_template("login.html", error="链接无效，请重新登录"), 404
    semester_start_date = record.get("semester_start_date") or SEMESTER_START_DATE
    current_week = get_current_week(semester_start_date)
    is_weekend = datetime.now().weekday() >= 5

    selected_week = current_week
    week_param = request.args.get("week")
    if week_param == "all":
        selected_week = None
    elif week_param == "current" and current_week:
        selected_week = current_week
    elif week_param:
        try:
            selected_week = int(week_param)
        except ValueError:
            selected_week = current_week

    return render_template(
        "timetable.html",
        token=token,
        saved_link=build_public_timetable_link(token),
        username=record["username"],
        password=get_stored_password_for_display(record),
        semester_start_date=semester_start_date,
        current_week=current_week,
        selected_week=selected_week,
        is_weekend=is_weekend,
        show_link_hint=record["link_hint_seen"] == 0,
    )


if __name__ == '__main__':
    print('=' * 60)
    print('简约课表系统 - 2026春季学期')
    print('=' * 60)
    print(f'访问地址: http://localhost:{PORT}')
    print('每次刷新页面都会实时获取最新课表')
    print(f'学期开始日期: 2026-03-02 (当前周次: {get_current_week() or "未开学"})')
    print('=' * 60)
    print()
    
    app.run(debug=DEBUG, host=HOST, port=PORT)
