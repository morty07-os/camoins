# Backhaul Logistics - Development Setup Guide

A mobile marketplace for matching unused truck capacity—especially return trips—with compatible freight shipments along or near the same route.

## Technology Stack

- **Mobile**: Flutter + Dart
- **Backend**: NestJS + TypeScript
- **Database**: PostgreSQL 17 + PostGIS 3.5
- **Cache**: Redis 7.4
- **Container**: Docker + Docker Compose

## Project Structure

```
camoins/
├── mobile/           # Flutter mobile application
├── backend/          # NestJS REST API
├── database/         # Database migrations and seeds
├── docker/           # Docker Compose configuration
├── docs/             # Architecture documentation
└── .github/          # CI/CD workflows
```

## Prerequisites

Make sure these are installed on your system:

1. **Flutter SDK** - [Install Flutter](https://docs.flutter.dev/get-started/install/windows)
2. **Node.js LTS** - [Download Node.js](https://nodejs.org/)
3. **Docker Desktop** - [Get Docker Desktop](https://www.docker.com/products/docker-desktop/)
4. **Git** - Already installed
5. **Android Studio** (for Android development)

## Getting Started

### 1. Start the Database

Start PostgreSQL and Redis using Docker:

```bash
cd docker
docker compose up -d
```

Verify containers are running:

```bash
docker ps
```

You should see `backhaul-postgres` and `backhaul-redis` running.

### 2. Verify Database Connection

Test PostgreSQL with PostGIS:

```bash
docker exec -it backhaul-postgres psql -U backhaul -d backhaul
```

Inside PostgreSQL:

```sql
SELECT version();
SELECT PostGIS_Version();
\q
```

### 3. Start the Backend

```bash
cd backend
npm install           # Already done
npm run start:dev
```

The backend will start on `http://localhost:3000`

Check the health endpoint:

```bash
curl http://localhost:3000/health
```

View Swagger API docs at: `http://localhost:3000/api`

### 4. Run the Mobile App

```bash
cd mobile
flutter pub get
flutter run
```

Select your device (Android emulator or physical device).

## Environment Configuration

### Backend Environment Variables

The backend uses `.env` for configuration. A template is provided at `backend/.env.example`.

Current development configuration:
- Database: `localhost:5432`
- Database name: `backhaul`
- Database user: `backhaul`
- API Port: `3000`

### Docker Environment Variables

Docker services use `docker/.env` for configuration.

Current configuration:
- PostgreSQL: Port `5432`
- Redis: Port `6379`

## Development Workflow

### Backend Development

```bash
cd backend
npm run start:dev    # Hot-reload development mode
npm run build        # Production build
npm run test         # Run tests
```

### Mobile Development

```bash
cd mobile
flutter run          # Run on connected device
flutter test         # Run tests
flutter build apk    # Build Android APK
```

## Database Management

### Connect to PostgreSQL

```bash
docker exec -it backhaul-postgres psql -U backhaul -d backhaul
```

### View Container Logs

```bash
docker logs backhaul-postgres
docker logs backhaul-redis
```

### Stop Services

```bash
cd docker
docker compose down
```

### Reset Database (Nuclear Option)

```bash
cd docker
docker compose down -v    # WARNING: Deletes all data
docker compose up -d
```

## API Documentation

Swagger documentation is auto-generated and available at:

```
http://localhost:3000/api
```

## Current Status

### ✅ Completed

- [x] Project structure created
- [x] Docker Compose configuration (PostgreSQL + PostGIS + Redis)
- [x] Backend scaffolding (NestJS)
- [x] Backend dependencies installed
- [x] Environment configuration
- [x] Database connection setup with TypeORM
- [x] Health check endpoint
- [x] Swagger API documentation
- [x] User entity created
- [x] Flutter app initialization (in progress)

### 🚧 Next Steps

1. **Start Docker containers** (requires Docker Desktop to be running)
2. **Complete Flutter initialization**
3. **Implement authentication module** (JWT + Passport)
4. **Create driver and customer profile entities**
5. **Create truck entity**
6. **Create trip entity with PostGIS geometry**
7. **Create shipment entity**
8. **Implement matching algorithm**
9. **Build booking flow**

## First Milestone Target

```
Driver → Register → Create Truck → Publish Trip
Customer → Register → Create Shipment → See Matching Trip
Customer → Request Booking → Driver Accepts → Booking ACCEPTED
```

## Troubleshooting

### Docker containers won't start

Make sure Docker Desktop is running:
1. Open Docker Desktop
2. Wait for it to fully start
3. Try `docker ps` to verify

### Backend won't connect to database

1. Check if PostgreSQL is running: `docker ps`
2. Verify environment variables in `backend/.env`
3. Check backend logs for connection errors

### Flutter build errors

```bash
flutter clean
flutter pub get
flutter doctor    # Check for issues
```

## Technical Decisions

See the full specification at: `backhaul_logistics_codex_spec.md`

Key architectural decisions are documented in `docs/`

## Resources

- [NestJS Documentation](https://docs.nestjs.com/)
- [Flutter Documentation](https://docs.flutter.dev/)
- [TypeORM Documentation](https://typeorm.io/)
- [PostGIS Documentation](https://postgis.net/documentation/)

---

**Last Updated**: 2026-08-25
