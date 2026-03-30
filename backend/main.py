import os
import sqlite3
from pathlib import Path
from threading import Lock

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

DB_PATH = Path(os.getenv("DB_PATH", Path(__file__).parent / "paradigms.db"))
LOCK = Lock()

app = FastAPI(title="Minimal Paradigm Showdown")


class Paradigm(BaseModel):
    id: int
    name: str
    votes: int


def _get_connection():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def _ensure_schema():
    with LOCK:
        conn = _get_connection()
        with conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS paradigms (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT UNIQUE NOT NULL,
                    votes INTEGER NOT NULL DEFAULT 0
                )
                """
            )
        conn.close()


def seed_initial_rows():
    with LOCK:
        conn = _get_connection()
        with conn:
            if conn.execute("SELECT COUNT(*) FROM paradigms").fetchone()[0]:
                return
            conn.executemany(
                "INSERT INTO paradigms (name) VALUES (?)",
                [
                    ("Functional Programming",),
                    ("Object-Oriented Programming",),
                    ("Event-Driven Architecture",),
                ],
            )
        conn.close()


def fetch_all():
    conn = _get_connection()
    rows = conn.execute(
        "SELECT id, name, votes FROM paradigms ORDER BY votes DESC, name ASC"
    ).fetchall()
    conn.close()
    return [Paradigm(**dict(row)) for row in rows]


@app.on_event("startup")
def startup():
    _ensure_schema()
    seed_initial_rows()


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/api/paradigms")
def list_paradigms():
    return fetch_all()


@app.post("/api/paradigms/{paradigm_id}/vote")
def vote_paradigm(paradigm_id: int):
    with LOCK:
        conn = _get_connection()
        cursor = conn.execute(
            "UPDATE paradigms SET votes = votes + 1 WHERE id = ?", (paradigm_id,)
        )
        if not cursor.rowcount:
            conn.close()
            raise HTTPException(status_code=404, detail="Paradigm not found")
        conn.commit()
        row = conn.execute(
            "SELECT id, name, votes FROM paradigms WHERE id = ?", (paradigm_id,)
        ).fetchone()
        conn.close()
    return Paradigm(**dict(row))
