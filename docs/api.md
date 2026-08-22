# API Baseline

The backend will expose REST endpoints first, versioned under `/api/v1`. WebSockets will be introduced later for chat and live tracking.

## Response envelope

Successful responses:

```json
{
  "success": true,
  "data": {},
  "message": "Operation completed successfully"
}
```

Error responses:

```json
{
  "success": false,
  "error": {
    "code": "INSUFFICIENT_CAPACITY",
    "message": "The truck does not have enough available capacity."
  }
}
```

## First-slice resource groups

- `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`
- `GET|PATCH /drivers/me`
- `GET|POST|PATCH|DELETE /drivers/me/trucks`
- `POST|GET|PATCH /trips`; `POST /trips/:id/publish`; `POST /trips/:id/cancel`
- `POST|GET|PATCH /shipments`; `POST /shipments/:id/cancel`
- `GET /matching/shipments/:shipmentId`; `GET /matching/trips/:tripId`
- `POST|GET /bookings`; `POST /bookings/:id/accept|reject|cancel`

The full OpenAPI specification is created with the NestJS application in the backend-foundation step.
