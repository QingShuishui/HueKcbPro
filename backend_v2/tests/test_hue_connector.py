from unittest.mock import Mock, patch

from app.modules.connectors.hue_connector import HUEConnector


def _response(**kwargs):
    defaults = {
        "text": "",
        "content": b"",
        "status_code": 200,
        "url": "https://jwxt.hue.edu.cn",
    }
    defaults.update(kwargs)
    return type("R", (), defaults)()


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
            "text": "<div id='timetableDiv'>2026春</div><table id='kbtable'></table>",
            "status_code": 200,
            "url": "https://jwxt.hue.edu.cn",
        },
    )()
    session.get.side_effect = [
        response_home,
        response_sess,
        response_captcha,
    ]
    session.post.side_effect = [response_login, response_table]

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

    for session in sessions:
        session.get.side_effect = [
            _response(),
            _response(text="abc#111"),
            _response(content=b"img"),
        ]

    failed_login = _response(url="https://jwxt.hue.edu.cn/Logon.do?method=logon")
    successful_login = _response(url="https://jwxt.hue.edu.cn/xsMain.jsp")
    sessions[0].post.return_value = failed_login
    sessions[1].post.return_value = failed_login
    sessions[2].post.side_effect = [
        successful_login,
        _response(text="<div id='timetableDiv'>2026春</div><table id='kbtable'></table>"),
    ]

    result = HUEConnector().fetch_schedule("demo_student_id", "pw123")

    assert result.semester_label == "2026春"
    assert session_cls.call_count == 3
    assert sessions[0].post.call_count == 1
    assert sessions[1].post.call_count == 1
    assert sessions[2].post.call_count == 2


@patch("app.modules.connectors.hue_connector.ddddocr.DdddOcr")
@patch("app.modules.connectors.hue_connector.requests.Session")
def test_connector_posts_configured_course_term(session_cls, ocr_cls, monkeypatch):
    session = session_cls.return_value
    ocr_cls.return_value.classification.return_value = "1234"
    monkeypatch.setattr(
        "app.modules.connectors.hue_connector.COURSE_TERM_ID",
        "2025-2026-1",
    )

    session.get.side_effect = [
        _response(),
        _response(text="abc#111"),
        _response(content=b"img"),
    ]
    session.post.side_effect = [
        _response(url="https://jwxt.hue.edu.cn/xsMain.jsp"),
        _response(
            text="<div id='timetableDiv'>2025秋</div><table id='kbtable'></table>",
            url="https://jwxt.hue.edu.cn/jsxsd/xskb/xskb_list.do",
        ),
    ]

    result = HUEConnector().fetch_schedule("demo_student_id", "pw123")

    assert result.semester_label == "2025秋"
    schedule_call = session.post.call_args_list[1]
    assert schedule_call.args[0] == "https://jwxt.hue.edu.cn/jsxsd/xskb/xskb_list.do"
    assert schedule_call.kwargs["data"]["xnxq01id"] == "2025-2026-1"
    assert schedule_call.kwargs["data"]["sfFD"] == "1"


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
