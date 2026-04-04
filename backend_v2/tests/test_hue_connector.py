from unittest.mock import patch

from app.modules.connectors.hue_connector import HUEConnector


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
        response_table,
    ]
    session.post.return_value = response_login

    connector = HUEConnector()
    connector.fetch_schedule("demo_student_id", "pw123")

    post_data = session.post.call_args.kwargs["data"]
    assert "demo_student_id" not in post_data["encoded"]


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
