# Database migrations

`001_initial_schema.sql` is the first PostgreSQL/PostGIS schema migration. It is intentionally plain SQL so it can be executed by a migration runner selected in the backend-foundation phase (for example, TypeORM migrations) or directly by `psql` in a controlled development environment.

The migration is transactional and creates:

- all core marketplace tables from the master specification;
- PostGIS geographic columns and spatial indexes;
- UUID defaults, timestamps, domain enums, and data validation;
- booking status-transition checks;
- row-locked capacity allocation on booking acceptance, preventing concurrent overbooking.

Apply it only after the PostgreSQL/PostGIS service is healthy. Do not edit a migration that has been applied to a shared environment; add a new numbered migration instead.
