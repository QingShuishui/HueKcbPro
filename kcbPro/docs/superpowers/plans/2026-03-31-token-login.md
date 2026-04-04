# Token Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-user login with an 8-character token link, encrypted credential storage in SQLite, and token-scoped timetable loading.

**Architecture:** The Flask app will stop using fixed credentials from `config.py` and instead persist `token + username + encrypted_password` in SQLite. A new login route will validate credentials once, store encrypted credentials with a random token, then timetable views and API calls will resolve the token, decrypt the password, and re-login to the school system on demand.

**Tech Stack:** Flask, SQLite (`sqlite3`), `cryptography.fernet`, `pytest`, `requests`, `BeautifulSoup`

---

### Task 1: Add Test Harness And Dependencies

**Files:**
- Modify: `requirements.txt`
- Create: `tests/conftest.py`
- Create: `tests/test_token_generator.py`
- Create: `tests/test_crypto.py`

- [ ] **Step 1: Write the failing token generator test**

```python
from utils.token_generator import generate_token


def test_generate_token_returns_8_alnum_chars():
    token = generate_token()

    assert len(token) == 8
    assert token.isalnum()
```

- [ ] **Step 2: Write the failing crypto round-trip test**

```python
from utils.crypto import encrypt_password, decrypt_password


def test_encrypt_and_decrypt_password_round_trip(monkeypatch):
    monkeypatch.setenv(
        "CREDENTIAL_ENCRYPTION_KEY",
        "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="
    )

    encrypted = encrypt_password("secret123")

    assert encrypted != "secret123"
    assert decrypt_password(encrypted) == "secret123"
```

- [ ] **Step 3: Add test fixtures and test dependency**

```python
# tests/conftest.py
import os
import tempfile

import pytest


@pytest.fixture
def temp_db_path():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    try:
        yield path
    finally:
        if os.path.exists(path):
            os.remove(path)
```

```text
# requirements.txt
pytest>=8.0.0
cryptography>=42.0.0
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `pytest tests/test_token_generator.py tests/test_crypto.py -q`

Expected: FAIL with `ModuleNotFoundError` for `utils.token_generator` and `utils.crypto`

- [ ] **Step 5: Write minimal implementation for token generation and crypto**

```python
# utils/token_generator.py
import secrets
import string


TOKEN_ALPHABET = string.ascii_letters + string.digits


def generate_token(length=8):
    return "".join(secrets.choice(TOKEN_ALPHABET) for _ in range(length))
```

```python
# utils/crypto.py
import base64
import hashlib
import os

from cryptography.fernet import Fernet


def _get_fernet():
    raw_key = os.environ["CREDENTIAL_ENCRYPTION_KEY"]
    derived = hashlib.sha256(raw_key.encode("utf-8")).digest()
    return Fernet(base64.urlsafe_b64encode(derived))


def encrypt_password(password):
    return _get_fernet().encrypt(password.encode("utf-8")).decode("utf-8")


def decrypt_password(encrypted_password):
    return _get_fernet().decrypt(encrypted_password.encode("utf-8")).decode("utf-8")
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `pytest tests/test_token_generator.py tests/test_crypto.py -q`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add requirements.txt tests/conftest.py tests/test_token_generator.py tests/test_crypto.py utils/token_generator.py utils/crypto.py
git commit -m "test: add token and crypto foundations"
```

### Task 2: Add SQLite Credential Store

**Files:**
- Create: `utils/credential_store.py`
- Create: `tests/test_credential_store.py`

- [ ] **Step 1: Write the failing credential store test**

```python
from utils.credential_store import CredentialStore


def test_store_save_and_get_record(temp_db_path):
    store = CredentialStore(temp_db_path)
    store.initialize()

    store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    record = store.get_record("Ab3X9kQ2")

    assert record["username"] == "demo_student_id"
    assert record["encrypted_password"] == "ciphertext"
```

- [ ] **Step 2: Add a failing last-access update test**

```python
from utils.credential_store import CredentialStore


def test_touch_record_updates_last_accessed_at(temp_db_path):
    store = CredentialStore(temp_db_path)
    store.initialize()
    store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    store.touch_record("Ab3X9kQ2", "2026-03-31T13:00:00")
    record = store.get_record("Ab3X9kQ2")

    assert record["last_accessed_at"] == "2026-03-31T13:00:00"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/test_credential_store.py -q`

Expected: FAIL with `ModuleNotFoundError: No module named 'utils.credential_store'`

- [ ] **Step 4: Write minimal implementation**

```python
import sqlite3


class CredentialStore:
    def __init__(self, db_path):
        self.db_path = db_path

    def initialize(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS saved_logins (
                    token TEXT PRIMARY KEY,
                    username TEXT NOT NULL,
                    encrypted_password TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    last_accessed_at TEXT NOT NULL
                )
                """
            )

    def save_record(self, token, username, encrypted_password, created_at, last_accessed_at):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO saved_logins
                (token, username, encrypted_password, created_at, last_accessed_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (token, username, encrypted_password, created_at, last_accessed_at),
            )

    def get_record(self, token):
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute(
                "SELECT token, username, encrypted_password, created_at, last_accessed_at FROM saved_logins WHERE token = ?",
                (token,),
            ).fetchone()
        return dict(row) if row else None

    def touch_record(self, token, last_accessed_at):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "UPDATE saved_logins SET last_accessed_at = ? WHERE token = ?",
                (last_accessed_at, token),
            )
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pytest tests/test_credential_store.py -q`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add tests/test_credential_store.py utils/credential_store.py
git commit -m "test: add sqlite credential store"
```

### Task 3: Parameterize The Crawler

**Files:**
- Modify: `utils/crawler.py`
- Create: `tests/test_crawler_login_contract.py`

- [ ] **Step 1: Write the failing crawler contract test**

```python
from unittest.mock import patch

from utils.crawler import login_and_get_schedule


@patch("utils.crawler.parse_table", return_value=[])
@patch("utils.crawler.ddddocr.DdddOcr")
@patch("utils.crawler.requests.Session")
def test_login_and_get_schedule_uses_supplied_credentials(
    session_cls, ocr_cls, _parse_table
):
    session = session_cls.return_value
    ocr_cls.return_value.classification.return_value = "1234"

    response_home = type("R", (), {"text": "", "status_code": 200, "url": "https://jwxt.hue.edu.cn"})()
    response_sess = type("R", (), {"text": "abc#111", "status_code": 200, "url": "https://jwxt.hue.edu.cn"})()
    response_captcha = type("R", (), {"content": b"img", "status_code": 200, "url": "https://jwxt.hue.edu.cn"})()
    response_login = type("R", (), {"text": "", "status_code": 200, "url": "https://jwxt.hue.edu.cn/xsMain.jsp"})()
    response_table = type("R", (), {"text": "<div id='timetableDiv'>2026春</div><table id='kbtable'></table>", "status_code": 200, "url": "https://jwxt.hue.edu.cn"})()
    session.get.side_effect = [response_home, response_sess, response_captcha, response_table]
    session.post.return_value = response_login

    login_and_get_schedule("demo_student_id", "pw123")

    post_data = session.post.call_args.kwargs["data"]
    assert "demo_student_id" not in post_data["encoded"]
    assert "pw123" not in post_data["encoded"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_crawler_login_contract.py -q`

Expected: FAIL because `login_and_get_schedule()` does not accept `username` and `password`

- [ ] **Step 3: Write minimal implementation**

```python
def login_and_get_schedule(username, password):
    # ...
    code = username + '%%%' + password
    # ...
```

Also remove the direct import and dependency on `USERNAME` and `PASSWORD` from `config.py`.

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_crawler_login_contract.py -q`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add utils/crawler.py tests/test_crawler_login_contract.py
git commit -m "refactor: parameterize crawler credentials"
```

### Task 4: Add Login And Token Routes

**Files:**
- Modify: `app.py`
- Create: `templates/login.html`
- Create: `templates/timetable.html`
- Create: `tests/test_login_routes.py`

- [ ] **Step 1: Write the failing login redirect test**

```python
from unittest.mock import patch


@patch("app.login_and_get_schedule", return_value=({"courses": [], "semester_info": "", "generated_at": "now"}, None))
@patch("app.generate_token", return_value="Ab3X9kQ2")
def test_post_login_redirects_to_token_page(_generate_token, _crawler, client):
    response = client.post(
        "/login",
        data={"username": "demo_student_id", "password": "pw123"},
        follow_redirects=False,
    )

    assert response.status_code == 302
    assert response.headers["Location"].endswith("/t/Ab3X9kQ2")
```

- [ ] **Step 2: Add the failing invalid-token page test**

```python
def test_token_page_returns_404_for_missing_token(client):
    response = client.get("/t/BadTok99")

    assert response.status_code == 404
```

- [ ] **Step 3: Add Flask client fixture**

```python
# tests/conftest.py
import importlib


@pytest.fixture
def client(monkeypatch, temp_db_path):
    monkeypatch.setenv("CREDENTIAL_ENCRYPTION_KEY", "local-dev-key")
    monkeypatch.setenv("KCBPRO_DB_PATH", temp_db_path)
    app_module = importlib.import_module("app")
    app_module.app.config["TESTING"] = True
    with app_module.app.test_client() as client:
        yield client
```

- [ ] **Step 4: Run test to verify it fails**

Run: `pytest tests/test_login_routes.py -q`

Expected: FAIL because `/login` and `/t/<token>` do not exist yet

- [ ] **Step 5: Write minimal implementation**

```python
# app.py sketch
@app.route("/")
def index():
    return render_template("login.html")


@app.route("/login", methods=["POST"])
def login():
    username = request.form.get("username", "").strip()
    password = request.form.get("password", "")
    data, error = login_and_get_schedule(username, password)
    if error:
        return render_template("login.html", error=error), 400

    token = generate_token()
    encrypted_password = encrypt_password(password)
    now = datetime.utcnow().isoformat()
    credential_store.save_record(token, username, encrypted_password, now, now)
    return redirect(url_for("timetable_page", token=token))


@app.route("/t/<token>")
def timetable_page(token):
    if not credential_store.get_record(token):
        return render_template("login.html", error="链接无效，请重新登录"), 404
    return render_template("timetable.html", token=token, saved_link=request.url)
```

- [ ] **Step 6: Run test to verify it passes**

Run: `pytest tests/test_login_routes.py -q`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app.py templates/login.html templates/timetable.html tests/conftest.py tests/test_login_routes.py
git commit -m "feat: add login and token routes"
```

### Task 5: Add Token-Scoped Schedule API

**Files:**
- Modify: `app.py`
- Modify: `static/js/script.js`
- Create: `tests/test_schedule_api.py`

- [ ] **Step 1: Write the failing API lookup test**

```python
from unittest.mock import patch


@patch("app.decrypt_password", return_value="pw123")
@patch("app.login_and_get_schedule", return_value=({"courses": [], "semester_info": "2026春", "generated_at": "now"}, None))
def test_schedule_api_uses_token_record(_crawler, _decrypt_password, client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/api/schedule/Ab3X9kQ2")

    assert response.status_code == 200
    _crawler.assert_called_once_with("demo_student_id", "pw123")
```

- [ ] **Step 2: Add the failing invalid-token API test**

```python
def test_schedule_api_rejects_missing_token(client):
    response = client.get("/api/schedule/Missing1")

    assert response.status_code == 404
    assert response.get_json()["error"] == "链接无效，请重新登录"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pytest tests/test_schedule_api.py -q`

Expected: FAIL because `/api/schedule/<token>` does not exist

- [ ] **Step 4: Write minimal implementation**

```python
@app.route("/api/schedule/<token>")
def get_schedule_api(token):
    record = credential_store.get_record(token)
    if not record:
        return jsonify({"error": "链接无效，请重新登录"}), 404

    password = decrypt_password(record["encrypted_password"])
    data, error = login_and_get_schedule(record["username"], password)
    if error:
        return jsonify({"error": "登录失效，请重新登录"}), 400

    credential_store.touch_record(token, datetime.utcnow().isoformat())
    current_week = get_current_week()
    week_param = request.args.get("week")
    is_weekend = request.args.get("is_weekend") == "true"

    if week_param == "current":
        week_param = current_week
    elif week_param:
        week_param = int(week_param)
    else:
        week_param = current_week

    weekend_message = None
    if is_weekend and week_param == current_week:
        next_week = get_next_week()
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

    return jsonify({
        "semester_info": data["semester_info"],
        "generated_at": data["generated_at"],
        "grid": grid,
        "current_week": current_week,
        "selected_week": week_param,
        "weekend_message": weekend_message,
    })
```

In `static/js/script.js`, change the request URL from `'/api/schedule'` to:

```javascript
let url = `/api/schedule/${window.scheduleToken}`;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pytest tests/test_schedule_api.py -q`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app.py static/js/script.js tests/test_schedule_api.py
git commit -m "feat: add token scoped schedule api"
```

### Task 6: Show Save-Link Guidance In UI

**Files:**
- Modify: `templates/timetable.html`
- Modify: `static/css/style.css`
- Create: `tests/test_timetable_page.py`

- [ ] **Step 1: Write the failing page content test**

```python
def test_timetable_page_shows_saved_link_notice(client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/t/Ab3X9kQ2")

    assert "请保存此链接" in response.get_data(as_text=True)
    assert "/t/Ab3X9kQ2" in response.get_data(as_text=True)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_timetable_page.py -q`

Expected: FAIL because the timetable page does not show the save-link notice yet

- [ ] **Step 3: Write minimal implementation**

```html
<section class="save-link-banner">
    <p>登录成功。请保存此链接，下次可直接访问。</p>
    <input type="text" value="{{ saved_link }}" readonly>
</section>
```

```css
.save-link-banner {
    margin: 1rem 0;
    padding: 1rem;
    border: 2px solid #111;
    border-radius: 12px;
    background: #fffbe6;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/test_timetable_page.py -q`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add templates/timetable.html static/css/style.css tests/test_timetable_page.py
git commit -m "feat: show save link guidance"
```

### Task 7: Final Verification

**Files:**
- Modify: `app.py`
- Modify: `utils/crawler.py`
- Modify: `templates/login.html`
- Modify: `templates/timetable.html`
- Modify: `static/js/script.js`
- Modify: `static/css/style.css`
- Modify: `requirements.txt`
- Create: `utils/crypto.py`
- Create: `utils/token_generator.py`
- Create: `utils/credential_store.py`
- Create: `tests/conftest.py`
- Create: `tests/test_token_generator.py`
- Create: `tests/test_crypto.py`
- Create: `tests/test_credential_store.py`
- Create: `tests/test_crawler_login_contract.py`
- Create: `tests/test_login_routes.py`
- Create: `tests/test_schedule_api.py`
- Create: `tests/test_timetable_page.py`

- [ ] **Step 1: Run the full test suite**

Run: `pytest -q`

Expected: PASS

- [ ] **Step 2: Run a manual smoke test**

Run: `python3 app.py`

Expected: Flask starts without missing-key errors when `CREDENTIAL_ENCRYPTION_KEY` is set and the login page is served at `http://localhost:5004`

- [ ] **Step 3: Verify the main flows manually**

1. Open `/`
2. Submit a valid username and password
3. Confirm redirect to `/t/<token>`
4. Refresh `/t/<token>`
5. Confirm timetable data still loads
6. Confirm the page displays “请保存此链接”

- [ ] **Step 4: Commit**

```bash
git add app.py utils/crawler.py templates/login.html templates/timetable.html static/js/script.js static/css/style.css requirements.txt utils/crypto.py utils/token_generator.py utils/credential_store.py tests/conftest.py tests/test_token_generator.py tests/test_crypto.py tests/test_credential_store.py tests/test_crawler_login_contract.py tests/test_login_routes.py tests/test_schedule_api.py tests/test_timetable_page.py
git commit -m "feat: add token based timetable login"
```
