import os
import sys
import tempfile
import importlib
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

FERNET_TEST_KEY = "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="


@pytest.fixture
def temp_db_path():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    try:
        yield path
    finally:
        if os.path.exists(path):
            os.remove(path)


@pytest.fixture
def client(monkeypatch, temp_db_path):
    # app.py reads env vars at import time, so make sure they're set before importing/reloading.
    monkeypatch.setenv("CREDENTIAL_ENCRYPTION_KEY", FERNET_TEST_KEY)
    monkeypatch.setenv("KCBPRO_DB_PATH", temp_db_path)

    app_module = importlib.import_module("app")
    app_module = importlib.reload(app_module)
    app_module.app.config["TESTING"] = True

    with app_module.app.test_client() as client:
        yield client
