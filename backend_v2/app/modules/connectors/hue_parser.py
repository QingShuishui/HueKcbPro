import re

from bs4 import BeautifulSoup

from app.modules.connectors.base import NormalizedCourse, NormalizedSchedule


LESSON_SPANS = [
    (1, 2),
    (3, 4),
    (5, 6),
    (7, 8),
    (9, 10),
    (11, 12),
]

ROMAN_NUMERAL_SUFFIXES = {
    "I",
    "II",
    "III",
    "IV",
    "V",
    "VI",
    "VII",
    "VIII",
    "IX",
    "X",
}


def extract_location_code(location: str) -> str:
    if not location:
        return location

    match = re.match(r"^[A-Za-z0-9]+", location)
    return match.group(0) if match else location


def parse_weeks(week_str: str) -> list[int]:
    if not week_str or "(周)" not in week_str:
        return []

    week_str = week_str.replace("(周)", "").strip()
    weeks: list[int] = []
    for part in week_str.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start, end = part.split("-")
            weeks.extend(range(int(start), int(end) + 1))
        else:
            weeks.append(int(part))
    return weeks


def split_course_name_code(raw_name: str) -> tuple[str, str]:
    course_name = raw_name
    course_code = ""
    if " " not in raw_name:
        return course_name, course_code

    parts = raw_name.rsplit(" ", 1)
    code_candidate = parts[1].strip()
    looks_like_code = bool(re.fullmatch(r"[A-Za-z0-9-]{2,12}", code_candidate))
    alpha_only_code = code_candidate.isalpha()
    roman_suffix = code_candidate.upper() in ROMAN_NUMERAL_SUFFIXES
    if (
        looks_like_code
        and not roman_suffix
        and (not alpha_only_code or len(code_candidate) >= 3)
    ):
        course_name = parts[0]
        course_code = code_candidate
    return course_name, course_code


def parse_home_schedule_table(table) -> list[NormalizedCourse]:
    courses: list[NormalizedCourse] = []
    rows = table.find_all("tr")[1:]

    for row_idx, row in enumerate(rows[: len(LESSON_SPANS)]):
        cells = row.find_all("td")
        if len(cells) < 2:
            continue
        fallback_lesson_start, fallback_lesson_end = LESSON_SPANS[row_idx]

        for day_idx, cell in enumerate(cells[1:8]):
            for course_item in cell.find_all("p"):
                title = course_item.get("title", "")
                fields = _parse_home_course_title(title)
                raw_name = fields.get("课程名称", "").strip()
                if not raw_name:
                    continue

                course_name, course_code = split_course_name_code(raw_name)
                raw_time = fields.get("上课时间", "")
                title_weekday = _parse_home_weekday(raw_time)
                lesson_blocks = _parse_home_lesson_blocks(
                    raw_time,
                    fallback=(fallback_lesson_start, fallback_lesson_end),
                )
                raw_weeks = _parse_home_weeks(raw_time)

                for lesson_start, lesson_end in lesson_blocks:
                    courses.append(
                        NormalizedCourse(
                            name=course_name,
                            code=course_code,
                            teacher="",
                            room=extract_location_code(
                                fields.get("上课地点", "").strip()
                            ),
                            weekday=title_weekday or day_idx + 1,
                            lesson_start=lesson_start,
                            lesson_end=lesson_end,
                            raw_weeks=raw_weeks,
                            parsed_weeks=parse_weeks(raw_weeks),
                        )
                    )

    return courses


def _parse_home_course_title(title: str) -> dict[str, str]:
    title_soup = BeautifulSoup(title, "html.parser")
    fields: dict[str, str] = {}
    for line in title_soup.stripped_strings:
        if "：" not in line:
            continue
        key, value = line.split("：", 1)
        fields[key.strip()] = value.strip()
    return fields


def _parse_home_weekday(raw_time: str) -> int | None:
    weekdays = {
        "星期一": 1,
        "星期二": 2,
        "星期三": 3,
        "星期四": 4,
        "星期五": 5,
        "星期六": 6,
        "星期日": 7,
        "星期天": 7,
    }
    for label, weekday in weekdays.items():
        if label in raw_time:
            return weekday
    return None


def _parse_home_lesson_blocks(
    raw_time: str,
    *,
    fallback: tuple[int, int],
) -> list[tuple[int, int]]:
    match = re.search(r"\[([0-9,-]+)\]节", raw_time)
    if not match:
        return [fallback]

    lesson_numbers = [int(item) for item in re.findall(r"\d+", match.group(1))]
    if not lesson_numbers:
        return [fallback]

    lesson_start = min(lesson_numbers)
    lesson_end = max(lesson_numbers)
    lesson_blocks = [
        block
        for block in LESSON_SPANS
        if block[0] >= lesson_start and block[1] <= lesson_end
    ]
    return lesson_blocks or [(lesson_start, lesson_end)]


def _parse_home_weeks(raw_time: str) -> str:
    match = re.search(r"第([0-9,-]+)周", raw_time)
    if not match:
        return ""
    return f"{match.group(1)}(周)"


def parse_schedule_html(html: str) -> NormalizedSchedule:
    soup = BeautifulSoup(html, "html.parser")
    semester = soup.find("div", {"id": "timetableDiv"})
    semester_label = semester.get_text(strip=True) if semester else ""
    table = soup.find("table", {"id": "kbtable"})

    courses: list[NormalizedCourse] = []
    if table is not None:
        rows = table.find_all("tr")[1:]
        for row_idx, row in enumerate(rows[: len(LESSON_SPANS)]):
            cells = row.find_all("td")[:7]
            lesson_start, lesson_end = LESSON_SPANS[row_idx]

            for day_idx, cell in enumerate(cells):
                for div in cell.find_all("div", class_="kbcontent1"):
                    if "sykb1" in div.get("class", []):
                        continue

                    for block in str(div).split("----------------------"):
                        block_soup = BeautifulSoup(block, "html.parser")
                        lines = [
                            line
                            for line in block_soup.stripped_strings
                            if not line.startswith("&nbsp")
                        ]
                        if not lines:
                            continue

                        course_name, course_code = split_course_name_code(lines[0])

                        teacher = ""
                        location = ""
                        weeks = ""
                        for line in lines[1:]:
                            if "(周)" in line:
                                weeks = line
                            elif not location and line:
                                location = line
                            elif (
                                not teacher
                                and location
                                and line
                                and len(line) <= 8
                                and not any(char.isdigit() for char in line)
                            ):
                                teacher = line

                        courses.append(
                            NormalizedCourse(
                                name=course_name,
                                code=course_code,
                                teacher=teacher,
                                room=extract_location_code(location),
                                weekday=day_idx + 1,
                                lesson_start=lesson_start,
                                lesson_end=lesson_end,
                                raw_weeks=weeks,
                                parsed_weeks=parse_weeks(weeks),
                            )
                        )
    else:
        home_table = soup.find("table", {"id": "tab1"}) or soup.find(
            "table",
            class_="kb_table",
        )
        if home_table is not None:
            courses = parse_home_schedule_table(home_table)

    return NormalizedSchedule(
        semester_label=semester_label,
        generated_at="generated-at-runtime",
        courses=courses,
    )
