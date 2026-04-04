from pydantic import BaseModel


class CourseOut(BaseModel):
    name: str
    code: str
    teacher: str
    room: str
    weekday: int
    lesson_start: int
    lesson_end: int
    raw_weeks: str
    parsed_weeks: list[int]


class ScheduleOut(BaseModel):
    semester_label: str
    generated_at: str
    is_stale: bool
    last_synced_at: str | None
    courses: list[CourseOut]
