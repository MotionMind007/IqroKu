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

## Endpoints

- `GET /health`
- `POST /auth/demo-login`
- `GET /children?parentId=...`
- `POST /children`
- `GET /progress?childId=...`
- `PUT /progress`
- `GET /attempts?childId=...`
- `POST /attempts`
- `POST /assessments/mock`
- `POST /subscriptions/activate`

Runtime data is stored in `backend/data/dev-store.json` and ignored by Git.
