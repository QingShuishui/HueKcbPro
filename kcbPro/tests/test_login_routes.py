from unittest.mock import patch


@patch(
    "app.login_and_get_schedule",
    return_value=({"courses": [], "semester_info": "", "generated_at": "now"}, None),
)
@patch("app.generate_token", return_value="Ab3X9kQ2")
def test_post_login_redirects_to_token_page(_generate_token, _crawler, client):
    response = client.post(
        "/login",
        data={"username": "demo_student_id", "password": "pw123"},
        follow_redirects=False,
    )

    assert response.status_code == 302
    assert response.headers["Location"].endswith("/t/Ab3X9kQ2")


def test_token_page_returns_404_for_missing_token(client):
    response = client.get("/t/BadTok99")

    assert response.status_code == 404


def test_index_renders_home_page(client):
    response = client.get("/")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert 'static/css/style.css' in body
    assert 'bottom-nav' in body
    assert 'id="homeNavTrigger"' in body


def test_login_page_renders_styled_login_page(client):
    response = client.get("/login")
    body = response.get_data(as_text=True)

    assert response.status_code == 200
    assert 'static/css/style.css' in body
    assert 'login-card' in body


@patch(
    "app.login_and_get_schedule",
    return_value=({"courses": [], "semester_info": "", "generated_at": "now"}, None),
)
@patch("app.generate_token", return_value="Ab3X9kQ2")
def test_post_login_creates_accessible_token_page(_generate_token, _crawler, client):
    login_response = client.post(
        "/login",
        data={"username": "demo_student_id", "password": "pw123"},
        follow_redirects=False,
    )

    page_response = client.get(login_response.headers["Location"])

    assert login_response.status_code == 302
    assert page_response.status_code == 200
    assert "Ab3X9kQ2" in page_response.get_data(as_text=True)


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

    assert 'data-show-link-hint="true"' in response.get_data(as_text=True)
