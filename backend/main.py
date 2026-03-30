import os
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import desc
from sqlmodel import Field, Session, SQLModel, create_engine, select

SQLITE_DB_PATH = Path(os.getenv("DB_PATH", Path(__file__).parent / "paradigms.db"))
DEFAULT_CORS_ALLOW_ORIGINS = [
    "http://127.0.0.1:3000",
    "http://localhost:3000",
    "http://127.0.0.1:3001",
    "http://localhost:3001",
    "http://127.0.0.1:5173",
    "http://localhost:5173",
    "http://127.0.0.1:4173",
    "http://localhost:4173",
    "http://127.0.0.1:5500",
    "http://localhost:5500",
    "http://127.0.0.1:8080",
    "http://localhost:8080",
]

app = FastAPI(title="Minimal Paradigm Showdown")


def _resolve_database_url():
    configured = os.getenv("DATABASE_URL")
    if configured:
        if configured.startswith("postgres://"):
            return configured.replace("postgres://", "postgresql+psycopg://", 1)
        if configured.startswith("postgresql://"):
            return configured.replace("postgresql://", "postgresql+psycopg://", 1)
        return configured

    return f"sqlite:///{SQLITE_DB_PATH}"


def _get_cors_allow_origins():
    configured = os.getenv("CORS_ALLOW_ORIGINS")
    if configured:
        if configured.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in configured.split(",") if origin.strip()]
    return DEFAULT_CORS_ALLOW_ORIGINS


cors_allow_origins = _get_cors_allow_origins()
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_allow_origins,
    allow_credentials="*" not in cors_allow_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


DATABASE_URL = _resolve_database_url()
ENGINE_KWARGS = {"pool_pre_ping": True}
if DATABASE_URL.startswith("sqlite:///"):
    ENGINE_KWARGS["connect_args"] = {"check_same_thread": False}

engine = create_engine(DATABASE_URL, **ENGINE_KWARGS)


class ParadigmBase(SQLModel):
    name: str = Field(index=True, sa_column_kwargs={"unique": True})
    votes: int = 0


class Paradigm(ParadigmBase, table=True):
    id: int | None = Field(default=None, primary_key=True)


class ParadigmRead(ParadigmBase):
    id: int


def _to_read_model(paradigm: Paradigm) -> ParadigmRead:
    if paradigm.id is None:
        raise ValueError("Paradigm id should not be None after persistence")
    return ParadigmRead(id=paradigm.id, name=paradigm.name, votes=paradigm.votes)


def _ensure_schema():
    SQLModel.metadata.create_all(engine)


def seed_initial_rows():
    with Session(engine) as session:
        existing = session.exec(select(Paradigm.id).limit(1)).first()
        if existing is not None:
            return

        session.add_all(
            [
                Paradigm(name="Functional Programming"),
                Paradigm(name="Object-Oriented Programming"),
                Paradigm(name="Event-Driven Architecture"),
            ]
        )
        session.commit()


def fetch_all():
    with Session(engine) as session:
        paradigms = session.exec(
            select(Paradigm).order_by(desc(Paradigm.votes), Paradigm.name)
        ).all()
    return [_to_read_model(paradigm) for paradigm in paradigms]


@app.on_event("startup")
def startup():
    _ensure_schema()
    seed_initial_rows()


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/")
def root():
    return {
        "name": app.title,
        "status": "ok",
        "docs": "/docs",
        "health": "/health",
    }


@app.get("/api/paradigms")
def list_paradigms():
    return fetch_all()


@app.post("/api/paradigms/{paradigm_id}/vote")
def vote_paradigm(paradigm_id: int):
    with Session(engine) as session:
        paradigm = session.get(Paradigm, paradigm_id)
        if paradigm is None:
            raise HTTPException(status_code=404, detail="Paradigm not found")
        paradigm.votes += 1
        session.add(paradigm)
        session.commit()
        session.refresh(paradigm)
    return _to_read_model(paradigm)
