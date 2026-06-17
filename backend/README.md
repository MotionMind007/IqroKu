# IqroKu Backend Prototype

Local API prototype for the Flutter app. It intentionally uses only Node built-ins so it can run without dependency install.

## Run

```bash
npm start --workspace backend
```

or:

```bash
cd backend
npm start
```

Default URL: `http://localhost:8787`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8787` | Server port |
| `IQROKU_ADMIN_TOKEN` | `admin-dev-token` | Token for admin dashboard access |
| `IQROKU_BACKEND_STORE` | `data/dev-store.json` | Path to JSON data store |

## Authentication

All protected endpoints require a `Bearer` token in the `Authorization` header:

```
Authorization: Bearer <session_token>
```

Tokens are returned by `/auth/register` and `/auth/login`.

## Admin Dashboard

Admin routes require the admin token either via header or query param:

```text
http://localhost:8787/admin?token=admin-dev-token
```

Or with header:
```
Authorization: Bearer admin-dev-token
```

Pages:
- `/admin` — Dashboard with metrics
- `/admin/metrics` — Raw JSON metrics
- `/admin/prayers` — Prayer CRUD interface

## Security Features

- **Auth middleware** — All data endpoints verify session tokens and enforce ownership
- **Admin protection** — Admin dashboard requires separate admin token
- **Rate limiting** — 10 auth attempts / 120 general requests per minute per IP
- **Request body size limit** — 5MB max
- **Input validation** — String truncation (500 chars), number clamping, email length check
- **Password constraints** — 6-128 characters, scrypt hashing with timing-safe verification
- **Graceful shutdown** — SIGTERM/SIGINT handlers save state before exit
- **Session TTL** — Sessions expire after 7 days
- **Ownership enforcement** — Users can only access their own children/progress/attempts

## Endpoints

### Public
- `GET /health`
- `GET /daily-prayers`
- `POST /auth/demo-login`
- `POST /auth/register`
- `POST /auth/login`

### Protected (require user auth token)
- `GET /children?parentId=...`
- `POST /children`
- `GET /progress?childId=...`
- `PUT /progress`
- `GET /attempts?childId=...`
- `POST /attempts`
- `POST /attempts/:id/audio` (multipart)
- `POST /assessments/mock`
- `POST /subscriptions/activate`

### Admin (require admin token)
- `GET /admin`
- `GET /admin/metrics`
- `GET /admin/prayers`
- `POST /admin/prayers`
- `POST /admin/prayers/:id/update`
- `POST /admin/prayers/:id/delete`

Runtime data is stored in `backend/data/dev-store.json` and ignored by Git.
