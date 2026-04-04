from __future__ import annotations

import hashlib
import json
import shutil
from datetime import datetime, timezone
from email import policy
from email.parser import BytesParser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


BASE_DIR = Path(__file__).resolve().parent
DOWNLOADS_DIR = BASE_DIR / "downloads"
STORAGE_DIR = BASE_DIR / "storage"
LATEST_ANDROID_JSON = STORAGE_DIR / "latest-android.json"
DEFAULT_HOST = "0.0.0.0"
DEFAULT_PORT = 8000

DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)
STORAGE_DIR.mkdir(parents=True, exist_ok=True)
if not LATEST_ANDROID_JSON.exists():
    LATEST_ANDROID_JSON.write_text("{}", encoding="utf-8")


def compute_sha256(file_path: Path) -> str:
    digest = hashlib.sha256()
    with file_path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_metadata() -> dict:
    try:
        return json.loads(LATEST_ANDROID_JSON.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def write_metadata(metadata: dict) -> None:
    LATEST_ANDROID_JSON.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


class UpdateRequestHandler(BaseHTTPRequestHandler):
    server_version = "KcbUpdateServer/1.0"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/update/android":
            self._serve_android_metadata()
            return

        if parsed.path.startswith("/downloads/"):
            self._serve_download(parsed.path.removeprefix("/downloads/"))
            return

        self._send_json({"error": "not_found"}, status=HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/api/admin/upload":
            self._send_json({"error": "not_found"}, status=HTTPStatus.NOT_FOUND)
            return

        form = self._parse_multipart_form()
        upload = form.get("file")
        if upload is None or not upload.get("filename"):
            self._send_json({"error": "missing_file"}, status=HTTPStatus.BAD_REQUEST)
            return

        version = str(form.get("version", {}).get("value", "")).strip()
        build_number_raw = str(form.get("build_number", {}).get("value", "")).strip()
        force_update_raw = str(
            form.get("force_update", {}).get("value", "false")
        ).strip().lower()
        notes = str(form.get("notes", {}).get("value", "")).strip()

        if not version or not build_number_raw.isdigit():
            self._send_json(
                {"error": "invalid_version_fields"},
                status=HTTPStatus.BAD_REQUEST,
            )
            return

        filename = Path(str(upload["filename"])).name
        if not filename.endswith(".apk"):
            self._send_json({"error": "invalid_file_type"}, status=HTTPStatus.BAD_REQUEST)
            return

        destination = DOWNLOADS_DIR / filename
        with destination.open("wb") as target:
            target.write(upload["content"])

        host = self.headers.get("Host", f"127.0.0.1:{self.server.server_port}")
        metadata = {
            "platform": "android",
            "version": version,
            "build_number": int(build_number_raw),
            "force_update": force_update_raw == "true",
            "notes": notes,
            "apk_url": f"http://{host}/downloads/{filename}",
            "sha256": compute_sha256(destination),
            "published_at": datetime.now(timezone.utc).isoformat(),
        }
        write_metadata(metadata)
        self._send_json(metadata)

    def log_message(self, format: str, *args) -> None:
        return

    def _serve_android_metadata(self) -> None:
        metadata = read_metadata()
        if not metadata:
            self._send_json(
                {"error": "no_release"},
                status=HTTPStatus.NOT_FOUND,
            )
            return

        self._send_json(metadata)

    def _serve_download(self, relative_path: str) -> None:
        file_path = (DOWNLOADS_DIR / relative_path).resolve()
        if DOWNLOADS_DIR.resolve() not in file_path.parents or not file_path.exists():
            self._send_json({"error": "not_found"}, status=HTTPStatus.NOT_FOUND)
            return

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/vnd.android.package-archive")
        self.send_header("Content-Length", str(file_path.stat().st_size))
        self.end_headers()

        with file_path.open("rb") as source:
            shutil.copyfileobj(source, self.wfile)

    def _send_json(self, payload: dict, status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _parse_multipart_form(self) -> dict:
        content_type = self.headers.get("Content-Type", "")
        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)
        message = BytesParser(policy=policy.default).parsebytes(
            (
                f"Content-Type: {content_type}\r\n"
                "MIME-Version: 1.0\r\n\r\n"
            ).encode("utf-8")
            + raw_body
        )

        if not message.is_multipart():
            return {}

        fields: dict[str, dict] = {}
        for part in message.iter_parts():
            name = part.get_param("name", header="content-disposition")
            if not name:
                continue

            fields[name] = {
                "filename": part.get_filename(),
                "value": part.get_content().strip()
                if part.get_content_maintype() == "text"
                else None,
                "content": part.get_payload(decode=True),
            }

        return fields


def run(host: str = DEFAULT_HOST, port: int = DEFAULT_PORT) -> None:
    server = ThreadingHTTPServer((host, port), UpdateRequestHandler)
    print(f"Serving update backend on http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    run()
