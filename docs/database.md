# Database Baseline

## Database choices

- PostgreSQL is the primary relational database.
- PostGIS is required for geographic operations.
- All geographic points use `GEOGRAPHY(Point, 4326)`; routes use `GEOGRAPHY(LineString, 4326)`.
- Store a display name alongside every geographic coordinate.
- Store weight in kilograms and volume in cubic meters.

## First-slice tables

| Table | Purpose |
| --- | --- |
| `users` | Authentication, account profile, status, role |
| `driver_profiles` | Driver credentials, verification, performance data |
| `trucks` | Truck type, plate, maximum capacities, capabilities |
| `trips` | Published capacity, timing, route, detour allowance, status |
| `shipments` | Cargo, pickup/delivery, requirements, status |
| `bookings` | The transactional relationship between a trip and shipment |

Future migrations add documents, route points, messages, notifications, reviews, payments, and disputes.

## Critical integrity requirements

- No negative capacity, weight, or volume.
- A trip cannot be booked when cancelled, completed, or full.
- Accepted bookings cannot exceed a trip's available capacity.
- A booking follows controlled status transitions only.
- A user cannot access another user's private resources without authorization.
- Prevent race conditions during simultaneous booking acceptance with transactions and row-level/database protection.
