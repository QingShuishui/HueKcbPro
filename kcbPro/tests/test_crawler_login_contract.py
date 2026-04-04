from unittest.mock import patch

import importlib
import builtins

import utils.crawler as crawler


@patch("utils.crawler.parse_table", return_value=[])
@patch("utils.crawler.ddddocr.DdddOcr")
@patch("utils.crawler.requests.Session")
def test_login_and_get_schedule_uses_supplied_credentials(
    session_cls, ocr_cls, _parse_table
):
    session = session_cls.return_value
    ocr_cls.return_value.classification.return_value = "1234"

    response_home = type(
        "R", (), {"text": "", "status_code": 200, "url": "https://jwxt.hue.edu.cn"}
    )()
    response_sess = type(
        "R", (), {"text": "abc#111", "status_code": 200, "url": "https://jwxt.hue.edu.cn"}
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
    session.get.side_effect = [response_home, response_sess, response_captcha, response_table]
    session.post.return_value = response_login

    username = "demo_student_id"
    password = "pw123"
    crawler.login_and_get_schedule(username, password)

    post_data = session.post.call_args.kwargs["data"]
    assert "demo_student_id" not in post_data["encoded"]

    scode, sxh = response_sess.text.split("#")
    expected = _expected_encoded(username, password, scode, sxh)
    assert post_data["encoded"] == expected

    # Prove the function doesn't ignore the supplied credentials: a second
    # call with different credentials must produce a different encoded payload.
    session_2 = session_cls.return_value.__class__()
    session_cls.side_effect = [session_2]
    session_2.get.side_effect = [response_home, response_sess, response_captcha, response_table]
    session_2.post.return_value = response_login

    username_2 = "0000000000"
    password_2 = "pw999"
    crawler.login_and_get_schedule(username_2, password_2)
    post_data_2 = session_2.post.call_args.kwargs["data"]
    expected_2 = _expected_encoded(username_2, password_2, scode, sxh)
    assert post_data_2["encoded"] == expected_2
    assert post_data_2["encoded"] != post_data["encoded"]


def _expected_encoded(username: str, password: str, scode: str, sxh: str) -> str:
    code = username + "%%%" + password
    encoded = ""
    sxh_list = [int(x) for x in sxh]

    for i in range(len(code)):
        if i < len(sxh_list):
            encoded += code[i] + scode[0 : sxh_list[i]]
            scode = scode[sxh_list[i] :]
        else:
            encoded += code[i:]
            break
    return encoded


def test_login_and_get_schedule_does_not_exit_if_ddddocr_missing():
    real_import = builtins.__import__

    def fake_import(name, globals=None, locals=None, fromlist=(), level=0):
        if name == "ddddocr":
            raise ImportError("missing ddddocr for test")
        return real_import(name, globals, locals, fromlist, level)

    with patch("builtins.__import__", side_effect=fake_import):
        with patch("sys.exit", side_effect=AssertionError("sys.exit called")):
            reloaded = importlib.reload(crawler)

    result, err = reloaded.login_and_get_schedule("u", "p")
    assert result is None
    assert err is not None
    assert "ddddocr" in err.lower()
