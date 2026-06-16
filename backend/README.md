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

## Admin Dashboard

Open:

```text
http://localhost:8787/admin
```

The dashboard shows parent users, child profiles, Free vs Plus users, active subscriptions, estimated monthly revenue, reading attempts, assessment counts, and recent activity.

Raw metrics are available at:

```text
http://localhost:8787/admin/metrics
```

## Endpoints

- `GET /health`
- `GET /admin`
- `GET /admin/metrics`
- `POST /auth/demo-login`
- `POST /auth/register`
- `POST /auth/login`
- `GET /children?parentId=...`
- `POST /children`
- `GET /progress?childId=...`
- `PUT /progress`
- `GET /attempts?childId=...`
- `POST /attempts`
- `POST /assessments/mock`
- `POST /subscriptions/activate`

Runtime data is stored in `backend/data/dev-store.json` and ignored by Git.
