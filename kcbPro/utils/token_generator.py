import secrets
import string


TOKEN_ALPHABET = string.ascii_letters + string.digits


def generate_token(length=8):
    return "".join(secrets.choice(TOKEN_ALPHABET) for _ in range(length))
