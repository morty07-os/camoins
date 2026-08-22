# Matching Baseline

Matching runs exclusively in the backend. It finds compatible trips for a shipment and compatible shipments for a trip.

## Immediate rejection rules

Reject a candidate when capacity is insufficient, the truck type is incompatible, refrigeration is unavailable, the trip is inactive, time windows do not overlap, the pickup exceeds maximum detour, or the destination is incompatible with the route direction.

## Version-one score

| Signal | Weight |
| --- | ---: |
| Route compatibility | 30% |
| Pickup proximity to route | 20% |
| Delivery proximity to route | 20% |
| Capacity fit | 15% |
| Time compatibility | 10% |
| Driver reliability | 5% |

Scores are normalized to 0–100 and returned with concise match reasons. The first version is deterministic; multi-load optimization and AI recommendations come later.

## Route principle

Exact origin/destination equality is not required. A shipment whose pickup and delivery sit along or within the driver's configured detour of the route is a strong candidate. Geographic coordinates—not city strings alone—determine compatibility.
