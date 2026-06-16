from datetime import date
from unittest.mock import Mock, patch

from app.modules.connectors import hue_connector
from app.modules.connectors.base import NormalizedSchedule
from app.modules.connectors.hue_connector import FALLBACK_WEEK_COUNT, HUEConnector
from app.modules.schedule.service import normalize_connector_schedule


def _schedule_html(
    *,
    semester: str = "2026春",
    name: str = "软件测试技术 SIT",
    room: str = "S101",
    weeks: str = "1(周)",
    teacher: str = "张三",
) -> str:
    return f"""
    <div id="timetableDiv">{semester}</div>
    <table id="kbtable">
      <tr><th></th><th>周一</th></tr>
      <tr>
        <td>
          <div class="kbcontent1">
            {name}<br/>
            {room}<br/>
            {weeks}<br/>
            {teacher}
          </div>
        </td>
      </tr>
    </table>
    """


def _response(**kwargs):
    defaults = {
        "text": "",
        "content": b"",
        "status_code": 200,
        "url": "https://jwxt.hue.edu.cn",
    }
    defaults.update(kwargs)
    return type("R", (), defaults)()


def test_connector_fallback_checks_twenty_weeks_by_default():
    assert FALLBACK_WEEK_COUNT == 20


@patch("app.modules.connectors.hue_connector.ddddocr.DdddOcr")
@patch("app.modules.connectors.hue_connector.requests.Session")
def test_connector_uses_supplied_credentials(session_cls, ocr_cls):
    session = session_cls.return_value
    ocr_cls.return_value.classification.return_value = "1234"

    response_home = type(
        "R",
        (),
        {"text": "", "status_code": 200, "url": "https://jwxt.hue.edu.cn"},
    )()
    response_sess = type(
        "R",
        (),
        {"text": "abc#111", "status_code": 200, "url": "https://jwxt.hue.edu.cn"},
    )()
    response_captcha = type(
        "R",
        (),
        {"content": b"img", "status_code": 200, "url": "https://jwxt.hue.edu.cn"},
    )()
    response_login = type(
        "R",
        (),
        {
            "text": "",
            "status_code": 200,
            "url": "https://jwxt.hue.edu.cn/xsMain.jsp",
        },
    )()
    response_table = type(
        "R",
        (),
        {
            "text": _schedule_html(),
            "status_code": 200,
            "url": "https://jwxt.hue.edu.cn",
        },
    )()
    session.get.side_effect = [
        response_home,
        response_sess,
        response_captcha,
        response_table,
    ]
    session.post.side_effect = [response_login]

    connector = HUEConnector()
    connector.fetch_schedule("demo_student_id", "pw123")

    post_data = session.post.call_args_list[0].kwargs["data"]
    assert "demo_student_id" not in post_data["encoded"]


@patch("app.modules.connectors.hue_connector.ddddocr.DdddOcr")
@patch("app.modules.connectors.hue_connector.requests.Session")
def test_connector_retries_transient_login_redirect_failures(session_cls, ocr_cls):
    sessions = [Mock(), Mock(), Mock()]
    session_cls.side_effect = sessions
    ocr_cls.return_value.classification.return_value = "1234"

    for session in sessions[:2]:
        session.get.side_effect = [
            _response(),
            _response(text="abc#111"),
            _response(content=b"img"),
        ]
    sessions[2].get.side_effect = [
        _response(),
        _response(text="abc#111"),
        _response(content=b"img"),
        _response(text=_schedule_html()),
    ]

    failed_login = _response(url="https://jwxt.hue.edu.cn/Logon.do?method=logon")
    successful_login = _response(url="https://jwxt.hue.edu.cn/xsMain.jsp")
    sessions[0].post.return_value = failed_login
    sessions[1].post.return_value = failed_login
    sessions[2].post.return_value = successful_login

    result = HUEConnector().fetch_schedule("demo_student_id", "pw123")

    assert result.semester_label == "2026春"
    assert session_cls.call_count == 3
    assert sessions[0].post.call_count == 1
    assert sessions[1].post.call_count == 1
    assert sessions[2].post.call_count == 1


@patch("app.modules.connectors.hue_connector.ddddocr.DdddOcr")
@patch("app.modules.connectors.hue_connector.requests.Session")
def test_connector_uses_default_schedule_endpoint(session_cls, ocr_cls):
    session = session_cls.return_value
    ocr_cls.return_value.classification.return_value = "1234"

    session.get.side_effect = [
        _response(),
        _response(text="abc#111"),
        _response(content=b"img"),
        _response(
            text=_schedule_html(semester="2025秋"),
            url="https://jwxt.hue.edu.cn/jsxsd/xskb/xskb_list.do",
        ),
    ]
    session.post.side_effect = [_response(url="https://jwxt.hue.edu.cn/xsMain.jsp")]

    result = HUEConnector().fetch_schedule("demo_student_id", "pw123")

    assert result.semester_label == "2025秋"
    assert len(session.post.call_args_list) == 1
    schedule_call = session.get.call_args_list[3]
    assert schedule_call.args[0] == "https://jwxt.hue.edu.cn/jsxsd/xskb/xskb_list.do"
    assert "data" not in schedule_call.kwargs


@patch("app.modules.connectors.hue_connector.ddddocr.DdddOcr")
@patch("app.modules.connectors.hue_connector.requests.Session")
def test_connector_falls_back_to_weekly_endpoint_when_default_schedule_is_empty(
    session_cls, ocr_cls, monkeypatch
):
    session = session_cls.return_value
    ocr_cls.return_value.classification.return_value = "1234"
    monkeypatch.setattr("app.modules.connectors.hue_connector.FALLBACK_WEEK_COUNT", 2)
    fallback_calls = []

    def fake_week(self, _session, week, request_date):
        fallback_calls.append((week, request_date.isoformat()))
        room = "S101" if week == 1 else "S102"
        return self.parse_schedule_html(_schedule_html(room=room))

    monkeypatch.setattr(HUEConnector, "_fetch_fallback_week", fake_week)

    session.get.side_effect = [
        _response(),
        _response(text="abc#111"),
        _response(content=b"img"),
        _response(
            text="<div id='timetableDiv'>2026春</div><table id='kbtable'></table>",
            url="https://jwxt.hue.edu.cn/jsxsd/xskb/xskb_list.do",
        ),
    ]
    session.post.side_effect = [_response(url="https://jwxt.hue.edu.cn/xsMain.jsp")]

    result = HUEConnector().fetch_schedule("demo_student_id", "pw123")

    assert result.semester_label == "2026春"
    assert len(result.courses) == 1
    assert result.courses[0].room == "S101, S102"
    assert result.courses[0].raw_weeks == "1-2(周)"
    assert result.courses[0].parsed_weeks == [1, 2]
    assert sorted(fallback_calls) == [(1, "2026-03-02"), (2, "2026-03-09")]


def test_fetch_fallback_week_posts_week_date_with_authenticated_session(monkeypatch):
    source_session = Mock()
    source_session.headers = {"User-Agent": "test-agent"}
    source_session.cookies = {"JSESSIONID": "abc123"}
    worker_session = Mock()
    worker_session.headers = {}
    worker_session.cookies = {}
    worker_session.post.return_value = _response(text=_schedule_html())
    monkeypatch.setattr(hue_connector.requests, "Session", lambda: worker_session)

    result = HUEConnector()._fetch_fallback_week(
        source_session,
        week=2,
        request_date=date(2026, 3, 9),
    )

    assert result.semester_label == "2026春"
    assert worker_session.headers["User-Agent"] == "test-agent"
    assert worker_session.cookies["JSESSIONID"] == "abc123"
    worker_session.post.assert_called_once_with(
        "https://jwxt.hue.edu.cn/jsxsd/framework/main_index_loadkb.jsp",
        data={"rq": "2026-03-09"},
        headers={
            "Accept": "text/html, */*; q=0.01",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6",
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "Referer": "https://jwxt.hue.edu.cn/jsxsd/framework/xsMain_new.jsp?t1=1",
            "X-Requested-With": "XMLHttpRequest",
        },
        timeout=10,
    )


def test_fallback_result_normalizes_to_main_schedule_payload_shape(monkeypatch):
    monkeypatch.setattr("app.modules.connectors.hue_connector.FALLBACK_WEEK_COUNT", 1)
    monkeypatch.setattr(
        HUEConnector,
        "_fetch_fallback_week",
        lambda self, _session, _week, _request_date: self.parse_schedule_html(
            _schedule_html()
        ),
        raising=False,
    )

    schedule = HUEConnector()._fetch_fallback_schedule(Mock(), semester_label="2026春")

    payload = normalize_connector_schedule(schedule)

    assert set(payload) == {
        "semester_label",
        "generated_at",
        "courses",
        "schedule_hash",
    }
    assert set(payload["courses"][0]) == {
        "name",
        "code",
        "teacher",
        "room",
        "weekday",
        "lesson_start",
        "lesson_end",
        "raw_weeks",
        "parsed_weeks",
    }


def test_connector_dispatches_fallback_weeks_with_twenty_workers(monkeypatch):
    class CompletedFuture:
        def __init__(self, value):
            self.value = value

        def result(self):
            return self.value

    class RecordingExecutor:
        instances = []

        def __init__(self, max_workers):
            self.max_workers = max_workers
            self.submitted = []
            RecordingExecutor.instances.append(self)

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, traceback):
            return False

        def submit(self, fn, *args):
            self.submitted.append((fn, args))
            return CompletedFuture(fn(*args))

    def fake_week(self, _session, week, _request_date):
        return NormalizedSchedule(
            semester_label="2026春",
            generated_at="now",
            courses=[],
        )

    monkeypatch.setattr(hue_connector, "ThreadPoolExecutor", RecordingExecutor, raising=False)
    monkeypatch.setattr(hue_connector, "as_completed", lambda futures: futures, raising=False)
    monkeypatch.setattr(HUEConnector, "_fetch_fallback_week", fake_week, raising=False)

    HUEConnector()._fetch_fallback_schedule(Mock(), semester_label="2026春")

    assert len(RecordingExecutor.instances) == 1
    assert RecordingExecutor.instances[0].max_workers == FALLBACK_WEEK_COUNT
    assert len(RecordingExecutor.instances[0].submitted) == FALLBACK_WEEK_COUNT


def test_parser_reads_fixture_into_normalized_courses():
    html = """
    <div id="timetableDiv">2026春</div>
    <table id="kbtable">
      <tr>
        <th></th><th>周一</th>
      </tr>
      <tr>
        <td>
          <div class="kbcontent1">
            软件测试技术 SIT<br/>
            S4409计算机专业实验室<br/>
            1-16(周)<br/>
            张三
          </div>
        </td>
      </tr>
    </table>
    """

    result = HUEConnector().parse_schedule_html(html)

    assert result.semester_label == "2026春"
    assert len(result.courses) == 1
    assert result.courses[0].name == "软件测试技术"
    assert result.courses[0].code == "SIT"
    assert result.courses[0].room == "S4409"
    assert result.courses[0].teacher == "张三"
    assert result.courses[0].weekday == 1
    assert result.courses[0].lesson_start == 1
    assert result.courses[0].lesson_end == 2


def test_parser_reads_alphanumeric_course_code():
    html = """
    <div id="timetableDiv">2026春</div>
    <table id="kbtable">
      <tr>
        <th></th><th>周一</th>
      </tr>
      <tr>
        <td>
          <div class="kbcontent1">
            程序设计基础 CS101<br/>
            S1101<br/>
            1-16(周)<br/>
            李四
          </div>
        </td>
      </tr>
    </table>
    """

    result = HUEConnector().parse_schedule_html(html)

    assert result.courses[0].name == "程序设计基础"
    assert result.courses[0].code == "CS101"


def test_parser_reads_home_kb_table_fallback_html():
    html = """
    <table id="tab1" class="table kb_table">
      <tr>
        <th>周/节次</th>
        <th>星期一</th>
        <th>星期二</th>
        <th>星期三</th>
        <th>星期四</th>
        <th>星期五</th>
        <th>星期六</th>
        <th>星期日</th>
      </tr>
      <tr>
        <td>上午1-2节<br/>(01,02小节)<br/>08:00-09:40</td>
        <td></td>
        <td>
          <p title="课程学分：3.5&lt;br/&gt;课程属性：必修&lt;br/&gt;课程名称：数据库原理&lt;br/&gt;上课时间：第16周 星期二 [01-02]节&lt;br/&gt;上课地点：BY509">数据库原理<br/>BY509</p>
        </td>
      </tr>
      <tr>
        <td>上午3-4节<br/>(03,04小节)<br/>10:00-11:40</td>
        <td>
          <p title="课程学分：3.5&lt;br/&gt;课程属性：必修&lt;br/&gt;课程名称：计算机组成原理 CS101&lt;br/&gt;上课时间：第16周 星期一 [03-04]节&lt;br/&gt;上课地点：S4108人工智能实验室">计算机组成原..<br/>S4108人工智能实验室</p>
        </td>
      </tr>
      <tr>
        <td>下午5-6节<br/>(05,06小节)<br/>14:00-15:40</td>
        <td></td><td></td><td></td>
        <td>
          <p title="课程学分：6&lt;br/&gt;课程属性：必修&lt;br/&gt;课程名称：高等数学AⅡ&lt;br/&gt;上课时间：第16周 星期四 [05-06-07-08]节&lt;br/&gt;上课地点：10107">高等数学AⅡ..</p>
        </td>
      </tr>
    </table>
    """

    result = HUEConnector().parse_schedule_html(html)

    assert len(result.courses) == 3
    assert result.courses[0].name == "数据库原理"
    assert result.courses[0].code == ""
    assert result.courses[0].room == "BY509"
    assert result.courses[0].weekday == 2
    assert result.courses[0].lesson_start == 1
    assert result.courses[0].lesson_end == 2
    assert result.courses[0].raw_weeks == "16(周)"
    assert result.courses[0].parsed_weeks == [16]
    assert result.courses[1].name == "计算机组成原理"
    assert result.courses[1].code == "CS101"
    assert result.courses[1].room == "S4108"
    assert result.courses[1].weekday == 1
    assert result.courses[1].lesson_start == 3
    assert result.courses[1].lesson_end == 4
    assert result.courses[2].name == "高等数学AⅡ"
    assert result.courses[2].lesson_start == 5
    assert result.courses[2].lesson_end == 8


def test_parser_keeps_roman_numeral_suffix_in_course_name():
    html = """
    <div id="timetableDiv">2026春</div>
    <table id="kbtable">
      <tr>
        <th></th><th>周一</th>
      </tr>
      <tr>
        <td>
          <div class="kbcontent1">
            课程综合英语 IV<br/>
            3304<br/>
            1-16(周)<br/>
            王老师
          </div>
        </td>
      </tr>
    </table>
    """

    result = HUEConnector().parse_schedule_html(html)

    assert result.courses[0].name == "课程综合英语 IV"
    assert result.courses[0].code == ""
