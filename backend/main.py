import os
import time

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy.exc import OperationalError
from sqlmodel import Field, Session, SQLModel, create_engine, select


class Paradigm(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    name: str
    votes: int = Field(default=0)


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@db:5432/paradigm_poll",
)
engine = create_engine(DATABASE_URL, pool_pre_ping=True)

app = FastAPI(title="Dev Paradigm Showdown API")


def get_session():
    with Session(engine) as session:
        yield session


def seed_data(session: Session) -> None:
    if session.exec(select(Paradigm)).first():
        return

    session.add_all(
        [
            Paradigm(name="Functional Programming"),
            Paradigm(name="Object-Oriented Programming"),
            Paradigm(name="Event-Driven Architecture"),
        ]
    )
    session.commit()


def init_db() -> None:
    for attempt in range(30):
        try:
            SQLModel.metadata.create_all(engine)
            with Session(engine) as session:
                seed_data(session)
            return
        except OperationalError:
            if attempt == 29:
                raise
            time.sleep(2)


@app.on_event("startup")
def on_startup() -> None:
    init_db()


@app.get("/health")
def healthcheck() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/paradigms", response_model=list[Paradigm])
def get_paradigms(session: Session = Depends(get_session)) -> list[Paradigm]:
    statement = select(Paradigm).order_by(Paradigm.votes.desc(), Paradigm.name.asc())
    return list(session.exec(statement).all())


@app.post("/api/paradigms/{paradigm_id}/vote", response_model=Paradigm)
def vote_for_paradigm(
    paradigm_id: int, session: Session = Depends(get_session)
) -> Paradigm:
    paradigm = session.get(Paradigm, paradigm_id)
    if paradigm is None:
        raise HTTPException(status_code=404, detail="Paradigm not found")

    paradigm.votes += 1
    session.add(paradigm)
    session.commit()
    session.refresh(paradigm)
    return paradigm
