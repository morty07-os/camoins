# Camoins — Backhaul marketplace

Camoins connects drivers publishing return trips with customers who need cargo transport.
The app has a Flutter frontend and a Node.js/Express API backed by SQLite, with Socket.IO
for chat and live notifications.

## Features

- Registration and login with DRIVER and CUSTOMER accounts, bcrypt passwords and JWT sessions.
- Driver profiles, trucks, return trips and cargo management.
- Trip search, transport requests, capacity reservation and cancellation.
- Conversations per request, chat, read receipts and notifications.
- Trip history and ratings between transport participants.

## Project layout

- `backend/server.js`: REST routes and Socket.IO handlers.
- `backend/models.js`: database access and transactional booking operations.
- `backend/database.js`: SQLite schema, indexes and existing schema migrations.
- `backend/test/`: API and data integrity regression suites.
- `frontend/lib/`: Flutter pages, widgets, Riverpod providers and services.
- `frontend/test/`: model, provider and widget tests.

## Local setup

Install Node.js compatible with the locked better-sqlite3 dependency and a Flutter SDK
compatible with `frontend/pubspec.yaml`. The backend tests require Node's built-in fetch.

From the repository root:

```powershell
npm ci
npm --prefix backend ci
cd frontend
flutter pub get
cd ..
npm run dev
```

The API runs on port 5000 and Flutter Web on port 3000. Create an account through
registration; there is no seeded demo login. To run components separately:

```powershell
npm run backend
npm run frontend
```

## Configuration

Backend environment variables (also loaded from `.env` in the backend working directory):

| Variable | Purpose |
| --- | --- |
| `PORT` | HTTP and Socket.IO port; defaults to 5000. |
| `DB_PATH` | SQLite file path; defaults to `backend/backhaul.db`. |
| `JWT_SECRET` | Signing secret; required when `NODE_ENV=production`. |
| `NODE_ENV` | Set to `production` in production. |
| `FRONTEND_URLS` | Comma-separated exact trusted frontend origins. |
| `FRONTEND_URL` | Single-origin alternative. |
| `TRUST_PROXY` | Set to `true` only when behind one trusted reverse proxy. |

Set a strong, unique JWT secret in production. The development fallback is only for
local use. JWTs expire after seven days.

Without configured origins, localhost and 127.0.0.1 browser origins are allowed.
REST and Socket.IO share the same origin policy. Non-browser requests without an
Origin header remain allowed. Set the real deployed frontend origins in production.

The frontend accepts a backend origin without `/api`:

```powershell
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:5000
```

For deployment, pass the HTTPS backend origin when building the frontend. Defaults
are `http://10.0.2.2:5000` for Android emulators and `http://localhost:5000` otherwise.
A persisted `backend_url` preference can override the build-time value.

SQLite must live on persistent storage in deployment. Back up the database before
deployments or schema changes. Push notifications via Firebase are not implemented;
current live notifications use Socket.IO.

## Booking rules

- Requests require positive finite numeric weight and, when provided, volume.
- Acceptance requires a pending request and a published trip. Status and capacity
  checks occur inside the same transaction as reservation.
- Cancelling a trip cancels pending and accepted requests atomically.
- Completing a trip completes accepted requests and cancels unanswered requests
  atomically. Customers receive notifications for the resulting transitions.
- Trucks and trips with any booking history cannot be deleted (HTTP 409), including
  cancelled and completed bookings. Their conversations, messages and ratings remain.
- A temporary session lookup failure preserves the saved token and offers retry.
  An unauthorized response clears it; explicit logout also clears it.

## Tests

```powershell
npm test
cd frontend
flutter test
flutter analyze
```

`npm test` runs every backend `*.test.js` suite sequentially, including authentication
rate limits, CORS, trucks, trips, chat and booking integrity. Suites use isolated test
databases, not the application database. The booking integrity suite also verifies
transaction rollback and preservation of chat history after blocked deletion.

Authentication limits are 5 failed logins per IP per 15 minutes and 10 registration
attempts per IP per hour. Exceeding a limit returns HTTP 429. The limiter is in memory;
configure a shared store before running multiple backend instances.

## API overview

The base path is `/api`. Health is available at `GET /api/health`.
Authentication uses `/auth/register`, `/auth/login` and `/auth/me`.
Protected routes require `Authorization: Bearer <token>`.
Other route groups include `/profile`, `/trucks`, `/trips`, `/cargaisons`,
`/search/trips`, `/requests`, `/conversations`, `/notifications` and `/ratings`.
See `backend/server.js` for request bodies, permissions and response formats.
