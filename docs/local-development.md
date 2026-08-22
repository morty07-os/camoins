# Local infrastructure

## Services

The local stack contains:

- PostgreSQL 17 with PostGIS 3.5 on port `5432`
- Redis 7.4 on port `6379`

The PostGIS image is pinned to `postgis/postgis:17-3.5`; Redis is pinned to `redis:7.4.10-alpine3.21`. Both use persistent Docker named volumes.

## Start the stack

1. Install and start Docker Desktop.
2. Copy `docker/.env.example` to `docker/.env`.
3. Replace `POSTGRES_PASSWORD` with a local development secret.
4. From the repository root, run:

   ```powershell
   docker compose --env-file docker/.env -f docker/compose.yml up -d
   ```

5. Verify the services:

   ```powershell
   docker compose --env-file docker/.env -f docker/compose.yml ps
   ```

## Backend configuration

Set the following values in the backend's local `.env` file once the stack is running:

```text
DATABASE_URL=postgresql://backhaul:YOUR_PASSWORD@localhost:5432/backhaul
REDIS_URL=redis://localhost:6379
```

`database/init/001_extensions.sql` enables PostGIS and `pgcrypto` when the database volume is first created. Future schema changes must be added as reproducible versioned migrations in `database/migrations/`.

## Reset local data

Stopping the stack preserves data. To intentionally delete all local database and Redis data, run:

```powershell
docker compose --env-file docker/.env -f docker/compose.yml down -v
```

This command is destructive and should never be used against production data.
