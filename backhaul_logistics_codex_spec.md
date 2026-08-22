# Backhaul Logistics Mobile App — Codex Master Specification

## 1. Project Overview

Build a production-ready mobile logistics marketplace focused on reducing empty return trips for trucks.

### Core problem

A truck delivers cargo from City A to City B. After delivery, the truck often returns to City A empty.

The application allows the driver/truck owner to announce available capacity on the return trip so customers near that route can book cargo transportation back toward the truck's destination or another location along/near the return route.

### Core value proposition

> Connect unused truck capacity with cargo that needs transportation in the same direction.

This is a digital backhaul / return-load marketplace.

### Example

Truck:

- Original route: Algiers → Oran
- Delivery completed in Oran
- Returning toward Algiers
- Maximum capacity: 20 tons
- Remaining capacity: 8 tons

The driver publishes:

- Current location: Oran
- Return destination: Algiers
- Available capacity: 8 tons
- Departure: tomorrow 08:00

A customer publishes:

- Pickup: Oran
- Delivery: Algiers
- Cargo: furniture
- Weight: 4 tons

The matching engine recommends the truck and the customer can request/book the transport.

---

# 2. Product Vision

Do NOT build only an app where a driver says "I am going home."

Build a broader freight-capacity marketplace:

> Trucks can publish any unused capacity on a route, with special emphasis on return trips.

The system should eventually support:

- Full loads
- Partial loads
- Multiple shipments sharing one truck
- Pickup/drop-off near the route
- Route-aware matching
- Live tracking
- Driver/customer reputation
- Transport documents
- Payments
- Automated notifications
- Fleet management
- Advanced route optimization

The initial MVP should prove one central hypothesis:

> Can the platform reliably match an available truck capacity with a compatible shipment?

---

# 3. Platforms

## Initial target

Mobile only.

Build one Flutter codebase for:

- Android
- iOS

Do not build a separate web frontend for the main product.

An admin web panel can be added later if needed, but it is outside the first mobile MVP.

---

# 4. Recommended Technology Stack

## Mobile

- Flutter
- Dart
- Riverpod for state management
- GoRouter for navigation
- Dio for HTTP/API requests
- Freezed + json_serializable where appropriate
- Flutter Secure Storage for tokens
- Firebase Cloud Messaging for push notifications
- Google Maps Flutter or Mapbox for maps
- Geolocator for GPS/location
- Image/file picker for documents and truck photos

## Backend

- NestJS
- TypeScript
- REST API
- WebSockets / Socket.IO for realtime functionality
- JWT authentication
- Refresh tokens
- Class-validator / DTO validation
- OpenAPI / Swagger documentation

## Database

Primary database:

- PostgreSQL

Geospatial extension:

- PostGIS

Why PostgreSQL + PostGIS:

- Strong relational integrity
- Transactions
- Relationships between users, trucks, trips, shipments, bookings, payments, etc.
- Geographic queries
- Nearby-point searches
- Route and distance calculations
- Future support for route matching and optimization

Do NOT use MongoDB as the primary database for this project unless there is a very strong architectural reason.

## Additional infrastructure

- Redis for caching, queues, rate limiting, temporary/live data and background jobs
- S3-compatible object storage for images/documents
- Firebase Cloud Messaging for push notifications
- Sentry for crash/error monitoring
- GitHub Actions for CI/CD
- Docker for local development and deployment consistency

---

# 5. High-Level Architecture

```text
                         FLUTTER MOBILE APP
                    ┌────────────┴────────────┐
                    │                         │
                 DRIVER                    CUSTOMER
                    │                         │
                    └────────────┬────────────┘
                                 │
                              REST API
                                 │
                       ┌─────────┴─────────┐
                       │                   │
                   NestJS API        WebSocket API
                       │                   │
                       └─────────┬─────────┘
                                 │
                         PostgreSQL + PostGIS
                                 │
                    ┌────────────┼─────────────┐
                    │            │             │
                  Redis        Storage       Maps API
```

Architecture rule:

- Flutter handles UI, presentation, local mobile interaction and client-side state.
- Backend owns business rules, security, matching, booking state, validation and data integrity.
- Database is the source of truth.
- Never put important business rules only in Flutter.

---

# 6. User Roles

## Driver / Truck Owner

Can:

- Register
- Verify identity
- Create driver profile
- Add one or more trucks
- Upload truck documents
- Publish trips
- Set available capacity
- Define route
- Accept/reject shipment requests
- Chat with customers
- See active bookings
- Share live location
- Mark pickup
- Mark delivery
- View completed trips
- View earnings
- Receive ratings
- Report problems

## Customer / Shipper

Can:

- Register
- Create customer profile
- Create shipment request
- Define pickup
- Define delivery
- Enter cargo information
- Search for trucks
- See recommended matches
- Request booking
- Chat with driver
- Track shipment
- Confirm delivery
- Rate driver
- View shipment history

## Admin

Admin capabilities eventually include:

- User management
- Driver verification
- Customer management
- Truck verification
- Trip management
- Shipment management
- Booking management
- Complaint/dispute handling
- Reviews moderation
- Platform statistics
- Suspensions/bans
- Document verification

Admin panel is not required in the first mobile MVP, but backend permissions must support the ADMIN role.

---

# 7. Main Product Flows

## Driver flow

```text
Register
  ↓
Create driver profile
  ↓
Verify identity
  ↓
Add truck
  ↓
Create trip
  ↓
Set origin
  ↓
Set destination
  ↓
Set departure time
  ↓
Set available weight/volume
  ↓
Publish trip
  ↓
Receive matching shipment requests
  ↓
Accept request
  ↓
Pickup
  ↓
Transport
  ↓
Delivery
  ↓
Complete trip
  ↓
Rating
```

## Customer flow

```text
Register
  ↓
Create shipment
  ↓
Pickup location
  ↓
Destination
  ↓
Cargo details
  ↓
Weight / volume
  ↓
Pickup time
  ↓
Search matches
  ↓
Review recommended trucks
  ↓
Request booking
  ↓
Driver accepts
  ↓
Pickup
  ↓
Transport
  ↓
Delivery
  ↓
Confirmation
  ↓
Rating
```

---

# 8. Critical UX Principle

The app must remain simple.

Complexity should live in the backend and matching engine, not in long forms.

## Driver publish-return-trip screen

Prefer a very short flow:

```text
WHERE ARE YOU?
[ Oran ]

WHERE ARE YOU GOING?
[ Algiers ]

WHEN?
[ Tomorrow - 08:00 ]

AVAILABLE CAPACITY
[ 8 tons ]

MAXIMUM DETOUR
[ 20 km ]

[ PUBLISH TRIP ]
```

## Customer create-shipment screen

```text
FROM
[ Oran ]

TO
[ Algiers ]

CARGO
[ Furniture ]

WEIGHT
[ 4 tons ]

VOLUME
[ Optional ]

DATE
[ 24 Aug ]

[ FIND TRUCKS ]
```

---

# 9. Core Domain Model

Main entities:

```text
User
Driver
Customer
Truck
TruckDocument
Trip
RoutePoint
Shipment
Cargo
Booking
Message
Review
Notification
Payment
Dispute
Verification
```

Relationship overview:

```text
User
 ├── Driver
 │    └── Trucks
 │         └── Trips
 │              └── Available Capacity
 │
 └── Customer
      └── Shipments

Trip + Shipment
       ↓
    Booking
       ↓
 Payment / Tracking / Review
```

---

# 10. Database Design

Use PostgreSQL with PostGIS.

## users

Fields:

- id
- role
- first_name
- last_name
- phone
- email
- password_hash
- profile_image_url
- status
- created_at
- updated_at
- last_login_at

Roles:

- DRIVER
- CUSTOMER
- ADMIN

## driver_profiles

Fields:

- id
- user_id
- license_number
- verification_status
- rating_average
- completed_trip_count
- cancellation_count
- created_at
- updated_at

## trucks

Fields:

- id
- driver_id
- truck_type
- plate_number
- max_weight_kg
- max_volume_m3
- refrigerated
- dimensions
- description
- status
- created_at
- updated_at

Truck types should be extensible, for example:

- VAN
- BOX_TRUCK
- FLATBED
- SEMI_TRAILER
- REFRIGERATED
- TANKER
- PICKUP
- OTHER

## truck_documents

Fields:

- id
- truck_id
- document_type
- file_url
- status
- expiration_date
- created_at

## trips

This is one of the most important tables.

Fields:

- id
- truck_id
- origin_name
- destination_name
- origin_point GEOGRAPHY(Point, 4326)
- destination_point GEOGRAPHY(Point, 4326)
- route_geometry GEOGRAPHY(LineString, 4326)
- departure_time
- estimated_arrival_time
- available_weight_kg
- available_volume_m3
- max_detour_km
- status
- created_at
- updated_at

Possible statuses:

- DRAFT
- PUBLISHED
- FULL
- IN_PROGRESS
- COMPLETED
- CANCELLED
- EXPIRED

## trip_route_points

Optional detailed route points:

- id
- trip_id
- sequence_number
- point GEOGRAPHY(Point, 4326)
- place_name

## shipments

Fields:

- id
- customer_id
- pickup_name
- delivery_name
- pickup_point GEOGRAPHY(Point, 4326)
- delivery_point GEOGRAPHY(Point, 4326)
- weight_kg
- volume_m3
- cargo_type
- description
- pickup_time_start
- pickup_time_end
- required_truck_type
- fragile
- refrigerated_required
- status
- created_at
- updated_at

Possible statuses:

- DRAFT
- OPEN
- MATCHED
- BOOKED
- PICKUP_PENDING
- IN_TRANSIT
- DELIVERED
- CANCELLED

## bookings

Fields:

- id
- trip_id
- shipment_id
- customer_id
- driver_id
- agreed_price
- currency
- requested_at
- accepted_at
- pickup_confirmed_at
- delivered_at
- status
- cancellation_reason
- created_at
- updated_at

Possible statuses:

- REQUESTED
- ACCEPTED
- REJECTED
- CANCELLED
- PICKUP_CONFIRMED
- IN_TRANSIT
- DELIVERED
- DISPUTED

## messages

Fields:

- id
- booking_id
- sender_id
- message_type
- content
- attachment_url
- created_at
- read_at

## reviews

Fields:

- id
- booking_id
- reviewer_id
- reviewee_id
- rating
- comment
- created_at

## notifications

Fields:

- id
- user_id
- type
- title
- body
- data_json
- read_at
- created_at

## payments

Fields:

- id
- booking_id
- payer_id
- receiver_id
- amount
- platform_fee
- currency
- provider
- provider_reference
- status
- created_at

Payment integration can be implemented after the core marketplace flow.

## disputes

Fields:

- id
- booking_id
- opened_by
- reason
- description
- status
- resolution
- created_at
- resolved_at

---

# 11. Geospatial Model

PostGIS is a central part of the application.

Every important location should be stored as geographic coordinates.

Examples:

- pickup point
- delivery point
- trip origin
- trip destination
- truck current position
- route geometry
- intermediate route points

Do not rely only on strings such as "Oran" or "Algiers".

Store:

- display name
- latitude/longitude
- geographic geometry

This allows:

- Nearby search
- Distance calculations
- Route compatibility
- Maximum detour checks
- Live truck location
- Future route optimization

Use SRID 4326.

---

# 12. Matching Engine

The matching engine is the heart of the product.

It must NOT live exclusively in Flutter.

Create a dedicated backend module:

```text
matching/
 ├── matching.controller.ts
 ├── matching.service.ts
 ├── matching.repository.ts
 ├── scoring/
 ├── dto/
 └── types/
```

## Version 1 scoring

Use deterministic rules first.

Suggested weights:

- Route compatibility: 30%
- Pickup proximity: 20%
- Destination proximity: 20%
- Available capacity: 15%
- Time compatibility: 10%
- Driver rating/reliability: 5%

Return a normalized score from 0 to 100.

Example:

```text
Truck A — 96%
Truck B — 91%
Truck C — 84%
Truck D — 71%
```

## Matching rules

Reject candidates when:

- Capacity is insufficient
- Truck type is incompatible
- Refrigeration requirement is not met
- Driver is unavailable
- Trip is cancelled or completed
- Shipment pickup is after trip availability
- Pickup is beyond driver's maximum detour
- Destination is completely incompatible with the trip route

Rank candidates based on:

- Pickup distance to route
- Delivery distance to route
- Route direction similarity
- Capacity fit
- Time compatibility
- Driver reliability

---

# 13. Route Compatibility

Exact origin/destination matching is NOT required.

Example:

Truck:

```text
Oran
↓
Relizane
↓
Chlef
↓
Blida
↓
Algiers
```

Shipment:

```text
Chlef → Algiers
```

This should be considered a strong match.

Another shipment:

```text
Oran → Tlemcen
```

Should be considered poor/not compatible.

Add a route detour concept:

```text
Driver max detour:
5 km
10 km
20 km
50 km
```

The customer pickup may be slightly off-route, but the system should calculate whether the detour is acceptable.

---

# 14. Future Multi-Load Optimization

Do NOT build advanced multi-load optimization in the first MVP.

Design the database and backend so it can be added later.

Example:

Truck capacity:

- 20 tons

Already booked:

- 12 tons

Remaining:

- 8 tons

Possible future matching:

```text
Shipment A: 3 tons
Oran → Chlef

Shipment B: 2 tons
Relizane → Algiers

Shipment C: 3 tons
Oran → Algiers
```

This can lead to 100% utilization.

Future goal:

> Maximize truck capacity utilization while respecting route, time, weight, volume and cargo constraints.

---

# 15. "Going Back Empty?" Feature

This should be a major driver UX feature.

After a trip is near completion:

```text
GOING BACK EMPTY?

Current:
Oran

Returning toward:
Algiers

Available:
8 tons

Departure:
Tomorrow 07:00

[ FIND LOADS ]
```

The backend can immediately search open shipments that fit the return direction.

This feature directly addresses the original business problem.

---

# 16. Mobile Screens

## Shared

1. Splash
2. Onboarding
3. Login
4. Registration
5. Phone/email verification
6. Forgot password
7. Notifications
8. Profile
9. Settings
10. Help/support

## Driver

1. Driver dashboard
2. My trucks
3. Add truck
4. Truck details
5. Truck documents
6. Publish trip
7. Trip details
8. Available loads
9. Matching results
10. Requests
11. Booking details
12. Active transport
13. Live trip map
14. Chat
15. Earnings
16. Trip history
17. Reviews
18. Driver verification

## Customer

1. Customer dashboard
2. Create shipment
3. Shipment details
4. Search trucks
5. Matching results
6. Truck details
7. Driver details
8. Booking request
9. Active shipment
10. Live tracking
11. Chat
12. Shipment history
13. Reviews
14. Profile

---

# 17. Navigation

Use role-based navigation.

## Driver bottom navigation

```text
Home
Trips
Requests
Messages
Profile
```

## Customer bottom navigation

```text
Home
Shipments
Bookings
Messages
Profile
```

Do not create separate unrelated navigation structures unless necessary.

---

# 18. Flutter Project Structure

Use a feature-first architecture.

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── bootstrap.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── network/
│   ├── storage/
│   ├── theme/
│   ├── utils/
│   ├── permissions/
│   └── services/
│
├── shared/
│   ├── widgets/
│   ├── models/
│   └── extensions/
│
└── features/
    ├── auth/
    ├── profile/
    ├── drivers/
    ├── customers/
    ├── trucks/
    ├── trips/
    ├── shipments/
    ├── matching/
    ├── bookings/
    ├── tracking/
    ├── messaging/
    ├── notifications/
    ├── reviews/
    └── payments/
```

Each feature should generally use:

```text
feature/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── providers/
    ├── screens/
    └── widgets/
```

Do not over-engineer tiny features, but maintain clean separation between UI, state and API/data logic.

---

# 19. Backend Project Structure

Use NestJS modules.

```text
src/
├── main.ts
├── app.module.ts
│
├── common/
│   ├── guards/
│   ├── interceptors/
│   ├── filters/
│   ├── decorators/
│   ├── pipes/
│   └── utils/
│
├── auth/
├── users/
├── drivers/
├── customers/
├── trucks/
├── trips/
├── shipments/
├── matching/
├── bookings/
├── tracking/
├── messaging/
├── notifications/
├── reviews/
├── payments/
└── disputes/
```

Each module should contain appropriate:

- controller
- service
- repository
- DTOs
- entities/models
- validation
- tests

---

# 20. API Design

Use REST initially.

Example endpoints:

## Auth

```text
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
POST /auth/verify
POST /auth/forgot-password
POST /auth/reset-password
```

## Driver

```text
GET    /drivers/me
PATCH  /drivers/me
GET    /drivers/me/trucks
POST   /drivers/me/trucks
PATCH  /drivers/me/trucks/:id
DELETE /drivers/me/trucks/:id
```

## Trips

```text
POST /trips
GET  /trips
GET  /trips/:id
PATCH /trips/:id
DELETE /trips/:id
POST /trips/:id/publish
POST /trips/:id/cancel
```

## Shipments

```text
POST /shipments
GET  /shipments
GET  /shipments/:id
PATCH /shipments/:id
POST /shipments/:id/cancel
```

## Matching

```text
GET /matching/shipments/:shipmentId
GET /matching/trips/:tripId
```

## Bookings

```text
POST /bookings
GET  /bookings
GET  /bookings/:id
POST /bookings/:id/accept
POST /bookings/:id/reject
POST /bookings/:id/cancel
POST /bookings/:id/pickup
POST /bookings/:id/deliver
```

## Tracking

```text
POST /tracking/location
GET  /tracking/:bookingId
```

Realtime can later use WebSockets for location updates and chat.

---

# 21. Authentication and Security

Implement:

- Password hashing with Argon2 or bcrypt
- JWT access tokens
- Refresh tokens
- Secure token storage in Flutter
- Role-based authorization
- Request validation
- Rate limiting
- Input sanitization
- Secure file upload validation
- HTTPS only
- Audit logs for sensitive actions
- Do not expose database credentials to Flutter

Never put:

- database credentials
- JWT secrets
- private API secrets
- payment secrets

inside the Flutter application.

---

# 22. Push Notifications

Use Firebase Cloud Messaging.

Important notifications:

### Driver

- New shipment matches trip
- New booking request
- Customer accepted/updated booking
- Pickup reminder
- Delivery reminder
- Cancellation
- New message
- Rating received

### Customer

- New matching truck
- Driver accepted booking
- Driver rejected request
- Driver arriving
- Pickup confirmed
- Shipment in transit
- Delivery completed
- New message
- Cancellation
- Refund/payment status

---

# 23. Realtime Tracking

For active trips:

```text
Driver Flutter
     ↓
GPS
     ↓
WebSocket
     ↓
Backend
     ↓
Customer Flutter
```

GPS updates should not be unnecessarily frequent.

Use reasonable batching/throttling and configurable tracking intervals to reduce:

- Battery consumption
- Network traffic
- Backend cost

Live position can be cached in Redis while durable trip/booking state stays in PostgreSQL.

---

# 24. Maps and Location

Use a maps provider such as:

- Google Maps
- Mapbox

Requirements:

- Map display
- Search
- Place selection
- Geocoding
- Reverse geocoding
- Route drawing
- Distance calculations
- ETA when supported
- Current driver location

Keep the maps provider behind a service abstraction so it can be changed later.

---

# 25. Pricing

Do not hard-code a single pricing algorithm at the beginning.

The system should be able to support:

- Driver-defined price
- Customer offer
- Negotiation
- Platform-suggested price
- Future dynamic pricing

For MVP, the simplest model is:

1. Driver or platform defines a price.
2. Customer sees the price.
3. Customer sends booking request.
4. Driver accepts/rejects.

Currency must be configurable.

---

# 26. Payments

Payment architecture should support:

```text
Customer
    ↓
Payment provider
    ↓
Platform
    ↓
Booking completed
    ↓
Driver payout
```

The exact payment provider is country-dependent and should be integrated after the legal/business model is decided.

Do not build fake payment logic that looks real in production.

For MVP, payment can initially be:

- Cash on delivery
- External/manual settlement
- Payment-status placeholder

depending on operational requirements.

---

# 27. Verification and Trust

Trust is critical for the marketplace.

Driver profile should eventually show:

```text
★★★★★ 4.8

142 completed trips

✓ Identity verified
✓ Driver license verified
✓ Truck documents verified
✓ Insurance verified
```

Track:

- Rating
- Completed trips
- Cancellation rate
- No-show rate
- Verification status
- Complaint rate

Use these values in ranking/reliability scoring later.

---

# 28. Reviews

Both sides should eventually rate each other.

Driver can rate customer.

Customer can rate driver.

Minimum:

- 1–5 star rating
- Optional comment

Prevent duplicate reviews for one booking.

---

# 29. Admin and Moderation

Backend must support admin controls even if the first UI is not built.

Admins need to be able to:

- Verify drivers
- Verify trucks
- Suspend accounts
- Cancel fraudulent bookings
- Resolve disputes
- Remove inappropriate reviews
- View system metrics
- View operational data

---

# 30. MVP Scope

The first production MVP should contain:

### Must have

- Flutter mobile app
- Authentication
- Driver accounts
- Customer accounts
- Driver profiles
- Truck management
- Trip creation
- Trip publication
- Shipment creation
- Geographic locations
- Search
- Matching
- Booking requests
- Accept/reject booking
- Push notifications
- Basic chat
- Trip/shipment status
- Reviews
- Basic admin moderation support
- PostgreSQL + PostGIS
- Backend API
- Security
- Error logging

### Later

- Advanced multi-load optimization
- Dynamic pricing
- Integrated payments
- Insurance
- Fleet management
- Enterprise accounts
- AI route optimization
- Predictive backhaul recommendations
- Automated document OCR
- Advanced analytics

---

# 31. Development Roadmap

## Phase 0 — Product and Architecture

Deliver:

- User flows
- Wireframes
- UI design
- Database ERD
- API specification
- Architecture
- Security model
- Matching rules

## Phase 1 — Foundation

Build:

- Flutter app
- NestJS backend
- PostgreSQL
- PostGIS
- Docker
- Authentication
- Roles
- CI/CD
- Logging

## Phase 2 — Driver

Build:

- Driver profile
- Truck CRUD
- Documents
- Trip creation
- Route selection
- Capacity management
- Publish/cancel trip

## Phase 3 — Customer

Build:

- Customer profile
- Shipment creation
- Cargo details
- Pickup/delivery
- Search

## Phase 4 — Matching

Build:

- Geographic matching
- Capacity validation
- Route compatibility
- Time compatibility
- Scoring
- Ranked results

## Phase 5 — Booking

Build:

- Request
- Accept
- Reject
- Cancel
- Pickup confirmation
- Delivery confirmation

## Phase 6 — Communication

Build:

- Push notifications
- Basic chat
- Booking notifications

## Phase 7 — Tracking

Build:

- GPS
- Active trip map
- Live location
- ETA
- Route progress

## Phase 8 — Trust

Build:

- Verification
- Ratings
- Reviews
- Reliability score
- Complaints

## Phase 9 — Payments

Build:

- Payment provider integration
- Commission
- Transaction history
- Driver payout

## Phase 10 — Optimization

Build:

- Multi-load optimization
- Automatic return-load suggestions
- Capacity utilization
- Dynamic pricing
- Advanced analytics

---

# 32. Testing Strategy

Do not wait until the end.

## Flutter

Test:

- Unit tests
- Provider/state tests
- Widget tests
- Integration tests

Critical flows:

- Registration
- Login
- Add truck
- Publish trip
- Create shipment
- Search matches
- Booking
- Tracking

## Backend

Test:

- Unit tests
- Service tests
- Controller/API tests
- Database integration tests
- Matching-engine tests

## Matching-engine test cases

Create realistic test data for:

1. Exact origin/destination
2. Pickup near route
3. Delivery near route
4. Insufficient capacity
5. Wrong truck type
6. Refrigeration requirement
7. Excessive detour
8. Wrong date
9. Driver unavailable
10. Cancelled trip

---

# 33. Seed Data for Development

Create seed data for:

### Cities

Start with major Algerian cities as development examples:

- Algiers
- Oran
- Blida
- Chlef
- Relizane
- Tlemcen
- Mostaganem
- Mascara
- Sidi Bel Abbès
- Setif
- Constantine
- Annaba
- Batna
- Béjaïa

The system should NOT be hard-coded to Algeria. Country/region support should be extensible.

### Sample drivers

Create realistic test drivers.

### Sample trucks

Different capacities and truck types.

### Sample trips

Create multiple route directions.

### Sample shipments

Create requests that:

- Match exactly
- Match partially
- Are near the route
- Should not match

---

# 34. Development Quality Rules

Follow these rules throughout development:

1. Do not write business logic directly in Flutter widgets.
2. Do not duplicate API models unnecessarily.
3. Do not put database credentials in mobile code.
4. Do not trust client-provided pricing/capacity/status without backend validation.
5. Use transactions for critical booking/payment operations.
6. Prevent double booking with database constraints and transactional logic.
7. Use server timestamps as the source of truth.
8. Validate all coordinates.
9. Validate weight and volume units consistently.
10. Use kilograms and cubic meters internally unless a clear international unit system is required.
11. Keep IDs UUID-based.
12. Add indexes for common PostgreSQL/PostGIS queries.
13. Add pagination to list endpoints.
14. Add rate limiting.
15. Add structured logging.
16. Keep configuration in environment variables.
17. Never commit secrets.
18. Write tests for critical business rules.
19. Prefer small focused modules.
20. Document important architectural decisions.

---

# 35. Important Database Constraints

The backend/database should prevent:

- Booking more capacity than available
- Negative truck capacity
- Negative shipment weight
- A completed trip being booked
- A cancelled booking becoming active
- Duplicate reviews
- Invalid status transitions
- Unauthorized access to another user's private data

For booking acceptance, use a transaction and database-level protection against race conditions.

Example:

Two customers try to book the final 5 tons simultaneously.

Only one request should succeed.

---

# 36. API Response Standards

Use consistent API response structures.

Success example:

```json
{
  "success": true,
  "data": {},
  "message": "Operation completed successfully"
}
```

Error example:

```json
{
  "success": false,
  "error": {
    "code": "INSUFFICIENT_CAPACITY",
    "message": "The truck does not have enough available capacity."
  }
}
```

Use HTTP status codes correctly.

---

# 37. Environment Configuration

Backend environment examples:

```text
NODE_ENV=
PORT=

DATABASE_URL=

JWT_ACCESS_SECRET=
JWT_REFRESH_SECRET=

REDIS_URL=

S3_ENDPOINT=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_BUCKET=

FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=

MAPS_API_KEY=

SENTRY_DSN=
```

Flutter should receive only public/client-safe configuration.

Never include backend database credentials in Flutter.

---

# 38. Repository Structure

Recommended monorepo:

```text
backhaul-app/
├── mobile/
│   └── Flutter project
│
├── backend/
│   └── NestJS project
│
├── database/
│   ├── migrations/
│   └── seed/
│
├── docs/
│   ├── architecture.md
│   ├── api.md
│   ├── database.md
│   └── matching.md
│
├── docker/
│
├── .github/
│   └── workflows/
│
└── README.md
```

---

# 39. Codex Development Instructions

When implementing this project, follow this order.

## Step 1

Create the repository structure.

## Step 2

Create the Flutter project under `mobile/`.

## Step 3

Create the NestJS project under `backend/`.

## Step 4

Set up PostgreSQL + PostGIS locally with Docker.

## Step 5

Create migrations for:

- users
- driver_profiles
- trucks
- truck_documents
- trips
- trip_route_points
- shipments
- bookings
- messages
- reviews
- notifications
- payments
- disputes

## Step 6

Implement authentication and role-based access.

## Step 7

Implement Driver flow.

## Step 8

Implement Customer flow.

## Step 9

Implement matching engine.

## Step 10

Implement booking lifecycle.

## Step 11

Implement notifications.

## Step 12

Implement chat.

## Step 13

Implement live tracking.

## Step 14

Implement reviews and trust.

## Step 15

Add automated tests.

## Step 16

Prepare staging deployment.

Do not attempt to implement the entire system in one massive coding operation.

Complete one vertical slice at a time.

---

# 40. First Vertical Slice

The first working end-to-end slice should be:

```text
Driver registers
   ↓
Creates truck
   ↓
Publishes trip
   ↓
Customer registers
   ↓
Creates shipment
   ↓
Backend finds matching trip
   ↓
Customer sees truck
   ↓
Customer sends booking request
   ↓
Driver accepts
   ↓
Booking becomes ACCEPTED
```

This is the first milestone.

Do not build payments or sophisticated tracking before this complete flow works reliably.

---

# 41. Definition of Done for MVP

The MVP is considered functional when:

- Driver can register
- Customer can register
- Driver can create truck
- Driver can publish trip
- Customer can create shipment
- Locations are stored with geographic coordinates
- Matching engine returns compatible trips
- Customer can request booking
- Driver can accept/reject
- Capacity cannot be overbooked
- Booking state transitions work
- Both users receive notifications
- Users can communicate
- Trip/shipment status works
- Users can rate one another
- Errors are handled properly
- Critical backend logic has automated tests
- Mobile app communicates securely with backend
- Database migrations are reproducible
- No secrets are committed
- Staging environment can be deployed

---

# 42. Product Philosophy

The product should optimize for:

1. Simplicity
2. Trust
3. Speed
4. Reliable matching
5. Low friction for drivers
6. Clear logistics information
7. Geographic accuracy
8. Scalability

The driver should be able to publish unused capacity in seconds.

The customer should be able to find a suitable truck in seconds.

The platform should do the complicated route/capacity matching automatically.

---

# 43. Long-Term Vision

Eventually the platform should evolve into a logistics optimization network.

Potential future capability:

```text
Truck:
Oran → Algiers
20 tons

System detects:
8 tons unused

System searches:
Nearby shipments
+
Compatible time
+
Compatible route
+
Compatible cargo

System recommends:
Shipment A — 3t
Shipment B — 2t
Shipment C — 3t

Result:
20/20 tons utilized
```

Long-term objective:

> Maximize transportation utilization and reduce empty kilometers.

---

# 44. Final Technical Decision

Use:

```text
Flutter
+
NestJS
+
PostgreSQL
+
PostGIS
+
Redis
+
Firebase
+
Google Maps / Mapbox
+
S3-compatible storage
+
Docker
+
GitHub Actions
+
Sentry
```

Primary database:

> PostgreSQL + PostGIS

Primary architecture:

> Flutter mobile frontend + NestJS backend + PostgreSQL/PostGIS database.

Primary product concept:

> A backhaul marketplace that connects empty-returning trucks with shipments along or near their return route.

---

# 45. Instruction to Codex

Treat this document as the master product and engineering specification.

Before implementing a feature:

1. Respect the architecture defined here.
2. Reuse existing patterns instead of creating inconsistent new ones.
3. Do not silently replace PostgreSQL/PostGIS with another database.
4. Do not move core business logic into Flutter.
5. Keep interfaces clean and production-oriented.
6. Update documentation when architecture changes.
7. Write tests for critical business rules.
8. Prefer incremental implementation.
9. Do not create fake production integrations.
10. When a requirement is ambiguous, choose the simplest scalable interpretation that preserves the core backhaul marketplace concept.

Start by implementing the project foundation and the first vertical slice:

```text
Authentication
→ Driver + Truck
→ Publish Trip
→ Customer + Shipment
→ Matching
→ Booking
```

Then expand feature by feature.
