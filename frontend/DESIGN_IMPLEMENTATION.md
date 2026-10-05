# Camoins design update

Implemented in the existing Flutter screens, using Flutter 3.47.4 / Dart 3.13.3.
No dependencies were added or upgraded; `pubspec.yaml` and the lockfile are unchanged.

## Behavior

- Customer and driver dashboards share a neutral, abstract transport background: curved routes, pins, a slow truck, scroll parallax and a brief tap ripple. The illustration uses no GPS, map API or remote assets.
- Painting listens directly to animation controllers inside its own repaint boundary. Dashboard content does not rebuild each frame. Motion stops for inactive tabs, covered routes, background lifecycle states and reduced-motion preferences. Reduced motion also disables parallax and the navigation transition.
- Both roles share the floating curved navigation bar, with raised active icons, French labels and a 250 ms transition. GoRouter owns selection. The driver now uses the same state-preserving indexed shell architecture as the customer.
- The bar occupies Scaffold layout space, respects bottom safe insets and disappears for the keyboard. It keeps targets at least 48 pixels wide. At large text sizes the rail can scroll horizontally and reveals the selected destination automatically. Existing notification badges remain in their app-bar controls; destination icon widgets also support badges.
- Trip routes have stronger, wrapping typography. Navy/orange colors, readable orange controls, white cards and restrained shadows are shared through the theme. Chat, forms and details have no animated decoration.
- The driver's former “coming soon” shortcut now opens its real conversations screen. The separate request-management shortcut is retained.

## Modified files

| Files | Purpose |
| --- | --- |
| `lib/widgets/transport_background.dart` | Reusable illustration, interaction and lifecycle management |
| `lib/widgets/curved_transport_bar.dart` | Shared router-controlled navigation |
| `lib/pages/customer_navigation.dart`, `lib/pages/driver_navigation.dart` | Role destinations and shell integration |
| `lib/main.dart` | Driver stateful branches, preserving route URLs and authentication guards |
| `lib/navigation/main_navigation.dart` | Compatibility adjustment in the unused legacy sample router |
| `lib/pages/customer_home_page.dart`, `lib/pages/driver_home_page.dart` | Dashboard integration, real shortcuts and wrapping hero text |
| `lib/theme/app_theme.dart` | Palette, typography and control contrast |
| `lib/widgets/section_title.dart` | Solid backing behind section text |
| `lib/widgets/trip_card.dart`, `lib/pages/trip_search_results_page.dart` | Route emphasis and wrapping driver-card metadata |
| `test/customer_navigation_test.dart`, `test/driver_navigation_test.dart` | Role navigation, retained state, back navigation and dashboard snapshots |
| `test/transport_design_test.dart` | Small screen, large text, keyboard, semantics, motion and gesture checks |
| `test/flutter_test_config.dart` | Load the running Flutter SDK's fonts for readable snapshots |
| `test/goldens/customer_dashboard.png`, `test/goldens/driver_dashboard.png` | Rendered real dashboard widgets using test account fixtures |

## Verification

- `flutter analyze`: clean.
- Full Flutter suite: 55 tests passed, including authentication, trip filtering, notifications, chat/completion flows and the new design checks.
- Focused role/design tests cover switching all destinations, driver scroll retention, customer filter retention, notification detail routing, platform back handling, a 320 px screen, 200% navigation text, keyboard hiding, lifecycle pause/resume, reduced motion, and uninterrupted taps/scrolling.
- Dashboard widget snapshots were rendered and visually inspected. Snapshot account names are test fixtures; runtime screens still use the existing providers and API data.
- Flutter detected Windows and Edge, but no connected Android device. Live Android rendering, gesture navigation and frame-time profiling were not run. Back behavior was exercised through Flutter's platform-pop test API. Live backend/device end-to-end verification remains outstanding.

To run: `flutter analyze` and `flutter test` from `frontend`. To intentionally refresh dashboard references: `flutter test test/customer_navigation_test.dart test/driver_navigation_test.dart --update-goldens`.
