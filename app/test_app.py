import os

os.environ.setdefault("REDIS_HOST", "localhost")
os.environ.setdefault("REDIS_PASSWORD", "test")

import app as web


class FakeCache:
    def __init__(self):
        self.hits = 0

    def incr(self, key):
        self.hits += 1
        return self.hits

    def ping(self):
        return True


def make_client(monkeypatch):
    monkeypatch.setattr(web, "cache", FakeCache())
    return web.app.test_client()


def test_index_counts_visits(monkeypatch):
    client = make_client(monkeypatch)
    assert client.get("/").text == "Visits: 1\n"
    assert client.get("/").text == "Visits: 2\n"


def test_health_ok(monkeypatch):
    client = make_client(monkeypatch)
    assert client.get("/health").status_code == 200


def test_version(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "abc123")
    client = make_client(monkeypatch)
    assert client.get("/version").text == "abc123\n"
