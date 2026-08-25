from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import replace
from datetime import date, datetime, timedelta, timezone
import re

import requests
from bs4 import BeautifulSoup

try:
    import ddddocr
except ImportError:
    ddddocr = None

from app.core.settings import get_settings
from app.modules.connectors.base import AcademicConnector, NormalizedCourse, NormalizedSchedule
from app.modules.connectors.errors import InvalidCredentialsError
from app.modules.connectors.hue_parser import parse_schedule_html


FALLBACK_WEEK_COUNT = 20
MINIMUM_SEMESTER_WEEKS = 18
CALENDAR_PROBE_WEEKS = 10
FALLBACK_REQUEST_HEADERS = {
    "Accept": "text/html, */*; q=0.01",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "Referer": "https://jwxt.hue.edu.cn/jsxsd/framework/xsMain_new.jsp?t1=1",
    "X-Requested-With": "XMLHttpRequest",
}


class HUEConnector(AcademicConnector):
    connector_key = "hue"
    base_url = "https://jwxt.hue.edu.cn"
    max_login_attempts = 3

    def parse_schedule_html(self, html: str) -> NormalizedSchedule:
        result = parse_schedule_html(html)
        result.generated_at = datetime.now(timezone.utc).isoformat()
        return result

    def fetch_schedule(self, username: str, password: str) -> NormalizedSchedule:
        last_error: InvalidCredentialsError | None = None
        for _ in range(self.max_login_attempts):
            try:
                return self._fetch_schedule_for_session(
                    self._create_authenticated_session(username, password)
                )
            except InvalidCredentialsError as error:
                last_error = error

        if last_error is not None:
            raise last_error
        raise InvalidCredentialsError("invalid academic credentials")

    def fetch_academic_calendar(
        self,
        username: str,
        password: str,
    ) -> tuple[str, str, int]:
        """Detect the configured term once with the dedicated server account."""
        last_error: InvalidCredentialsError | None = None
        for _ in range(self.max_login_attempts):
            try:
                calendar = self._discover_academic_calendar(
                    self._create_authenticated_session(username, password)
                )
                if calendar is None:
                    raise RuntimeError("teaching calendar was not available")
                start_date, total_weeks = calendar
                end_date = start_date + timedelta(days=total_weeks * 7 - 1)
                return start_date.isoformat(), end_date.isoformat(), total_weeks
            except InvalidCredentialsError as error:
                last_error = error

        if last_error is not None:
            raise last_error
        raise RuntimeError("unable to detect teaching calendar")

    def _create_authenticated_session(
        self,
        username: str,
        password: str,
    ) -> requests.Session:
        if ddddocr is None:
            raise RuntimeError("ddddocr is required")

        session = requests.Session()
        session.get(self.base_url, timeout=10)
        sess_response = session.get(
            f"{self.base_url}/Logon.do?method=logon&flag=sess",
            timeout=10,
        )
        scode, sxh = sess_response.text.split("#")

        captcha_response = session.get(
            f"{self.base_url}/verifycode.servlet",
            timeout=10,
        )
        captcha = ddddocr.DdddOcr().classification(captcha_response.content)

        code = username + "%%%" + password
        encoded = ""
        sxh_list = [int(item) for item in sxh]
        for index, char in enumerate(code):
            if index < len(sxh_list):
                encoded += char + scode[: sxh_list[index]]
                scode = scode[sxh_list[index] :]
            else:
                encoded += code[index:]
                break

        login_response = session.post(
            f"{self.base_url}/Logon.do?method=logon",
            data={"useDogCode": "", "encoded": encoded, "RANDOMCODE": captcha},
            allow_redirects=True,
            timeout=10,
        )
        if "xsMain.jsp" not in login_response.url:
            raise InvalidCredentialsError("invalid academic credentials")
        return session

    def _fetch_schedule_for_session(self, session: requests.Session) -> NormalizedSchedule:
        default_schedule = self._fetch_default_schedule(session)
        if default_schedule is not None and default_schedule.courses:
            return default_schedule

        fallback_schedule = self._fetch_fallback_schedule(
            session,
            semester_label=default_schedule.semester_label if default_schedule else "",
        )
        if fallback_schedule.courses:
            return fallback_schedule

        return default_schedule or fallback_schedule

    def _discover_academic_calendar(
        self,
        session: requests.Session,
        *,
        today: date | None = None,
    ) -> tuple[date, int] | None:
        """Read the homepage teaching calendar instead of guessing its start date."""
        today = today or datetime.now(timezone(timedelta(hours=8))).date()
        for probe_date in _calendar_probe_dates(today):
            week_info = self._fetch_calendar_week(session, probe_date)
            if week_info is not None:
                week_number, total_weeks = week_info
                start_date = probe_date - timedelta(
                    days=probe_date.weekday() + (week_number - 1) * 7
                )
                return start_date, max(total_weeks, MINIMUM_SEMESTER_WEEKS)

            # HUE's preview does not always include the teaching-week label.
            # A date with courses still identifies its displayed academic week.
            if self._fetch_calendar_has_courses(session, probe_date):
                return probe_date - timedelta(days=probe_date.weekday()), MINIMUM_SEMESTER_WEEKS
        return None

    def _fetch_calendar_preview_html(
        self,
        session: requests.Session,
        probe_date: date,
    ) -> str | None:
        try:
            response = session.post(
                f"{self.base_url}/jsxsd/framework/main_index_loadkb.jsp",
                data={"rq": probe_date.isoformat()},
                headers=FALLBACK_REQUEST_HEADERS.copy(),
                timeout=10,
            )
        except requests.RequestException:
            return None
        if getattr(response, "status_code", 0) != 200:
            return None
        return response.text

    def _fetch_calendar_week(
        self,
        session: requests.Session,
        probe_date: date,
    ) -> tuple[int, int] | None:
        html = self._fetch_calendar_preview_html(session, probe_date)
        return _parse_calendar_week(html) if html is not None else None

    def _fetch_calendar_has_courses(
        self,
        session: requests.Session,
        probe_date: date,
    ) -> bool:
        html = self._fetch_calendar_preview_html(session, probe_date)
        return bool(self.parse_schedule_html(html).courses) if html is not None else False

    def _fetch_default_schedule(self, session: requests.Session) -> NormalizedSchedule | None:
        settings = get_settings()
        try:
            table_response = session.post(
                f"{self.base_url}/jsxsd/xskb/xskb_list.do",
                data={
                    "jx0404id": "",
                    "cj0701id": "",
                    "zc": "",
                    "demo": "",
                    "xnxq01id": settings.academic_term_id,
                    "sfFD": "1",
                },
                timeout=10,
            )
        except requests.RequestException:
            return None

        if table_response.status_code != 200:
            return None
        return self.parse_schedule_html(table_response.text)

    def _fetch_fallback_schedule(
        self,
        session: requests.Session,
        *,
        semester_label: str = "",
    ) -> NormalizedSchedule:
        start_date = _configured_semester_start_date()
        weekly_results: list[tuple[int, NormalizedSchedule]] = []

        with ThreadPoolExecutor(max_workers=FALLBACK_WEEK_COUNT) as executor:
            future_to_week = {}
            for week in range(1, FALLBACK_WEEK_COUNT + 1):
                request_date = start_date + timedelta(days=(week - 1) * 7)
                future = executor.submit(
                    self._fetch_fallback_week,
                    session,
                    week,
                    request_date,
                )
                future_to_week[future] = week

            for future in as_completed(future_to_week):
                try:
                    weekly_schedule = future.result()
                except Exception:
                    continue
                if weekly_schedule is None:
                    continue
                weekly_results.append((future_to_week[future], weekly_schedule))

        courses: list[NormalizedCourse] = []
        for week, weekly_schedule in sorted(weekly_results, key=lambda item: item[0]):
            if not semester_label:
                semester_label = weekly_schedule.semester_label
            courses.extend(
                replace(course, raw_weeks=f"{week}(周)", parsed_weeks=[week])
                for course in weekly_schedule.courses
            )

        return NormalizedSchedule(
            semester_label=semester_label,
            generated_at=datetime.now(timezone.utc).isoformat(),
            courses=_merge_course_weeks(courses),
        )

    def _fetch_fallback_week(
        self,
        session: requests.Session,
        week: int,
        request_date: date,
    ) -> NormalizedSchedule | None:
        worker_session = requests.Session()
        try:
            worker_session.headers.update(session.headers)
            worker_session.cookies.update(session.cookies)
        except (AttributeError, TypeError):
            pass

        try:
            response = worker_session.post(
                f"{self.base_url}/jsxsd/framework/main_index_loadkb.jsp",
                data={"rq": request_date.isoformat()},
                headers=FALLBACK_REQUEST_HEADERS.copy(),
                timeout=10,
            )
        except requests.RequestException:
            return None

        if response.status_code != 200:
            return None
        return self.parse_schedule_html(response.text)


def _merge_course_weeks(courses: list[NormalizedCourse]) -> list[NormalizedCourse]:
    merged: dict[tuple, NormalizedCourse] = {}
    rooms_by_key: dict[tuple, list[str]] = {}
    weeks_by_key: dict[tuple, set[int]] = {}

    for course in courses:
        key = (
            course.name,
            course.code,
            course.teacher,
            course.weekday,
            course.lesson_start,
            course.lesson_end,
        )
        if key not in merged:
            merged[key] = course
            rooms_by_key[key] = []
            weeks_by_key[key] = set()

        if course.room and course.room not in rooms_by_key[key]:
            rooms_by_key[key].append(course.room)
        weeks_by_key[key].update(course.parsed_weeks)

    return [
        NormalizedCourse(
            name=course.name,
            code=course.code,
            teacher=course.teacher,
            room=", ".join(rooms_by_key[key]),
            weekday=course.weekday,
            lesson_start=course.lesson_start,
            lesson_end=course.lesson_end,
            raw_weeks=_format_weeks(sorted(weeks_by_key[key])),
            parsed_weeks=sorted(weeks_by_key[key]),
        )
        for key, course in merged.items()
    ]


def _format_weeks(weeks: list[int]) -> str:
    if not weeks:
        return ""

    ranges: list[str] = []
    start = weeks[0]
    previous = weeks[0]
    for week in weeks[1:]:
        if week == previous + 1:
            previous = week
            continue
        ranges.append(_format_week_range(start, previous))
        start = previous = week
    ranges.append(_format_week_range(start, previous))
    return f"{','.join(ranges)}(周)"


def _format_week_range(start: int, end: int) -> str:
    if start == end:
        return str(start)
    return f"{start}-{end}"


def _calendar_probe_dates(today: date) -> list[date]:
    """Probe the configured term near its normal September/February start."""
    term_match = re.fullmatch(r"(\d{4})-(\d{4})-(\d+)", get_settings().academic_term_id)
    if term_match and term_match.group(3) == "1":
        anchor = date(int(term_match.group(1)), 8, 17)
    elif term_match and term_match.group(3) == "2":
        anchor = date(int(term_match.group(2)), 2, 2)
    elif today.month >= 7:
        anchor = date(today.year, 8, 17)
    else:
        anchor = date(today.year, 2, 2)

    first_monday = anchor - timedelta(days=anchor.weekday())
    return [
        first_monday + timedelta(days=week * 7)
        for week in range(CALENDAR_PROBE_WEEKS)
    ]


def _configured_semester_start_date() -> date:
    from app.modules.calendar.service import get_current_academic_calendar

    calendar = get_current_academic_calendar()
    if calendar is not None:
        return date.fromisoformat(calendar["semester_start_date"])
    return datetime.strptime(
        get_settings().academic_semester_start_date, "%Y-%m-%d"
    ).date()


def _parse_calendar_week(html: str) -> tuple[int, int] | None:
    text = BeautifulSoup(html, "html.parser").get_text(" ", strip=True)
    match = re.search(r"第\s*(\d+)\s*周\s*/\s*(\d+)\s*周", text)
    if match is None:
        return None
    return int(match.group(1)), int(match.group(2))
