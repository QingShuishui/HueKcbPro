# Link Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one-time link guidance, canonical link copying, and desktop/mobile settings entry points on the token timetable page.

**Architecture:** Extend the saved token record with a `link_hint_seen` flag, expose a small token state update API, and render the timetable page with enough state for the frontend to decide whether to show the first-time banner. Keep the UI behavior in the existing page and script so desktop and mobile can share the same token/session flow while differing only in entry placement.

**Tech Stack:** Flask, SQLite (`sqlite3`), Jinja2 templates, vanilla JavaScript, pytest

---

### Task 1: Persist Link Hint State

**Files:**
- Modify: `utils/credential_store.py`
- Modify: `tests/test_credential_store.py`

- [ ] **Step 1: Write the failing schema/state tests**

```python
from utils.credential_store import CredentialStore


def test_store_defaults_link_hint_seen_to_zero(temp_db_path):
    store = CredentialStore(temp_db_path)
    store.initialize()
    store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    record = store.get_record("Ab3X9kQ2")

    assert record["link_hint_seen"] == 0


def test_mark_link_hint_seen_updates_record(temp_db_path):
    store = CredentialStore(temp_db_path)
    store.initialize()
    store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    store.mark_link_hint_seen("Ab3X9kQ2")
    record = store.get_record("Ab3X9kQ2")

    assert record["link_hint_seen"] == 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_credential_store.py -q`

Expected: FAIL because `link_hint_seen` and `mark_link_hint_seen` do not exist yet

- [ ] **Step 3: Write minimal implementation**

```python
CREATE TABLE IF NOT EXISTS saved_logins (
    token TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    encrypted_password TEXT NOT NULL,
    created_at TEXT NOT NULL,
    last_accessed_at TEXT NOT NULL,
    link_hint_seen INTEGER NOT NULL DEFAULT 0
)
```

```python
def save_record(self, token, username, encrypted_password, created_at, last_accessed_at):
    with sqlite3.connect(self.db_path) as conn:
        conn.execute(
            """
            INSERT OR REPLACE INTO saved_logins
            (token, username, encrypted_password, created_at, last_accessed_at, link_hint_seen)
            VALUES (?, ?, ?, ?, ?, COALESCE(
                (SELECT link_hint_seen FROM saved_logins WHERE token = ?),
                0
            ))
            """,
            (token, username, encrypted_password, created_at, last_accessed_at, token),
        )


def mark_link_hint_seen(self, token):
    with sqlite3.connect(self.db_path) as conn:
        conn.execute(
            "UPDATE saved_logins SET link_hint_seen = 1 WHERE token = ?",
            (token,),
        )
```
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_credential_store.py -q`

Expected: PASS

### Task 2: Expose First-Time Banner State And Update API

**Files:**
- Modify: `app.py`
- Modify: `tests/test_login_routes.py`
- Modify: `tests/test_schedule_api.py`
- Create: `tests/test_link_hint_api.py`

- [ ] **Step 1: Write the failing page-state and update-api tests**

```python
def test_timetable_page_shows_link_hint_on_first_visit(client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/t/Ab3X9kQ2")

    assert "data-show-link-hint=\"true\"" in response.get_data(as_text=True)
```

```python
def test_mark_link_hint_seen_api_updates_state(client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.post("/api/tokens/Ab3X9kQ2/link-hint-seen")

    assert response.status_code == 200
    assert response.get_json() == {"ok": True}
    assert credential_store.get_record("Ab3X9kQ2")["link_hint_seen"] == 1
```

```python
@patch("app.decrypt_password", return_value="pw123")
@patch(
    "app.login_and_get_schedule",
    return_value=({"courses": [], "semester_info": "2026春", "generated_at": "now"}, None),
)
def test_schedule_api_defaults_to_all_when_week_all(_crawler, _decrypt_password, client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/api/schedule/Ab3X9kQ2?week=all")

    assert response.status_code == 200
    assert response.get_json()["selected_week"] is None
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_login_routes.py tests/test_schedule_api.py tests/test_link_hint_api.py -q`

Expected: FAIL because `show_link_hint` and the new POST API do not exist yet

- [ ] **Step 3: Write minimal implementation**

```python
@app.route("/api/tokens/<token>/link-hint-seen", methods=["POST"])
def mark_link_hint_seen_api(token):
    record = credential_store.get_record(token)
    if not record:
        return jsonify({"error": "链接无效，请重新登录"}), 404

    credential_store.mark_link_hint_seen(token)
    return jsonify({"ok": True})
```

```python
return render_template(
    "timetable.html",
    token=token,
    saved_link=url_for("timetable_page", token=token, _external=True),
    current_week=current_week,
    selected_week=current_week,
    is_weekend=is_weekend,
    show_link_hint=record["link_hint_seen"] == 0,
)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_login_routes.py tests/test_schedule_api.py tests/test_link_hint_api.py -q`

Expected: PASS

### Task 3: Implement Desktop/Mobile Settings Copy UI

**Files:**
- Modify: `templates/timetable.html`
- Modify: `static/js/script.js`
- Modify: `static/css/style.css`
- Modify: `tests/test_timetable_page.py`

- [ ] **Step 1: Write the failing UI tests**

```python
def test_timetable_page_renders_settings_copy_entry(client):
    from app import credential_store

    credential_store.save_record(
        token="Ab3X9kQ2",
        username="demo_student_id",
        encrypted_password="ciphertext",
        created_at="2026-03-31T12:00:00",
        last_accessed_at="2026-03-31T12:00:00",
    )

    response = client.get("/t/Ab3X9kQ2")
    body = response.get_data(as_text=True)

    assert "settings-trigger" in body
    assert "复制当前链接" in body
    assert "data-show-link-hint=\"true\"" in body
```
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_timetable_page.py -q`

Expected: FAIL because the settings entry and state markers are missing

- [ ] **Step 3: Write minimal implementation**

```html
<section class="save-link-banner{% if not show_link_hint %} is-hidden{% endif %}" id="saveLinkBanner" data-show-link-hint="{{ 'true' if show_link_hint else 'false' }}">
  <p>登录成功。请保存此链接，下次可直接访问。</p>
  <input id="savedLinkInput" type="text" value="{{ saved_link }}" readonly>
  <button type="button" id="copyLinkButton">复制当前链接</button>
</section>

<button type="button" class="settings-trigger" id="desktopSettingsTrigger">⚙ 设置</button>
```

```javascript
async function markLinkHintSeen() {
  await fetch(`/api/tokens/${window.scheduleToken}/link-hint-seen`, { method: 'POST' });
}

async function copyCurrentLink() {
  const input = document.getElementById('savedLinkInput');
  const link = input ? input.value : window.location.origin + `/t/${window.scheduleToken}`;
  await navigator.clipboard.writeText(link);
  await markLinkHintSeen();
  setTimeout(() => document.getElementById('saveLinkBanner')?.classList.add('is-hidden'), 2500);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_timetable_page.py -q`

Expected: PASS

### Task 4: Final Verification

**Files:**
- Modify: `app.py`
- Modify: `utils/credential_store.py`
- Modify: `templates/timetable.html`
- Modify: `static/js/script.js`
- Modify: `static/css/style.css`
- Modify: `tests/test_credential_store.py`
- Modify: `tests/test_login_routes.py`
- Modify: `tests/test_schedule_api.py`
- Create: `tests/test_link_hint_api.py`
- Modify: `tests/test_timetable_page.py`

- [ ] **Step 1: Run the full test suite**

Run: `pytest -q`

Expected: PASS

- [ ] **Step 2: Verify Flask routes still load**

Run: `CREDENTIAL_ENCRYPTION_KEY='MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' python3 -c "from app import app; print(app.url_map)"`

Expected: Prints route map including `/api/tokens/<token>/link-hint-seen`, `/api/schedule/<token>`, `/login`, and `/t/<token>`
