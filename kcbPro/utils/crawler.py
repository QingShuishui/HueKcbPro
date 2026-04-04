#!/usr/bin/env python3
"""
爬虫模块 - 负责登录教务系统并获取课表数据
"""
import requests
from bs4 import BeautifulSoup
from datetime import datetime

try:
    import ddddocr
except ImportError:
    ddddocr = None

from config import BASE_URL
from utils.parser import parse_table


def login_and_get_schedule(username, password):
    """登录并获取课表数据"""
    if ddddocr is None:
        return None, "未安装 ddddocr 库，请先安装后再试"

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
    code = username + '%%%' + password
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
            return login_and_get_schedule(username, password)  # 验证码错误，重试
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
