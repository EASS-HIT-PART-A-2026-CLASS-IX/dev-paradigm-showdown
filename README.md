# Dev Paradigm Showdown

`Dev Paradigm Showdown` is a deliberately small microservices demo: one page, one table, two API calls, three containers.

The app lets users vote between software paradigms:

- Functional Programming
- Object-Oriented Programming
- Event-Driven Architecture

The point of the project is not feature depth. The point is to validate a stack end to end with the smallest slice that still feels real.

## Why This Repo Exists

This repository is designed as a teaching artifact for two things:

- how to build a thin software slice with Docker Compose and clean service boundaries
- how an AI coding agent works through a tool harness to inspect an environment, edit code, run validation, and recover from failures

## Architecture

```mermaid
flowchart LR
    U[Browser]
    F[frontend<br/>Nginx + static HTML/JS]
    A[api<br/>FastAPI + SQLModel]
    D[(db<br/>Postgres)]

    U -->|HTTP| F
    F -->|GET /api/paradigms| A
    F -->|POST /api/paradigms/:id/vote| A
    A -->|read/write| D
```

## Stack

- `frontend`: Nginx serving one static page
- `api`: FastAPI + SQLModel
- `db`: Postgres 16
- `orchestration`: Docker Compose

## Project Layout

```text
.
├── backend/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
├── frontend/
│   ├── Dockerfile
│   ├── app.js
│   ├── index.html
│   ├── nginx.conf
│   └── styles.css
├── docker-compose.yml
├── BUILD_TRACE.md
├── AI_AGENT_TRACE.md
└── README.md
```

## Run

Start the stack:

```bash
docker compose up --build
```

Find the published frontend port:

```bash
docker compose port frontend 80
```

Then open the returned address in your browser.

## API

- `GET /api/paradigms`
- `POST /api/paradigms/{id}/vote`

## Validation

Bring the stack up, then run the smoke test:

```bash
docker compose up --build -d
python3 scripts/e2e_smoke.py
```

The smoke test validates:

- the UI HTML is served
- the paradigms list loads through the frontend proxy
- a vote can be submitted
- the follow-up fetch reflects the database write

## Notes On Networking

Only the frontend is published to the host.

- the browser talks to the frontend
- the frontend proxies `/api/*` to the backend
- the backend talks to Postgres on the internal Compose network

This keeps the browser configuration simple and avoids CORS setup.

## Documentation

- [BUILD_TRACE.md](./BUILD_TRACE.md): step-by-step record of how the solution was assembled and debugged
- [AI_AGENT_TRACE.md](./AI_AGENT_TRACE.md): educational explanation of how an AI coding agent works through a harness, using this session as the concrete example

## What Makes This A Thin Slice

- one table
- two endpoints
- one UI page
- persistent storage
- real network boundaries
- real startup orchestration
- live end-to-end verification

That is enough surface area to test whether the stack is coherent without overbuilding the product.
