# Backhaul Logistics

A mobile marketplace for matching unused truck capacity—especially return trips—with compatible freight shipments along or near the same route.

## Technology direction

- Mobile: Flutter and Dart
- Backend: NestJS and TypeScript
- Data: PostgreSQL with PostGIS
- Supporting services: Redis, Firebase Cloud Messaging, S3-compatible storage

## Repository layout

```text
mobile/       Flutter application (added in the next implementation step)
backend/      NestJS API (added in the next implementation step)
database/     Database migrations and development seed data
docs/         Architecture and product-facing technical decisions
docker/       Local infrastructure configuration
.github/      CI/CD workflows
```

## First product milestone

```text
Driver registers → creates a truck → publishes a trip
Customer registers → creates a shipment → sees a matching trip
Customer requests booking → driver accepts → booking is ACCEPTED
```

See [the master specification](backhaul_logistics_codex_spec.md) and the documents in `docs/` for the current engineering baseline.
