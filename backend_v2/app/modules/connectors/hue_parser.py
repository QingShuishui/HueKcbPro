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

                        raw_name = lines[0]
                        course_name = raw_name
                        course_code = ""
                        if " " in raw_name:
                            parts = raw_name.rsplit(" ", 1)
                            code_candidate = parts[1].strip()
                            looks_like_code = bool(
                                re.fullmatch(r"[A-Za-z0-9-]{2,12}", code_candidate)
                            )
                            alpha_only_code = code_candidate.isalpha()
                            roman_suffix = code_candidate.upper() in ROMAN_NUMERAL_SUFFIXES
                            if (
                                looks_like_code
                                and not roman_suffix
                                and (not alpha_only_code or len(code_candidate) >= 3)
                            ):
                                course_name = parts[0]
                                course_code = code_candidate

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

    return NormalizedSchedule(
        semester_label=semester_label,
        generated_at="generated-at-runtime",
        courses=courses,
    )
