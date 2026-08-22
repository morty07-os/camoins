# Architecture

## Product boundary

The first release is a Flutter mobile application for drivers and customers. It connects available truck capacity with freight shipments that are compatible by route, capacity, equipment, and time.

## System ownership

```text
Flutter mobile app → REST / WebSocket API → NestJS backend → PostgreSQL + PostGIS
                                                   ├── Redis
                                                   ├── object storage
                                                   ├── push notifications
                                                   └── maps provider
```

- Flutter owns presentation, local interaction, and client-side state.
- NestJS owns authentication, authorization, validation, matching, booking transitions, and all business rules.
- PostgreSQL/PostGIS is the durable source of truth.
- Redis supports temporary/realtime data, queues, caching, and rate limits; it is not the source of truth for bookings.

## Non-negotiable decisions

- Use PostgreSQL with PostGIS; geographic locations are stored as coordinates plus a display name.
- Use UUID identifiers and server timestamps.
- Keep secrets out of Flutter and out of source control.
- Validate all client requests on the backend.
- Use transactions and database-level safeguards for booking acceptance and capacity allocation.
- Maintain role-based authorization for `DRIVER`, `CUSTOMER`, and `ADMIN`.

## First vertical slice

Authentication → Driver/Truck → Published Trip → Customer/Shipment → Matching → Booking acceptance.

Payments, advanced routing, live tracking, and multi-load optimization are intentionally outside this first slice.
