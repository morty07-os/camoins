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
# On a new checkout only: create the ignored local environment file.
Copy-Item backend/.env.example backend/.env
node -e "const fs=require('fs'),c=require('crypto'),p='backend/.env';fs.writeFileSync(p,fs.readFileSync(p,'utf8').replace(/^JWT_SECRET=.*$/m,'JWT_SECRET='+c.randomBytes(48).toString('hex')))"
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
| `JWT_SECRET` | Unique random signing secret of at least 32 bytes; required in every environment. |
| `NODE_ENV` | Set to `production` in production. |
| `FRONTEND_URLS` | Comma-separated exact trusted frontend origins. |
| `FRONTEND_URL` | Single-origin alternative. |
| `TRUST_PROXY` | Set to `true` only when behind one trusted reverse proxy. |

No signing-key fallback is provided. Keep `.env`, databases, and `node_modules`
out of Git. The setup commands generate a local key without printing it. Do not
overwrite an existing environment file when installing dependencies or updating.
JWTs expire after 12 hours. Logout revokes the current token in SQLite and closes
all sockets using that token; another independently signed-in session remains active.
An offline logout reports failure and can be retried once the backend is reachable.

Without configured origins, localhost and 127.0.0.1 browser origins are allowed.
REST and Socket.IO share the same origin policy. Non-browser requests without an
Origin header remain allowed. Set the real deployed frontend origins in production.

The frontend accepts a backend origin without `/api`:

```powershell
flutter run -d chrome --web-port 3000 --dart-define=API_BASE_URL=http://localhost:5000
```

Release builds require an HTTPS `API_BASE_URL` and ignore saved runtime URL
overrides. Debug defaults are `http://10.0.2.2:5000` for Android emulators and
`http://localhost:5000` otherwise; a persisted `backend_url` can override debug URLs.
In production the backend rejects unencrypted API and Socket.IO connections.
Terminate HTTPS at a trusted reverse proxy, restrict direct access to the Node port,
and only then enable `TRUST_PROXY=true`. The proxy must overwrite forwarded headers.
The health endpoint remains available over HTTP for local infrastructure probes.

Native tokens use platform secure storage. Browser tokens remain in tab memory,
so refreshing or closing the page requires signing in again. Old plaintext tokens
are discarded. Android backups are disabled to avoid restoring encrypted tokens
without their device keys. Windows native plugin builds require Developer Mode
(symlink support); native device packaging should be validated on the target OS.

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
  An unauthorized response clears it; explicit logout revokes it on the backend
  before clearing local authentication.

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

Chat allows 4,000 UTF-16 code units per message and 30 messages per user per minute
shared across REST and sockets. Chat REST requests and socket events each allow
120 per user per minute. Message/notification page sizes are 1–100, with offsets
0–100,000. Public search allows 60 requests per IP per minute and omits driver email
and vehicle registration numbers. New passwords require at least 12 characters
and at most 72 UTF-8 bytes; existing shorter passwords can still log in.

Run `npm audit` in the root and backend after dependency changes. The security
regression suite checks expiry, logout revocation across restarts, public-data
minimization, message/pagination limits, and production HTTPS enforcement.

## API overview

The base path is `/api`. Health is available at `GET /api/health`.
Authentication uses `/auth/register`, `/auth/login`, `/auth/me` and `POST /auth/logout`.
Protected routes require `Authorization: Bearer <token>`.
Other route groups include `/profile`, `/trucks`, `/trips`, `/cargaisons`,
`/search/trips`, `/requests`, `/conversations`, `/notifications` and `/ratings`.
See `backend/server.js` for request bodies, permissions and response formats.
