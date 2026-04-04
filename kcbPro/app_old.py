#!/usr/bin/env python3
"""
简约课表系统 - 单文件版本
实时爬取教务系统课表并以黑白简约风格展示
"""
from flask import Flask, render_template_string, request, jsonify
import requests
from bs4 import BeautifulSoup
from PIL import Image
import io
import sys
import re
from datetime import datetime

# Pillow 兼容性修复
if not hasattr(Image, 'ANTIALIAS'):
    Image.ANTIALIAS = Image.LANCZOS

try:
    import ddddocr
except ImportError:
    print("错误: 未安装 ddddocr 库，请运行: pip install ddddocr")
    sys.exit(1)

# 配置
USERNAME = 'demo_student_id'
PASSWORD = 'demo_password'
BASE_URL = 'https://jwxt.hue.edu.cn'
SEMESTER_START_DATE = '2025-09-08'  # 学期第一周开始日期

app = Flask(__name__)


def extract_location_code(location):
    """
    提取地点中的英文和数字部分
    示例: 'S4409计算机专业实验室' -> 'S4409'
    """
    if not location:
        return location
    
    # 匹配开头的英文字母和数字
    match = re.match(r'^[A-Za-z0-9]+', location)
    if match:
        return match.group(0)
    
    return location


# 注册Jinja2过滤器
app.jinja_env.filters['extract_location_code'] = extract_location_code


def login_and_get_schedule():
    """登录并获取课表数据"""
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    })
    
    # 1. 访问首页
    session.get(BASE_URL, timeout=10)
    
    # 2. 获取加密参数
    r = session.get(f'{BASE_URL}/Logon.do?method=logon&flag=sess', timeout=10)
    if '#' not in r.text:
        return None, "获取加密参数失败"
    
    scode, sxh = r.text.split('#')
    
    # 3. 识别验证码
    r = session.get(f'{BASE_URL}/verifycode.servlet', timeout=10)
    try:
        ocr = ddddocr.DdddOcr()
        captcha = ocr.classification(r.content)
    except Exception as e:
        return None, f"验证码识别失败: {e}"
    
    # 4. 生成加密凭据
    code = USERNAME + '%%%' + PASSWORD
    encoded = ''
    sxh_list = [int(x) for x in sxh]
    
    for i in range(len(code)):
        if i < len(sxh_list):
            encoded += code[i] + scode[0:sxh_list[i]]
            scode = scode[sxh_list[i]:]
        else:
            encoded += code[i:]
            break
    
    # 5. 提交登录
    r = session.post(
        f'{BASE_URL}/Logon.do?method=logon',
        data={'useDogCode': '', 'encoded': encoded, 'RANDOMCODE': captcha},
        allow_redirects=True,
        timeout=10
    )
    
    if 'xsMain.jsp' not in r.url:
        if '验证码错误' in r.text:
            return login_and_get_schedule()  # 验证码错误，重试
        return None, "登录失败"
    
    # 6. 获取课表
    r = session.get(f'{BASE_URL}/jsxsd/xskb/xskb_list.do', timeout=10)
    if r.status_code != 200:
        return None, "获取课表失败"
    
    soup = BeautifulSoup(r.text, 'html.parser')
    
    # 解析学期信息
    week_div = soup.find('div', {'id': 'timetableDiv'})
    semester_info = week_div.get_text(strip=True) if week_div else ''
    
    # 解析课表
    table = soup.find('table', {'id': 'kbtable'})
    if not table:
        return None, "未找到课表"
    
    courses = parse_table(table)
    
    return {
        'semester_info': semester_info,
        'courses': courses,
        'generated_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }, None


def get_current_week():
    """
    根据学期开始日期计算当前周次
    返回: 当前周次 (1-30)，如果不在学期内返回None
    """
    try:
        start_date = datetime.strptime(SEMESTER_START_DATE, '%Y-%m-%d')
        current_date = datetime.now()
        
        # 计算距离开学的天数
        days_diff = (current_date - start_date).days
        
        # 如果还没开学，返回None
        if days_diff < 0:
            return None
        
        # 计算周次（从第1周开始）
        week_num = (days_diff // 7) + 1
        
        # 限制在1-30周范围内
        if week_num > 30:
            return None
        
        return week_num
    except:
        return None


def parse_weeks(week_str):
    """
    解析周次字符串，返回周次列表
    示例: '1-16(周)' -> [1,2,...,16], '9(周)' -> [9], '1,3,5(周)' -> [1,3,5]
    """
    if not week_str or '(周)' not in week_str:
        return []
    
    week_str = week_str.replace('(周)', '').strip()
    weeks = []
    
    # 处理逗号分隔
    for part in week_str.split(','):
        part = part.strip()
        if '-' in part:
            # 范围: 1-16
            start, end = part.split('-')
            weeks.extend(range(int(start), int(end) + 1))
        else:
            # 单周: 9
            weeks.append(int(part))
    
    return weeks


def parse_table(table):
    """解析课表表格"""
    courses = []
    time_slots = ['08:00-09:40', '10:00-11:40', '14:00-15:40', '16:00-17:40', '18:30-20:10', '20:20-21:05']
    weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
    
    rows = table.find_all('tr')[1:]  # 跳过表头
    
    for row_idx, row in enumerate(rows[:6]):  # 6个时间段
        cells = row.find_all('td')[:7]  # 7天
        
        for day_idx, cell in enumerate(cells):
            course_divs = cell.find_all('div', class_='kbcontent1')
            
            for div in course_divs:
                if 'sykb1' in div.get('class', []):
                    continue
                
                text = str(div)
                blocks = text.split('----------------------')
                
                for block in blocks:
                    block_soup = BeautifulSoup(block, 'html.parser')
                    lines = list(block_soup.stripped_strings)
                    
                    if not lines:
                        continue
                    
                    # 过滤掉标记行（如 &nbspP）
                    lines = [line for line in lines if not line.startswith('&nbsp')]
                    
                    if not lines:
                        continue
                    
                    # 第一行包含：课程名 课程代号（例如：软件测试技术 SIT）
                    raw_name = lines[0]
                    course_name = raw_name
                    course_code = ''  # 课程代号
                    
                    # 检查是否有课程代号（通常是大写字母，长度2-6个字符）
                    if ' ' in raw_name:
                        parts = raw_name.rsplit(' ', 1)
                        # 判断最后一部分是否是课程代号（大写字母为主，无数字）
                        if len(parts[1]) <= 6 and parts[1].isupper() and not any(c.isdigit() for c in parts[1]):
                            course_name, course_code = parts
                    
                    teacher = ''
                    location = ''
                    weeks = ''
                    
                    # 解析后续行：地点、周次、教师
                    for line in lines[1:]:
                        if '(周)' in line:
                            weeks = line
                        elif not location and line:  # 第一个非周次的行是地点
                            location = line
                        elif not teacher and line and location:  # 地点后面的可能是教师名
                            # 教师名通常较短（2-4个字符）且不包含数字
                            if len(line) <= 4 and not any(c.isdigit() for c in line):
                                teacher = line
                    
                    if course_name:
                        courses.append({
                            'name': course_name,
                            'code': course_code,  # 课程代号
                            'teacher': teacher,
                            'location': location,
                            'weeks': weeks,
                            'time': time_slots[row_idx],
                            'day': weekdays[day_idx],
                            'row': row_idx,
                            'col': day_idx
                        })
    
    return courses


# HTML 模板 - 简约黑白风格
HTML_TEMPLATE = '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HUE课程表 ☁️</title>
    <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;800&family=ZCOOL+KuaiLe&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #FDFBF7;
            --text-main: #5D5D5D;
            --text-light: #9CA3AF;
            --color-pink: #FEE2E2; --color-pink-text: #991B1B;
            --color-blue: #E0F2FE; --color-blue-text: #075985;
            --color-yellow: #FEF3C7; --color-yellow-text: #92400E;
            --color-purple: #F3E8FF; --color-purple-text: #6B21A8;
            --color-green: #DCFCE7; --color-green-text: #166534;
            --color-gray: #F3F4F6; --color-gray-text: #9CA3AF;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Nunito', 'ZCOOL KuaiLe', cursive, sans-serif;
            background-color: var(--bg-color);
            background-image: radial-gradient(#E5E7EB 2px, transparent 2px);
            background-size: 24px 24px;
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }

        .container {
            width: 100%;
            max-width: 1200px;
            background: rgba(255, 255, 255, 0.85);
            backdrop-filter: blur(12px);
            border-radius: 30px;
            padding: 30px;
            box-shadow: 0 15px 35px rgba(0,0,0,0.05);
            border: 2px solid #fff;
            position: relative;
            min-height: 600px;
        }

        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 25px;
            flex-wrap: wrap;
        }

        .title-group h1 {
            font-size: 2rem;
            color: #F472B6;
            margin-bottom: 5px;
        }
        
        .title-group p {
            font-size: 0.9rem;
            color: var(--text-light);
        }

        .week-selector select {
            padding: 8px 20px;
            border-radius: 40px;
            border: 2px solid #FBCFE8;
            background: #fff;
            color: var(--text-main);
            font-family: inherit;
            font-weight: bold;
            cursor: pointer;
            outline: none;
            transition: all 0.3s ease;
            box-shadow: 0 4px 10px rgba(0,0,0,0.05);
        }
        
        .week-selector select:hover {
            box-shadow: 0 4px 10px rgba(244, 114, 182, 0.2);
            border-color: #F472B6;
        }

        .timetable {
            display: grid;
            grid-template-columns: 60px repeat(7, 1fr);
            gap: 12px;
        }

        .day-header {
            text-align: center;
            padding: 10px;
            font-weight: 800;
            color: var(--text-main);
            opacity: 0.7;
        }

        .time-slot {
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            font-size: 0.8rem;
            color: var(--text-light);
            font-weight: bold;
            min-height: 100px;
            text-align: center;
        }

        /* 核心动画卡片样式 */
        .course {
            padding: 12px;
            border-radius: 18px;
            display: flex;
            flex-direction: column;
            justify-content: center;
            position: relative;
            cursor: pointer;
            opacity: 0; /* 初始隐藏 */
            transform: scale(0.8);
            min-height: 100px;
            height: 100%;
            transition: transform 0.2s;
            background: #fff; /* Default fallback */
        }

        .course:hover {
            transform: translateY(-3px) scale(1.03) !important;
            z-index: 10;
            box-shadow: 0 10px 20px rgba(0,0,0,0.1);
        }
        
        .course.empty {
            border: 2px dashed #E5E7EB;
            background: transparent;
            box-shadow: none;
            cursor: default;
        }
        
        .course.empty:hover {
            transform: none !important;
        }

        /* 进场动画：果冻回弹 */
        @keyframes jellyPopIn {
            0% { opacity: 0; transform: scale(0.5) translateY(20px); }
            60% { opacity: 1; transform: scale(1.05) translateY(-5px); }
            100% { opacity: 1; transform: scale(1) translateY(0); }
        }

        .course.animate-in {
            animation: jellyPopIn 0.6s cubic-bezier(0.34, 1.56, 0.64, 1) forwards;
        }

        /* 颜色类 */
        .pink { background: var(--color-pink); color: var(--color-pink-text); }
        .blue { background: var(--color-blue); color: var(--color-blue-text); }
        .yellow { background: var(--color-yellow); color: var(--color-yellow-text); }
        .purple { background: var(--color-purple); color: var(--color-purple-text); }
        .green { background: var(--color-green); color: var(--color-green-text); }

        .course-name { font-weight: bold; font-size: 0.95rem; margin-bottom: 4px; line-height: 1.2; }
        .course-detail { font-size: 0.75rem; opacity: 0.85; }
        
        /* Tooltip */
        .course-tooltip {
            display: none;
            position: absolute;
            bottom: 100%;
            left: 50%;
            transform: translateX(-50%);
            margin-bottom: 8px;
            padding: 6px 10px;
            background: rgba(0, 0, 0, 0.8);
            color: #fff;
            font-size: 0.75rem;
            border-radius: 10px;
            white-space: nowrap;
            z-index: 100;
            pointer-events: none;
        }
        
        .course-tooltip::after {
            content: '';
            position: absolute;
            top: 100%;
            left: 50%;
            transform: translateX(-50%);
            border: 5px solid transparent;
            border-top-color: rgba(0, 0, 0, 0.8);
        }
        
        .course:hover .course-tooltip {
            display: block;
        }

        .error {
            background: #FEE2E2;
            color: #991B1B;
            padding: 20px;
            border-radius: 20px;
            text-align: center;
            animation: jellyPopIn 0.5s ease-out forwards;
            display: none;
        }
        
        footer {
            text-align: center;
            margin-top: 30px;
            color: var(--text-light);
            font-size: 0.8rem;
        }

        /* 桌面端隐藏移动端专用元素 */
        .date-strip,
        .bottom-nav {
            display: none;
        }

        /* Loading Overlay */
        .loading-overlay {
            position: absolute;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(255,255,255,0.9);
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            gap: 20px;
            z-index: 100;
            border-radius: 30px;
            backdrop-filter: blur(8px);
        }
        .loading-dots {
            display: flex;
            gap: 12px;
            margin-bottom: 10px;
        }
        
        .dot-item {
            width: 20px;
            height: 20px;
            border-radius: 50%;
            animation: bounce 0.6s alternate infinite cubic-bezier(0.5, 0.05, 1, 0.5);
        }
        
        .dot-item:nth-child(1) { background: #F472B6; animation-delay: 0s; }
        .dot-item:nth-child(2) { background: #60A5FA; animation-delay: 0.15s; }
        .dot-item:nth-child(3) { background: #FBBF24; animation-delay: 0.3s; }
        .dot-item:nth-child(4) { background: #A78BFA; animation-delay: 0.45s; }
        
        @keyframes bounce {
            0% { transform: translateY(0) scale(1); opacity: 0.8; }
            100% { transform: translateY(-20px) scale(1.1); opacity: 1; }
        }
        
        .loading-text {
            font-size: 1.2rem;
            color: #F472B6;
            font-weight: bold;
            display: flex;
            align-items: center;
            gap: 2px;
        }
        
        .loading-text .dot {
            animation: blink 1.4s infinite;
            opacity: 0;
        }
        
        .loading-text .dot:nth-child(2) { animation-delay: 0.2s; }
        .loading-text .dot:nth-child(3) { animation-delay: 0.4s; }
        .loading-text .dot:nth-child(4) { animation-delay: 0.6s; }
        
        @keyframes blink {
            0%, 20% { opacity: 0; }
            40% { opacity: 1; }
            100% { opacity: 0; }
        }

        /* ==================== 移动端布局 ==================== */
        @media (max-width: 768px) {
            :root {
                /* 定义统一的列宽比例，确保日期栏和课程表完全对齐 */
                --mobile-time-col: 45px;
                --mobile-day-cols: repeat(7, minmax(0, 1fr));
            }

            body {
                padding: 0;
                align-items: flex-start;
                background: #F5F5F7;
                background-image: none;
            }

            .container {
                max-width: 100%;
                width: 100%;
                min-height: 100vh;
                border-radius: 0;
                padding: 0;
                box-shadow: none;
                border: none;
                background: #F5F5F7;
                display: flex;
                flex-direction: column;
            }

            /* 顶部信息栏 */
            header {
                background: #fff;
                padding: 15px 16px 10px;
                margin-bottom: 0;
                border-bottom: 1px solid #E5E7EB;
                flex-wrap: nowrap;
            }

            .title-group h1 {
                font-size: 1.3rem;
                margin-bottom: 2px;
            }

            .title-group p {
                font-size: 0.75rem;
            }

            .week-selector select {
                padding: 6px 12px;
                font-size: 0.85rem;
            }

            /* 日期导航栏（吸顶）- 使用统一的 CSS 变量确保对齐 */
            .date-strip {
                display: grid !important;
                grid-template-columns: var(--mobile-time-col) var(--mobile-day-cols);
                gap: 2px;
                background: #fff;
                padding: 8px 4px;
                position: sticky;
                top: 0;
                z-index: 40;
                border-bottom: 1px solid #E5E7EB;
                box-shadow: 0 2px 4px rgba(0,0,0,0.05);
            }

            .date-strip .time-label {
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 0.7rem;
                color: var(--text-light);
                font-weight: bold;
            }

            .date-item {
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                padding: 6px 2px;
                border-radius: 12px;
                transition: all 0.2s;
                min-width: 0; /* 防止内容溢出 */
            }

            .date-item .weekday {
                font-size: 0.7rem;
                color: var(--text-light);
                margin-bottom: 2px;
                white-space: nowrap;
            }

            .date-item .date-num {
                font-size: 0.9rem;
                font-weight: bold;
                color: var(--text-main);
            }

            .date-item.today {
                background: #1F2937;
                color: #fff;
            }

            .date-item.today .weekday,
            .date-item.today .date-num {
                color: #fff;
            }

            /* 主课程表网格 - 使用相同的 CSS 变量确保列宽一致 */
            .timetable {
                display: grid;
                grid-template-columns: var(--mobile-time-col) var(--mobile-day-cols);
                gap: 2px;
                padding: 0;
                background: #E5E7EB;
                flex: 1;
                align-content: start;
            }

            /* 隐藏原有的 day-header */
            .day-header {
                display: none;
            }

            /* 时间轴 */
            .time-slot {
                background: #fff;
                font-size: 0.65rem;
                padding: 8px 4px;
                min-height: 90px;
                border-radius: 0;
                display: flex;
                flex-direction: column;
                justify-content: flex-start;
                align-items: center;
                gap: 2px;
            }

            /* 课程卡片：不要在移动端强制覆盖背景色，保留颜色类(pink/blue/...)的填充 */
            .course {
                border-radius: 8px;
                padding: 8px;
                min-height: 90px;
                font-size: 0.7rem;
                box-shadow: none;
                border: none;
            }

            .course.empty {
                background: #fff;
                border: none;
                display: block;
            }

            .course:hover {
                transform: none !important;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }

            .course-name {
                font-size: 0.65rem;
                margin-bottom: 3px;
                line-height: 1.3;
                word-break: break-word;
            }

            .course-detail {
                font-size: 0.6rem;
                line-height: 1.4;
            }

            /* Tooltip 在移动端禁用 */
            .course-tooltip {
                display: none !important;
            }

            /* 底部导航栏 */
            .bottom-nav {
                display: grid !important;
                grid-template-columns: repeat(4, 1fr);
                background: #fff;
                border-top: 1px solid #E5E7EB;
                padding: 8px 0;
                position: sticky;
                bottom: 0;
                z-index: 50;
            }

            .nav-item {
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                gap: 4px;
                color: var(--text-light);
                text-decoration: none;
                transition: color 0.2s;
                padding: 4px;
            }

            .nav-item.active {
                color: #1F2937;
            }

            .nav-icon {
                font-size: 1.4rem;
            }

            .nav-label {
                font-size: 0.7rem;
                font-weight: 600;
            }

            footer {
                display: none;
            }

            /* Loading 适配 */
            .loading-overlay {
                border-radius: 0;
            }

            /* 错误提示适配 */
            .error {
                margin: 16px;
                border-radius: 12px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div id="loading" class="loading-overlay">
            <div class="loading-dots">
                <div class="dot-item"></div>
                <div class="dot-item"></div>
                <div class="dot-item"></div>
                <div class="dot-item"></div>
            </div>
            <div class="loading-text">
                加载中<span class="dot">.</span><span class="dot">.</span><span class="dot">.</span>
            </div>
        </div>

        <div id="error-msg" class="error">
            <h2>哎呀，出错了 (qwq)</h2>
            <p id="error-text"></p>
        </div>

        <header>
            <div class="title-group">
                <h1>课程表 ✏️</h1>
                <p id="semester-info">正在加载学期信息...</p>
                <p id="generated-at" style="font-size: 0.8rem;"></p>
            </div>
            
            <div class="week-selector">
                <select id="weekSelect" onchange="changeWeek()">
                    <option value="" {% if selected_week is none %}selected{% endif %}>(全部课程)</option>
                    {% if current_week %}
                    <option value="current" {% if selected_week == current_week %}selected{% endif %}>
                        当前周 (第{{ current_week }}周) ⭐
                    </option>
                    {% endif %}
                    {% for w in range(1, 31) %}
                    <option value="{{ w }}" {% if selected_week == w %}selected{% endif %}>
                        第{{ w }}周{% if w == current_week %} ←{% endif %}
                    </option>
                    {% endfor %}
                </select>
            </div>
        </header>

        <!-- 移动端日期导航栏 -->
        <div class="date-strip" id="dateStrip">
            <div class="time-label">时间</div>
            <div class="date-item" data-day="0">
                <span class="weekday">周一</span>
                <span class="date-num">-</span>
            </div>
            <div class="date-item" data-day="1">
                <span class="weekday">周二</span>
                <span class="date-num">-</span>
            </div>
            <div class="date-item" data-day="2">
                <span class="weekday">周三</span>
                <span class="date-num">-</span>
            </div>
            <div class="date-item" data-day="3">
                <span class="weekday">周四</span>
                <span class="date-num">-</span>
            </div>
            <div class="date-item" data-day="4">
                <span class="weekday">周五</span>
                <span class="date-num">-</span>
            </div>
            <div class="date-item" data-day="5">
                <span class="weekday">周六</span>
                <span class="date-num">-</span>
            </div>
            <div class="date-item" data-day="6">
                <span class="weekday">周日</span>
                <span class="date-num">-</span>
            </div>
        </div>

        <div class="timetable" id="timetable">
            <div class="day-header"></div> 
            <div class="day-header">MON<br>周一</div>
            <div class="day-header">TUE<br>周二</div>
            <div class="day-header">WED<br>周三</div>
            <div class="day-header">THU<br>周四</div>
            <div class="day-header">FRI<br>周五</div>
            <div class="day-header">SAT<br>周六</div>
            <div class="day-header">SUN<br>周日</div>
            <!-- JS will inject slots here -->
        </div>
        
        <!-- 移动端底部导航栏 -->
        <nav class="bottom-nav">
            <a href="#" class="nav-item active">
                <span class="nav-icon">📅</span>
                <span class="nav-label">课程表</span>
            </a>
            <a href="#" class="nav-item">
                <span class="nav-icon">📚</span>
                <span class="nav-label">课程</span>
            </a>
            <a href="#" class="nav-item">
                <span class="nav-icon">🔔</span>
                <span class="nav-label">通知</span>
            </a>
            <a href="#" class="nav-item">
                <span class="nav-icon">👤</span>
                <span class="nav-label">我的</span>
            </a>
        </nav>
        
        <footer>
            <p>Keep learning, keep shining! (｡•̀ᴗ-)✧</p>
        </footer>
    </div>

    <script>
        const times = [
            '上午 1-2节|08:00-09:40',
            '上午 3-4节|10:00-11:40',
            '下午 5-6节|14:00-15:40',
            '下午 7-8节|16:00-17:40',
            '晚上 9-10节|18:30-20:10',
            '晚上 11节|20:20-21:05'
        ];
        const colors = ['pink', 'blue', 'yellow', 'purple', 'green'];

        function extractLocationCode(loc) {
            if (!loc) return '';
            const match = loc.match(/^[A-Za-z0-9]+/);
            return match ? match[0] : loc;
        }

        async function fetchSchedule(week) {
            const loading = document.getElementById('loading');
            const errorDiv = document.getElementById('error-msg');
            const timetable = document.getElementById('timetable');
            
            loading.style.display = 'flex';
            errorDiv.style.display = 'none';
            
            // Clear existing courses but keep headers
            const headers = Array.from(timetable.children).slice(0, 8);
            timetable.innerHTML = '';
            headers.forEach(h => timetable.appendChild(h));

            try {
                const url = week ? `/api/schedule?week=${week}` : '/api/schedule';
                const response = await fetch(url);
                const data = await response.json();
                
                if (data.error) {
                    document.getElementById('error-text').innerText = data.error;
                    errorDiv.style.display = 'block';
                    return;
                }
                
                updateUI(data);
            } catch (e) {
                console.error(e);
                document.getElementById('error-text').innerText = '网络请求失败';
                errorDiv.style.display = 'block';
            } finally {
                loading.style.display = 'none';
            }
        }

        function updateDateStrip() {
            // 更新移动端日期导航栏
            const today = new Date();
            const currentDay = today.getDay(); // 0=周日, 1=周一, ...
            
            // 计算本周一的日期
            const monday = new Date(today);
            const diff = currentDay === 0 ? -6 : 1 - currentDay; // 如果是周日,退6天,否则计算到周一
            monday.setDate(today.getDate() + diff);
            
            // 更新7天的日期
            const dateItems = document.querySelectorAll('.date-item');
            dateItems.forEach((item, index) => {
                const date = new Date(monday);
                date.setDate(monday.getDate() + index);
                
                const dateNum = date.getDate();
                item.querySelector('.date-num').textContent = dateNum;
                
                // 高亮今天
                if (date.toDateString() === today.toDateString()) {
                    item.classList.add('today');
                } else {
                    item.classList.remove('today');
                }
            });
        }

        function updateUI(data) {
            document.getElementById('semester-info').innerText = data.semester_info || '';
            document.getElementById('generated-at').innerText = '生成时间: ' + data.generated_at;
            
            // 更新日期导航栏
            updateDateStrip();
            
            const gridContainer = document.getElementById('timetable');
            
            // Render slots
            for (let timeIdx = 0; timeIdx < 6; timeIdx++) {
                // Time label
                const timeSlot = document.createElement('div');
                timeSlot.className = 'time-slot';
                const parts = times[timeIdx].split('|');
                timeSlot.innerHTML = `<span>${parts[1]}</span><span style="font-size: 0.7rem; font-weight: normal;">${parts[0]}</span>`;
                gridContainer.appendChild(timeSlot);
                
                for (let dayIdx = 0; dayIdx < 7; dayIdx++) {
                    const key = `${timeIdx}-${dayIdx}`;
                    const courses = data.grid[key];
                    const delay = (timeIdx * 7 + dayIdx) * 0.03; // Stagger animation
                    
                    if (courses && courses.length > 0) {
                        courses.forEach(course => {
                            const el = document.createElement('div');
                            el.className = `course animate-in ${colors[(timeIdx + dayIdx) % 5]}`;
                            el.style.animationDelay = `${delay}s`;
                            
                            // Tooltip - 显示周次和教师
                            if (course.weeks || course.teacher) {
                                const tooltip = document.createElement('div');
                                tooltip.className = 'course-tooltip';
                                let tooltipText = '';
                                if (course.weeks) tooltipText += '📅 ' + course.weeks;
                                if (course.teacher) {
                                    if (tooltipText) tooltipText += ' | ';
                                    tooltipText += '👤 ' + course.teacher;
                                }
                                tooltip.innerText = tooltipText;
                                el.appendChild(tooltip);
                            }
                            
                            // Name with code
                            const name = document.createElement('div');
                            name.className = 'course-name';
                            name.innerText = course.name + (course.code ? ' ' + course.code : '');
                            el.appendChild(name);
                            
                            // Detail - 只显示地点
                            const detail = document.createElement('div');
                            detail.className = 'course-detail';
                            if (course.location) {
                                detail.innerHTML = `📍 ${extractLocationCode(course.location)}`;
                            }
                            el.appendChild(detail);
                            
                            gridContainer.appendChild(el);
                        });
                    } else {
                        const el = document.createElement('div');
                        el.className = 'course empty animate-in';
                        el.style.animationDelay = `${delay}s`;
                        gridContainer.appendChild(el);
                    }
                }
            }
        }

        function changeWeek() {
            const week = document.getElementById('weekSelect').value;
            fetchSchedule(week);
        }

        // Initial load
        window.onload = () => {
            const urlParams = new URLSearchParams(window.location.search);
            // If URL has week param, use it, otherwise use the select value (which defaults to current or empty)
            let week = urlParams.get('week');
            if (!week) {
                week = document.getElementById('weekSelect').value;
            }
            fetchSchedule(week);
        };
    </script>
</body>
</html>'''


@app.route('/api/schedule')
def get_schedule_api():
    """API - 获取课表数据"""
    print('正在获取课表(API)...')
    data, error = login_and_get_schedule()
    
    current_week = get_current_week()
    
    if error:
        return jsonify({'error': error})
    
    week_param = request.args.get('week')
    if week_param == 'current':
        week_param = current_week
    elif week_param:
        week_param = int(week_param)
    else:
        week_param = current_week
        
    filtered_courses = []
    for course in data['courses']:
        if week_param is None:
            filtered_courses.append(course)
        else:
            course_weeks = parse_weeks(course.get('weeks', ''))
            if week_param in course_weeks:
                filtered_courses.append(course)
                
    grid = {}
    for course in filtered_courses:
        key = f"{course['row']}-{course['col']}"
        if key not in grid:
            grid[key] = []
        grid[key].append(course)
        
    return jsonify({
        'semester_info': data['semester_info'],
        'generated_at': data['generated_at'],
        'grid': grid,
        'current_week': current_week,
        'selected_week': week_param
    })


@app.route('/')
def index():
    """主页 - 显示课表框架"""
    current_week = get_current_week()
    return render_template_string(HTML_TEMPLATE, current_week=current_week, selected_week=current_week)


if __name__ == '__main__':
    print('=' * 60)
    print('简约课表系统')
    print('=' * 60)
    print('访问地址: http://localhost:5001')
    print('每次刷新页面都会实时获取最新课表')
    print('=' * 60)
    print()
    
    app.run(debug=True, host='0.0.0.0', port=5001)
