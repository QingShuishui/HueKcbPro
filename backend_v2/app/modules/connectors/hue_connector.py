from datetime import datetime, timezone

import requests

try:
    import ddddocr
except ImportError:
    ddddocr = None

from app.modules.connectors.base import AcademicConnector, NormalizedSchedule
from app.modules.connectors.errors import InvalidCredentialsError
from app.modules.connectors.hue_parser import parse_schedule_html


class HUEConnector(AcademicConnector):
    connector_key = "hue"
    base_url = "https://jwxt.hue.edu.cn"

    def parse_schedule_html(self, html: str) -> NormalizedSchedule:
        result = parse_schedule_html(html)
        result.generated_at = datetime.now(timezone.utc).isoformat()
        return result

    def fetch_schedule(self, username: str, password: str) -> NormalizedSchedule:
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

        table_response = session.get(
            f"{self.base_url}/jsxsd/xskb/xskb_list.do",
            timeout=10,
        )
        return self.parse_schedule_html(table_response.text)
