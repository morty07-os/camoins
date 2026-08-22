-- Runs only when the PostgreSQL data volume is created for the first time.
-- Application schema changes belong in versioned migrations, not this directory.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
