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

_GROUP_CONTENT_RE = re.compile(
    r"(?:分组|组别)\s*[0-9A-Za-z一二三四五六七八九十]+"
)
_GROUP_SUFFIX_RE = re.compile(
    r"^(?P<base>.*?)[(（]+\s*(?P<group>(?:分组|组别)\s*"
    r"[0-9A-Za-z一二三四五六七八九十]+)\s*[)）]+$"
)


def _group_suffix(value: str) -> str | None:
    match = _GROUP_CONTENT_RE.search(value or "")
    if match is None:
        return None
    group = re.sub(r"\s+", "", match.group(0))
    return f"({group})"


def _normalize_course_group_name(name: str, group_line: str | None = None) -> str:
    """Return one canonical ``课程名(分组XX)`` suffix.

    HUE has emitted both a grouped name and a separate group line in some
    timetable views. Normalizing before and after appending prevents output
    such as ``课程名((分组01))`` or a duplicated ``(分组01)(分组01)``.
    """
    normalized = re.sub(r"\s+", " ", name or "").strip()
    suffix = _group_suffix(group_line or "")
    if suffix is not None:
        existing = _GROUP_SUFFIX_RE.match(normalized)
        if existing is None or _group_suffix(existing.group("group")) != suffix:
            normalized = f"{normalized}{suffix}"

    existing = _GROUP_SUFFIX_RE.match(normalized)
    if existing is None:
        return normalized
    group = re.sub(r"\s+", "", existing.group("group"))
    return f"{existing.group('base').rstrip()}({group})"


def extract_location_code(location: str) -> str:
    if not location:
        return location

    if re.search(r"APP\s*线上(?:课程)?学习", location, re.IGNORECASE):
        return "APP线上课程学习"

    match = re.match(r"^[A-Za-z0-9]+", location)
    return match.group(0) if match else location


def _is_location_line(line: str) -> bool:
    if not line:
        return False
    return bool(
        re.search(r"^[A-Za-z]{1,4}-?\d{3,5}(?:\D|$)", line)
        or re.search(r"^\d{3,5}(?:\D|$)", line)
        or re.search(r"(?:楼栋室号|实验室|教室|教学楼|体育馆|校区|报告厅|操场)", line)
        or re.search(r"(?:^|\s)(?:报|综|机|理|文|艺|体|教|实|阶|培|训|创|学)\s*\d{1,4}(?:\D|$)", line)
        or re.search(r"APP\s*线上(?:课程)?学习", line, re.IGNORECASE)
    )


def _parse_teacher_and_room(lines: list[str]) -> tuple[str, str, str]:
    """Extract week, teacher and room without assuming their display order.

    HUE renders both `teacher -> week -> room` and `room -> week -> teacher`
    depending on the timetable view. Room-like values are identified first;
    the remaining human-readable value is kept as the complete teacher name.
    """
    weeks = ""
    details: list[str] = []
    for line in lines:
        if "(周)" in line and not weeks:
            weeks = line
        elif line:
            details.append(line.strip())

    location_indices = [
        index for index, line in enumerate(details) if _is_location_line(line)
    ]
    if location_indices:
        location = "、".join(details[index] for index in location_indices)
        teacher_values = [
            line for index, line in enumerate(details) if index not in location_indices
        ]
        teacher = "、".join(teacher_values)
    elif len(details) >= 2:
        # When a room has no recognizable prefix, HUE's detail order is
        # teacher followed by room (e.g. `龚希` then `报4`).
        teacher = "、".join(details[:-1])
        location = details[-1]
    elif details:
        teacher, location = details[0], ""
    else:
        teacher, location = "", ""
    return teacher, extract_location_code(location), weeks


def _teacher_from_markup(markup) -> str:
    """Read a teacher stored in a timetable node's metadata.

    Some HUE deployments keep the visible cell compact and put the full
    course details in ``title``/``data-*`` attributes instead.
    """
    for element in markup.find_all(True):
        for key, value in element.attrs.items():
            key_lower = key.lower()
            if key_lower in {"class", "style", "id", "href", "src"}:
                continue
            values = value if isinstance(value, list) else [value]
            for raw_value in values:
                raw_text = str(raw_value).strip()
                if not raw_text:
                    continue
                metadata = BeautifulSoup(raw_text, "html.parser")
                fields = _parse_home_course_title(raw_text)
                for label in ("任课教师", "授课教师", "上课教师", "教师", "老师"):
                    teacher = fields.get(label, "").strip()
                    if teacher:
                        return teacher
                plain_text = metadata.get_text(" ", strip=True)
                match = re.search(
                    r"(?:任课教师|授课教师|上课教师|教师|老师)\s*[:：]\s*"
                    r"([^,，;；|]+)",
                    plain_text,
                )
                if match:
                    return match.group(1).strip()
                # Some pages put a JSON-like key in data attributes or an
                # inline handler instead of using a human-readable label.
                match = re.search(
                    r"[\"']?(?:teacher|teacherName|teacher_name)[\"']?\s*[:=]\s*"
                    r"[\"']([^\"']+)[\"']",
                    raw_text,
                    re.IGNORECASE,
                )
                if match:
                    return match.group(1).strip()
    return ""


def _teacher_from_detail_markup(markup) -> str:
    """Read the explicit teacher node from HUE's hidden course details.

    ``xskb_list.do`` renders a compact ``kbcontent1`` preview and a matching
    hidden ``kbcontent`` node.  The latter contains ``<font title='老师'>``
    even when the visible preview omits the teacher completely.
    """
    for element in markup.find_all(True):
        title = str(element.get("title", "")).strip()
        if title and any(label in title for label in ("老师", "教师", "任课")):
            teacher = element.get_text(" ", strip=True)
            if teacher:
                return teacher
    return _teacher_from_markup(markup)


def _split_course_blocks(markup: str) -> list[str]:
    """Split visible and hidden timetable markup on either dash separator."""
    return re.split(r"-{10,}", markup)


def parse_weeks(week_str: str) -> list[int]:
    if not week_str or "(周)" not in week_str:
        return []

    # The timetable often puts lesson numbers on the same line, e.g.
    # `1-16(周)[05-06节]`; strip that bracket before parsing week ranges.
    week_str = re.sub(r"\[.*?\]", "", week_str)
    week_str = week_str.replace("(周)", "").strip()
    weeks: list[int] = []
    for part in week_str.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            range_match = re.fullmatch(r"(\d+)\s*-\s*(\d+)", part)
            if range_match is None:
                continue
            start, end = (int(value) for value in range_match.groups())
            weeks.extend(range(start, end + 1))
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
                # Some HUE deployments expose the teacher only in the title
                # metadata of the home timetable, while others omit the field
                # entirely. Preserve every known spelling when it is present.
                teacher = next(
                    (
                        fields.get(key, "").strip()
                        for key in (
                            "任课教师",
                            "授课教师",
                            "教师",
                            "老师",
                        )
                        if fields.get(key, "").strip()
                    ),
                    "",
                )
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
                            teacher=teacher,
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

                    visible_blocks = _split_course_blocks(str(div))
                    visible_id = div.get("id", "")
                    detail_ids = {visible_id}
                    if visible_id.endswith("-1"):
                        detail_ids.add(f"{visible_id[:-2]}-2")
                    detail_div = next(
                        (
                            candidate
                            for candidate in cell.find_all("div")
                            if candidate.get("id") in detail_ids
                            and "kbcontent" in candidate.get("class", [])
                            and "kbcontent1" not in candidate.get("class", [])
                        ),
                        None,
                    )
                    detail_blocks = (
                        _split_course_blocks(str(detail_div))
                        if detail_div is not None
                        else []
                    )

                    for block_index, block in enumerate(visible_blocks):
                        block_soup = BeautifulSoup(block, "html.parser")
                        lines = [
                            line
                            for line in block_soup.stripped_strings
                            if not line.startswith("&nbsp")
                        ]
                        if not lines:
                            continue

                        course_name, course_code = split_course_name_code(lines[0])
                        course_name = _normalize_course_group_name(course_name)

                        group_line = next(
                            (
                                line
                                for line in lines[1:]
                                if re.search(
                                    r"(?:分组|组别)\s*[0-9A-Za-z一二三四五六七八九十]+",
                                    line,
                                )
                            ),
                            None,
                        )
                        if group_line is not None:
                            course_name = _normalize_course_group_name(
                                course_name,
                                group_line,
                            )
                            lines.remove(group_line)

                        teacher, location, weeks = _parse_teacher_and_room(lines[1:])
                        if block_index < len(detail_blocks):
                            teacher = _teacher_from_detail_markup(
                                BeautifulSoup(detail_blocks[block_index], "html.parser")
                            ) or teacher
                        if not teacher:
                            teacher = _teacher_from_markup(block_soup)

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
