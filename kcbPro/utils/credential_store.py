import sqlite3
from config import SEMESTER_START_DATE


class CredentialStore:
    def __init__(self, db_path):
        self.db_path = db_path

    def initialize(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS saved_logins (
                    token TEXT PRIMARY KEY,
                    username TEXT NOT NULL,
                    encrypted_password TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    last_accessed_at TEXT NOT NULL,
                    link_hint_seen INTEGER NOT NULL DEFAULT 0,
                    semester_start_date TEXT NOT NULL DEFAULT '2026-03-02'
                )
                """
            )
            columns = {
                row[1] for row in conn.execute("PRAGMA table_info(saved_logins)").fetchall()
            }
            if "link_hint_seen" not in columns:
                conn.execute(
                    "ALTER TABLE saved_logins ADD COLUMN link_hint_seen INTEGER NOT NULL DEFAULT 0"
                )
            if "semester_start_date" not in columns:
                conn.execute(
                    f"ALTER TABLE saved_logins ADD COLUMN semester_start_date TEXT NOT NULL DEFAULT '{SEMESTER_START_DATE}'"
                )

    def save_record(self, token, username, encrypted_password, created_at, last_accessed_at):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO saved_logins
                (
                    token, username, encrypted_password, created_at, last_accessed_at,
                    link_hint_seen, semester_start_date
                )
                VALUES (
                    ?, ?, ?, ?, ?,
                    COALESCE((SELECT link_hint_seen FROM saved_logins WHERE token = ?), 0),
                    COALESCE(
                        (SELECT semester_start_date FROM saved_logins WHERE token = ?),
                        ?
                    )
                )
                """,
                (
                    token,
                    username,
                    encrypted_password,
                    created_at,
                    last_accessed_at,
                    token,
                    token,
                    SEMESTER_START_DATE,
                ),
            )

    def get_record(self, token):
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute(
                """
                SELECT
                    token, username, encrypted_password, created_at, last_accessed_at,
                    link_hint_seen, semester_start_date
                FROM saved_logins
                WHERE token = ?
                """,
                (token,),
            ).fetchone()
        return dict(row) if row else None

    def touch_record(self, token, last_accessed_at):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "UPDATE saved_logins SET last_accessed_at = ? WHERE token = ?",
                (last_accessed_at, token),
            )

    def mark_link_hint_seen(self, token):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "UPDATE saved_logins SET link_hint_seen = 1 WHERE token = ?",
                (token,),
            )

    def update_record_settings(self, token, username, encrypted_password, semester_start_date):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                UPDATE saved_logins
                SET username = ?, encrypted_password = ?, semester_start_date = ?
                WHERE token = ?
                """,
                (username, encrypted_password, semester_start_date, token),
            )
