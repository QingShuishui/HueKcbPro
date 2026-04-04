from utils.token_generator import generate_token


def test_generate_token_returns_8_alnum_chars():
    token = generate_token()

    assert len(token) == 8
    assert token.isalnum()
