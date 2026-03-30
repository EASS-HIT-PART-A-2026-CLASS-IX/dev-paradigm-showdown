# Dev Paradigm Showdown

`Dev Paradigm Showdown` is a deliberately small thin-slice demo: one page, one table, two API calls, and a backend that can run locally or on FastAPI Cloud.

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
    F[frontend<br/>Static HTML/JS]
    A[api<br/>FastAPI + SQLite or Postgres]
    C[FastAPI Cloud]
    N[Neon Postgres]

    U -->|HTTP| F
    F -->|/api via proxy or direct URL| A
    A -->|deploy| C
    C -->|DATABASE_URL| N
```

## Stack

- `frontend`: static HTML/JS, served by Nginx in Docker or `python -m http.server` locally
- `api`: FastAPI + SQLModel, using SQLite locally or Postgres through `DATABASE_URL`
- `cloud`: FastAPI Cloud for backend deployment
- `database`: Neon Postgres for shared cloud persistence
- `orchestration`: Docker Compose plus small local helper scripts

## Minimal Stack

- `frontend`: static HTML served by Nginx and reverse-proxies `/api` to the backend
- `api`: FastAPI talking to a local SQLite table stored in `backend/paradigms.db`
- `volumes`: Compose mounts a named `backend_data` volume so the SQLite file survives restarts
- no external database—this keeps the stack as lean as possible
- `frontend` can also call a deployed FastAPI Cloud backend directly when run locally

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
├── AI_AGENT_TRACE.md
├── scripts/
│   ├── _backend_common.sh
│   ├── deploy_backend.sh
│   ├── e2e_smoke.py
│   ├── run_backend_dev.sh
│   └── run_frontend.sh
└── README.md
```

## Modes

### 1. Full local Docker mode

Run the frontend through Nginx and proxy `/api` to the local backend:

```bash
docker compose up --build
```

Then find the published frontend port:

```bash
docker compose port frontend 80
```

Then open the returned address in your browser.

The Docker frontend starts on the local Docker backend by default. If you also set `FRONTEND_REMOTE_API_BASE_URL`, the UI exposes a selector so you can switch between local Docker and your deployed FastAPI Cloud backend.

### 2. Local frontend + local FastAPI dev backend

Run the backend in FastAPI dev mode:

```bash
./scripts/run_backend_dev.sh
```

In a second terminal, run the frontend against that local backend:

```bash
./scripts/run_frontend.sh local
```

Open `http://127.0.0.1:3000`.

The UI always includes the local FastAPI backend. If you also set `REMOTE_API_BASE_URL`, the selector lets you switch between:

- the local FastAPI backend
- the deployed FastAPI Cloud backend

### 3. Local frontend + deployed FastAPI Cloud backend

Run the frontend locally, but point it at the deployed backend:

```bash
API_BASE_URL=https://your-app.fastapicloud.dev ./scripts/run_frontend.sh cloud
```

Open `http://127.0.0.1:3000`.

This starts with the cloud backend selected by default, but the UI selector still lets you switch back to the local backend.

You can also point the frontend at any custom backend URL:

```bash
./scripts/run_frontend.sh https://your-api.example.com
```

Important:

- the deployed backend should use a shared database through `DATABASE_URL`
- local SQLite is fine for local mode, but it is not reliable behind a cloud load balancer
- if `DATABASE_URL` is not configured in FastAPI Cloud, mutation tests can fail because different requests may hit different app instances

## Deploy To Your Own FastAPI Cloud App With Neon

This repo is now set up so new users can wire in their own FastAPI Cloud app and their own Neon project instead of inheriting a repo-specific deployment.

### 4. Create your Neon database

You have two valid setup paths:

#### Option A: Connect Neon from FastAPI Cloud

This is the cleanest path if you want FastAPI Cloud to manage the `DATABASE_URL` secret for you.

1. Create or open a Neon project in the Neon console:
   `https://console.neon.tech`
2. In FastAPI Cloud, connect your Neon account from your team `Integrations` settings.
3. Open your FastAPI Cloud app, go to `Storage`, choose the Neon integration, then select:
   - organization
   - project
   - branch
   - database
4. Save the connection and redeploy.

FastAPI Cloud will create an encrypted `DATABASE_URL` environment variable automatically.

#### Option B: Copy the Neon connection string manually

Use this if you prefer to manage the environment variable yourself.

1. Create or open a Neon project in `https://console.neon.tech`.
2. In the Neon dashboard, click `Connect`.
3. Copy the connection string for the branch/database/role you want to use.
4. Prefer the pooled connection string for this app. In Neon that means the hostname includes `-pooler`.
5. Add that value to FastAPI Cloud as `DATABASE_URL`.

You can set it in the FastAPI Cloud dashboard or by CLI after the app is linked:

```bash
cd backend
fastapi cloud env set DATABASE_URL 'postgresql://USER:PASSWORD@ep-...-pooler....neon.tech/DBNAME?sslmode=require'
```

### 5. Deploy the backend to your own FastAPI Cloud app

First-time interactive deploy from the repo root:

```bash
./scripts/deploy_backend.sh
```

The script changes into `backend/`, ensures the local CLI is installed, and runs `fastapi deploy`.

On the first deploy, FastAPI Cloud will let you log in, select a team, and either create a new app or link an existing one. Later deploys reuse the generated `backend/.fastapicloud/` link automatically.

This repo also pins the FastAPI Cloud runtime to Python 3.12 with `backend/.python-version`, matching the local Docker image and the local `uv` workflow.

If you already know your app ID, you can pass it explicitly:

```bash
./scripts/deploy_backend.sh YOUR_FASTAPI_CLOUD_APP_ID
```

For non-interactive deploys such as CI, set the official deploy-token environment variables:

```bash
export FASTAPI_CLOUD_TOKEN='your-deploy-token'
export FASTAPI_CLOUD_APP_ID='your-app-uuid'
./scripts/deploy_backend.sh
```

### 6. Point the frontend at your deployed backend

For local frontend development against your own deployed app:

```bash
API_BASE_URL=https://your-app.fastapicloud.dev ./scripts/run_frontend.sh cloud
```

For Docker Compose, set the remote backend URL before starting:

```bash
export FRONTEND_REMOTE_API_BASE_URL=https://your-app.fastapicloud.dev
docker compose up --build
```

### 7. Test your deployed backend

To validate both local mode and your own cloud deployment:

```bash
CLOUD_BACKEND_URL=https://your-app.fastapicloud.dev ./scripts/test_backend_modes.sh
```

If `CLOUD_BACKEND_URL` is not set, the script now only validates the fully local path.

### 8. Notes for cloud persistence

- Local Docker mode still uses SQLite in a named volume.
- FastAPI Cloud should use Postgres through `DATABASE_URL`, not SQLite on the container filesystem.
- FastAPI Cloud deploys with multiple instances and zero-downtime rollouts, so a shared database is required for consistent writes.
- This backend already accepts either SQLite or Postgres and normalizes `postgres://` and `postgresql://` URLs for SQLAlchemy + psycopg.
- FastAPI Cloud custom domains are not available yet, so the deploy URL you should expect today is `https://your-app.fastapicloud.dev`.

### 9. Official References

- FastAPI Cloud existing-project guide: <https://fastapicloud.com/docs/getting-started/existing-project/>
- FastAPI Cloud deploy command: <https://fastapicloud.com/docs/fastapi-cloud-cli/deploy/>
- FastAPI Cloud environment variables: <https://fastapicloud.com/docs/builds-and-deployments/environment-variables/>
- FastAPI Cloud deploy tokens: <https://fastapicloud.com/docs/advanced-features/deploy-tokens/>
- FastAPI Cloud Neon integration: <https://fastapicloud.com/docs/integrations/neon-integration/>
- FastAPI Cloud custom domains status: <https://fastapicloud.com/docs/advanced-features/custom-domains/>
- Neon connection guide: <https://neon.com/docs/get-started/connect-neon>
- Neon connection pooling guide: <https://neon.com/docs/connect/connection-pooling>

## API

- `GET /api/paradigms`
- `POST /api/paradigms/{id}/vote`

## Validation

Validate the Docker mode:

```bash
docker compose up --build -d
python3 scripts/e2e_smoke.py
```

Validate the local frontend mode by pointing the smoke test at a specific base URL:

```bash
E2E_BASE_URL=http://127.0.0.1:3000 python3 scripts/e2e_smoke.py
```

The smoke test validates:

- the UI HTML is served
- the paradigms list loads through the configured backend target
- a vote can be submitted
- the follow-up fetch reflects the database write

## Simplified Docker Model

- `api` builds from `backend/`, writes `paradigms.db`, and responds to `/api/paradigms` and `/api/paradigms/{id}/vote`
- `frontend` builds from `frontend/` and can either proxy `/api` traffic or call a configured backend URL directly
- `backend_data` volume stores the SQLite database so votes persist across restarts
- deployed FastAPI Cloud mode should use a shared Postgres database through `DATABASE_URL`

There is zero extra service wiring: just two containers and one volume.

## Notes On Networking

Docker mode keeps the browser on one origin:

- the browser talks to the frontend
- the frontend proxies `/api/*` to the backend
- the backend uses SQLite on the container filesystem plus the named volume

Local frontend mode calls the backend directly:

- the browser talks to the local static frontend server
- the frontend calls the backend by absolute URL
- the backend enables CORS for common local dev origins such as `http://127.0.0.1:3000`

## Documentation

- [AI_AGENT_TRACE.md](./AI_AGENT_TRACE.md): the main deep-dive document for how the agent, prompt stack, tool harness, runtime feedback, and validation loop produced the final solution

## What Makes This A Thin Slice

- one table
- two endpoints
- one UI page
- persistent storage
- real network boundaries
- real startup orchestration
- live end-to-end verification

That is enough surface area to test whether the stack is coherent without overbuilding the product.
