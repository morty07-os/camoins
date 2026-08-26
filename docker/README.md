# Docker Setup for Backhaul Logistics

## Services

This Docker Compose setup includes:

1. **PostgreSQL 15 with PostGIS 3.3** - Main database with geospatial capabilities
2. **Redis 7** - Caching, queues, and session storage
3. **Backend (NestJS)** - API server (optional, can run locally)

## Quick Start

### Prerequisites

- Docker Desktop installed and running
- Node.js 20+ (for local development)

### 1. Start Database Services Only

```bash
# Start PostgreSQL and Redis
docker-compose up -d postgres redis

# Check if services are healthy
docker-compose ps
```

### 2. Verify PostGIS Installation

```bash
docker-compose exec postgres psql -U backhaul_user -d backhaul_db -c "SELECT PostGIS_Version();"
```

Expected output should show PostGIS version information.

### 3. Run Backend Locally (Recommended for Development)

```bash
cd backend
npm install
npm run start:dev
```

Backend will connect to PostgreSQL and Redis running in Docker.

### 4. OR Run Everything in Docker

```bash
# Start all services including backend
docker-compose up -d

# View logs
docker-compose logs -f backend
```

## Environment Variables

Copy `.env.example` to `.env` in the backend directory:

```bash
cd backend
cp .env.example .env
```

Default credentials (development only):
- Database User: `backhaul_user`
- Database Password: `backhaul_password`
- Database Name: `backhaul_db`
- PostgreSQL Port: `5432`
- Redis Port: `6379`

## Useful Commands

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (deletes all data)
docker-compose down -v

# View logs
docker-compose logs -f [service_name]

# Restart a service
docker-compose restart [service_name]

# Access PostgreSQL CLI
docker-compose exec postgres psql -U backhaul_user -d backhaul_db

# Access Redis CLI
docker-compose exec redis redis-cli

# Rebuild backend image
docker-compose build backend
```

## Database Connection Strings

When running locally (backend outside Docker):
```
postgresql://backhaul_user:backhaul_password@localhost:5432/backhaul_db
redis://localhost:6379
```

When running in Docker:
```
postgresql://backhaul_user:backhaul_password@postgres:5432/backhaul_db
redis://redis:6379
```

## Troubleshooting

### Port Already in Use

If port 5432 or 6379 is already in use, stop the conflicting service or change the port mapping in `docker-compose.yml`:

```yaml
ports:
  - "5433:5432"  # Use 5433 on host instead
```

### Permission Issues on Windows

Make sure Docker Desktop has access to your drive in Settings → Resources → File Sharing.

### PostGIS Not Working

Verify the extension is enabled:
```bash
docker-compose exec postgres psql -U backhaul_user -d backhaul_db -c "\dx"
```

You should see `postgis`, `postgis_topology`, and `uuid-ossp` in the list.

## Next Steps

1. Create database migrations (Step 5 in spec)
2. Implement authentication system
3. Set up TypeORM configuration
4. Create seed data for development