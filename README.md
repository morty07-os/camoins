# Backhaul App - Step 1: Login

A truck backhaul marketplace application connecting drivers with customers for return-trip transport.

## Technology Stack

**Frontend:**
- Flutter Web
- Dart
- Material 3
- HTTP package

**Backend:**
- Node.js
- Express
- CORS
- dotenv

## Project Structure

```
backhaul-app/
├── frontend/          # Flutter Web application
│   ├── lib/
│   │   ├── main.dart
│   │   └── login_page.dart
│   └── pubspec.yaml
├── backend/           # Node.js Express API
│   ├── server.js
│   ├── package.json
│   └── .env
├── package.json       # Root package with run scripts
└── README.md
```

## Prerequisites

### Flutter Setup

1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\src\flutter`
3. Add `C:\src\flutter\bin` to your system PATH
4. Restart terminal
5. Run: `flutter doctor`
6. Enable web: `flutter config --enable-web`

### Node.js

Ensure Node.js (v16+) and npm are installed.

## Installation

```bash
# Install all dependencies
npm install

# Install backend dependencies
cd backend
npm install
cd ..

# Install Flutter dependencies
cd frontend
flutter pub get
cd ..
```

## Running the Application

### Option 1: Run both concurrently (recommended)

```bash
npm run dev
```

This starts:
- Backend on http://localhost:5000
- Frontend on http://localhost:3000

### Option 2: Run separately

**Terminal 1 - Backend:**
```bash
cd backend
npm start
```

**Terminal 2 - Frontend:**
```bash
cd frontend
flutter run -d chrome --web-port 3000
```

### CORS configuration

Express and Socket.IO use the same trusted-origin policy. For local development,
leave `FRONTEND_URLS` unset; `localhost` and `127.0.0.1` frontend origins are
allowed. For production, set `FRONTEND_URLS` to the exact frontend origin or a
comma-separated list of exact origins, for example:

```text
FRONTEND_URLS=https://your-actual-frontend.example,https://another-frontend.example
```

The production frontend URL must be the real deployed URL; do not use the example
values above. `FRONTEND_URL` is also accepted for a single origin. Requests from
non-browser clients without an `Origin` header continue to work.

### JWT configuration

Set `JWT_SECRET` to a strong, unique secret in the production deployment environment
(for Render, add it under the service's Environment variables). Also set
`NODE_ENV=production`. The backend fails during startup if `JWT_SECRET` is missing
in production. Local development may use the development fallback when `JWT_SECRET`
is not set; that fallback is never used with `NODE_ENV=production`.

## Test Credentials

**Email:** test@example.com  
**Password:** password123

## API Endpoints

### Health Check
```
GET http://localhost:5000/api/health
```

Response:
```json
{
  "status": "ok"
}
```

### Login
```
POST http://localhost:5000/api/login
Content-Type: application/json
```

Request:
```json
{
  "email": "test@example.com",
  "password": "password123"
}
```

Success Response (200):
```json
{
  "success": true,
  "message": "Login successful",
  "token": "demo-token"
}
```

Error Response (401):
```json
{
  "success": false,
  "message": "Invalid email or password"
}
```

## Features Implemented

✓ Backend Express server with CORS  
✓ Login API endpoint with validation  
✓ Health check endpoint  
✓ Material 3 Flutter Web login page  
✓ Responsive design (mobile & desktop)  
✓ Form validation  
✓ Loading states  
✓ Error handling  
✓ Success/error messages  

## Development Notes

- This is Step 1 only: Login functionality
- No database yet (in-memory test user)
- No registration, password reset, or dashboard
- No navigation after login (shows success message)
- Demo token only (no JWT implementation)

## Authentication Rate Limiting

The backend uses `express-rate-limit` for the authentication endpoints:

- `POST /api/auth/login`: 5 failed attempts per IP in 15 minutes. Successful logins are not counted.
- `POST /api/auth/register`: 10 attempts per IP in 1 hour.
- Exceeded limits return HTTP 429 with a generic message.

The limiter uses process memory, which is appropriate for the current single-instance deployment. A shared store should be configured before running multiple backend instances. When deployed behind one trusted proxy, set `TRUST_PROXY=true` so client IPs are identified correctly; it remains disabled by default for local development.

## Next Steps

Future features will include:
- User registration
- Dashboard
- Truck/driver profiles
- Trip posting
- Customer connections
- Real authentication with JWT
- Database integration
