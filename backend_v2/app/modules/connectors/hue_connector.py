from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import replace
from datetime import date, datetime, timedelta, timezone

import requests

try:
    import ddddocr
except ImportError:
    ddddocr = None

from app.core.settings import get_settings
from app.modules.connectors.base import AcademicConnector, NormalizedCourse, NormalizedSchedule
from app.modules.connectors.errors import InvalidCredentialsError
from app.modules.connectors.hue_parser import parse_schedule_html


FALLBACK_WEEK_COUNT = 20
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
        if ddddocr is None:
            raise RuntimeError("ddddocr is required")

        last_error: InvalidCredentialsError | None = None
        for _ in range(self.max_login_attempts):
            try:
                return self._fetch_schedule_once(username, password)
            except InvalidCredentialsError as error:
                last_error = error

        if last_error is not None:
            raise last_error
        raise InvalidCredentialsError("invalid academic credentials")

    def _fetch_schedule_once(self, username: str, password: str) -> NormalizedSchedule:
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

    def _fetch_default_schedule(self, session: requests.Session) -> NormalizedSchedule | None:
        try:
            table_response = session.get(
                f"{self.base_url}/jsxsd/xskb/xskb_list.do",
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
        start_date = datetime.strptime(
            get_settings().academic_semester_start_date,
            "%Y-%m-%d",
        ).date()
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
