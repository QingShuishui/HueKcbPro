from dataclasses import dataclass


@dataclass
class NormalizedCourse:
    name: str
    code: str
    teacher: str
    room: str
    weekday: int
    lesson_start: int
    lesson_end: int
    raw_weeks: str
    parsed_weeks: list[int]


@dataclass
class NormalizedSchedule:
    semester_label: str
    generated_at: str
    courses: list[NormalizedCourse]


class AcademicConnector:
    connector_key = "base"

    def validate_credentials(self, username: str, password: str) -> None:
        self.fetch_schedule(username, password)

    def fetch_schedule(self, username: str, password: str) -> NormalizedSchedule:
        raise NotImplementedError
