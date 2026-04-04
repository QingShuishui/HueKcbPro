#!/usr/bin/env python3
"""
配置文件 - 课表系统配置
"""

# 教务系统配置
USERNAME = 'demo_student_id'
PASSWORD = 'demo_password'
BASE_URL = 'https://jwxt.hue.edu.cn'

# 学期配置
SEMESTER_START_DATE = '2026-03-02'  # 新学期第一周开始日期（2026年3月2日）

# Flask 配置
DEBUG = True
HOST = '0.0.0.0'
PORT = 5004

# 课程时间段配置
TIME_SLOTS = [
    '08:00-09:40',
    '10:00-11:40', 
    '14:00-15:40',
    '16:00-17:40',
    '18:30-20:10',
    '20:20-21:05'
]

# 星期配置
WEEKDAYS = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
