import os

import redis
from flask import Flask

app = Flask(__name__)
cache = redis.Redis(
    host=os.environ["REDIS_HOST"],
    password=os.environ["REDIS_PASSWORD"],
    decode_responses=True,
)


@app.get("/")
def index():
    return f"Visits: {cache.incr('hits')}\n"


@app.get("/health")
def health():
    cache.ping()
    return "ok\n"
