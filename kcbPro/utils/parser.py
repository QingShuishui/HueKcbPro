#!/usr/bin/env python3
"""
解析模块 - 负责解析课表数据和日期处理
"""
import re
from datetime import datetime
from bs4 import BeautifulSoup
from config import SEMESTER_START_DATE, TIME_SLOTS, WEEKDAYS


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


def get_current_week(semester_start_date=SEMESTER_START_DATE):
    """
    根据学期开始日期计算当前周次
    返回: 当前周次 (1-30)，如果不在学期内返回1（默认显示第一周）
    """
    try:
        start_date = datetime.strptime(semester_start_date, '%Y-%m-%d')
        current_date = datetime.now()
        
        # 计算距离开学的天数
        days_diff = (current_date - start_date).days
        
        # 如果还没开学，返回1（默认显示第一周）
        if days_diff < 0:
            return 1
        
        # 计算周次（从第1周开始）
        week_num = (days_diff // 7) + 1
        
        # 限制在1-30周范围内
        if week_num > 30:
            return 1
        
        return week_num
    except:
        return 1


def get_next_week(semester_start_date=SEMESTER_START_DATE):
    """
    获取下一周的周次
    """
    current = get_current_week(semester_start_date)
    if current and current < 30:
        return current + 1
    return current


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
                            'time': TIME_SLOTS[row_idx],
                            'day': WEEKDAYS[day_idx],
                            'row': row_idx,
                            'col': day_idx
                        })
    
    return courses
