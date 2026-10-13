# Security review — 12 October 2026

Update — 13 October 2026: stability verification passed and sensitive history was
removed from local Git refs and both affected branches on `origin`. GitHub's old
PR merge ref still needs Support cleanup. See [history cleanup report](SECURITY_HISTORY_CLEANUP.md)
for verification, preserved recovery data, and the remaining action.

## Remediation update — 12 October 2026

The findings below are the original audit record. The application fixes have now
been implemented locally, and the local backend has been restarted to activate them.
The user confirmed that there is no hosted deployment.

| Finding | Current status |
| --- | --- |
| Committed signing secret | Rotated locally to a random 48-byte key. Removed `.env` from the Git index while preserving the local file; added a placeholder example. Missing, short, and known fallback keys now stop backend startup. |
| Tracked database | Removed the database from the Git index, preserved local data, and ignored SQLite sidecar files. Sensitive history was subsequently cleaned; see the 13 October report. |
| Public personal data | Removed email and vehicle registration fields from public search, adjusted Flutter parsing, and added a search rate limit. |
| Socket expiry | Idle sockets disconnect at token expiry; every incoming socket event also checks authentication. Revoked tokens cannot reconnect. |
| Chat resource limits | Shared per-user message quotas across both transports; 4,000-code-unit messages; bounded pagination; REST and socket event limits. |
| Vulnerable npm dependencies | Installed compatible patched dependencies. Both npm audits returned zero vulnerabilities. Stopped tracking installed dependencies; retained lockfiles. |

Additional improvements: persistent server-side logout revocation, independent
session identifiers, 12-hour tokens, native secure token storage, memory-only web
tokens, rejection of plaintext production API connections, HTTPS-only release
frontend configuration, basic API security headers, and stronger registration
password validation. Existing accounts and their passwords were preserved.

Behavior changes: old sessions must sign in again. Browser refreshes require a new
login because tokens are no longer stored in localStorage. Logout requires a
successful backend response; if offline, the user gets an error and can retry.

Validation: all 12 backend test files passed, including the new security suite.
All 64 Flutter tests passed, including security, authentication, navigation, and
unchanged visual snapshots. Static analysis of the 14
changed/tested Dart targets reported no issues. Secure native storage was exercised
through its test mock; real native device packaging was not tested.
The release JavaScript web build succeeded using a verification-only HTTPS URL
and an ignored output folder (`tmp/security-web-build`). Flutter reported existing
Socket.IO WebAssembly compatibility and Cupertino font warnings; no Wasm build
was requested. Both final npm audits again returned zero vulnerabilities.
Restart the existing Flutter run session to load the dependency/authentication
changes, then sign in again. The backend process was restarted and its health
response was verified with the new no-store and nosniff headers.

Remaining limitation (updated 13 October): affected local and remote branch history
has been cleaned, but GitHub's old PR merge ref and any external copies are outside
that cleanup. The current key is rotated. See the linked history report for the
GitHub Support request and private recovery backup precautions.
Native Windows plugin setup also reported that Developer Mode/symlink support is
required for packaging; the plugin downloaded and Dart tests compiled successfully.
Breached-password screening was an optional audit recommendation and was not added.

The original audit text follows for traceability; statements about unpatched code
describe the pre-remediation state.

Scope: local Node/Express/SQLite backend, Flutter authentication/storage/configuration, tracked sensitive files, npm dependency advisories, existing backend tests, and bounded probes against an isolated in-memory database. Application code and dependencies were not changed. This is not a live deployment penetration test or a security certification.

## Findings, in priority order

### 1. High: the active local JWT signing secret is committed to Git

Evidence: `git ls-files` includes `backend/.env`. A redacted comparison against `HEAD:backend/.env` confirmed that the committed JWT_SECRET is nonempty and matches the current local configuration. No secret value was printed or copied into this report.

`backend/auth.js:11` uses this secret to sign and verify tokens. Middleware resolves the account from the token's user ID (`backend/auth.js:53`), so knowing the key permits impersonating an existing account, including an administrator if its ID is known. Setting an arbitrary ADMIN role alone does not bypass the database role lookup. On the isolated server, a manually signed token for a test driver returned HTTP 200 from `/api/auth/me` without that user's password.

Impact depends on who has repository access and whether this secret was reused in a deployed environment. Repository visibility and deployed configuration were not verified.

Fix: rotate the key wherever it was used; remove the environment file from tracking while preserving the local file; commit a placeholder-only example; assess Git-history cleanup for shared copies. Rotation is necessary even after history cleanup. Require a strong secret for any externally reachable deployment. The built-in development fallback at `backend/auth.js:4` should not be allowed outside isolated development.

### 2. High if populated with real accounts: an account database is tracked

Evidence: Git tracks `backend/backhaul.db`. Read-only aggregate queries found 13 users and 13 profiles in the current file. The schema stores email addresses, password hashes, and profile contact information. No row-level personal data or password hashes were displayed. Whether these are exclusively test accounts was not determined.

Repository readers can obtain the tracked database snapshot, bypassing API authorization and potentially attempting offline password cracking.

Fix: stop tracking databases while preserving operational copies, keep runtime data outside source control, and use synthetic seed data. Determine whether shared history contains real data and handle that exposure accordingly. Existing `.gitignore` rules do not untrack already committed files.

### 3. Medium: anonymous trip search reveals unnecessary identifying information

Evidence: `backend/server.js:1487` registers `/api/search/trips` without authentication. Its response includes driver email (`:1615`, within the driver response) and vehicle registration number (`:1588`, within the truck response). An unauthenticated request to the isolated server returned HTTP 200 with the synthetic driver's exact email and registration number. Pagination makes bulk collection possible.

Fix: define a minimal public search response, omitting email and vehicle registration. Expose private details only to authorized booking participants when required. Apply search abuse limits. Public trip discovery can remain available.

### 4. Medium: connected chat sessions remain authorized after JWT expiration

Evidence: `backend/server.js:2736` validates JWTs only during the Socket.IO handshake. Later events authorize using the stored user ID without checking token expiry. A probe connected with a two-second token, waited until REST `/api/auth/me` rejected the same token with HTTP 401, and then successfully joined a conversation over the existing socket.

An existing connection using a stolen token can outlive the token's expiry. Normal frontend logout disconnects that client's socket, but does not terminate another client's connection.

Fix: disconnect at token expiry or enforce expiry in socket event middleware, require fresh authentication on reconnect, and add server-side revocation if logout must invalidate all copies of a session token. Test expiration and revocation for both REST and sockets.

### 5. Medium: chat resource limits can be bypassed

Evidence: message and notification pagination uses unchecked `parseInt` values (`backend/server.js:2362`, `:2523`). Message queries pass the result directly to SQLite LIMIT (`backend/models.js:762`); negative limits remove the row cap. The isolated probe confirmed `limit=-1` returned all three synthetic messages. The REST message endpoint (`backend/server.js:2409`) also accepted a 90,000-character message. Neither message transport has a per-user message rate limit; the rate limiters cover login and registration only.

Transport-level request limits exist, but do not replace application-level message and request quotas. A registered conversation participant can generate large stored messages and repeatedly request full history, increasing disk, memory, and synchronous SQLite work. No load test or service disruption was attempted.

Fix: require integer pagination within a bounded range, reject negative offsets, cap message length consistently on REST and sockets, and add per-user write/event rate limits.

### 6. Dependency advisories: four affected npm packages across two manifests

Live `npm audit` results:

| Scope | Package | Registry severity | Assessment |
| --- | --- | --- | --- |
| Backend runtime | proxy-addr 2.0.7 | Critical | Upgrade to at least 2.0.8. The advisory requires a particular IPv6 trust-subnet configuration. This app currently uses `false` or a numeric hop count, so that specific exploit condition was not observed. |
| Backend runtime | qs 6.15.3 | Moderate | Upgrade to at least 6.16.0 to address the reported parser advisories. Route-level exploitability was not demonstrated. |
| Backend runtime | express 4.22.2 | Moderate | Audit flags the vulnerable qs dependency transitively; this is not an additional independent parser flaw. |
| Root development tooling | shell-quote | Critical | Upgrade to at least 1.11.0. A vulnerable quoting pattern requires attacker-controlled tokens; no application HTTP path to that function was established. |

All audit entries report fixes available. Backend audit totals: one critical and two moderate affected packages. Root audit totals: one critical affected development package. These are dependency advisory severities, not proof of critical remote exploitation in this application.

Primary advisory references: [proxy-addr](https://github.com/advisories/GHSA-jqcg-44mw-7w3h), [qs isBuffer](https://github.com/advisories/GHSA-4mjr-xmp4-gh2g), [qs array-limit](https://github.com/advisories/GHSA-x5fp-wj9c-mxmx), [shell-quote](https://github.com/advisories/GHSA-pqg4-j6r4-53mv).

Fix: update the resolved dependencies and lockfiles, remove tracked node_modules in a separate repository cleanup, reinstall reproducibly, rerun audits, and run the regression suite. Do not blindly force major-version upgrades.

## Additional hardening observations

- `frontend/lib/services/storage_service.dart:8` persists bearer tokens in SharedPreferences. Use platform-backed secure storage on native platforms; for web, evaluate an HttpOnly-cookie session design with appropriate CSRF protections. Script-readable browser token storage increases the impact of an XSS vulnerability; no XSS was demonstrated here.
- `frontend/lib/providers/auth_provider.dart:158` logs out locally. Existing JWT copies remain valid for up to seven days (`backend/auth.js:12`) because there is no server-side session revocation. Shorter-lived access tokens and revocable sessions would reduce stolen-token exposure.
- The frontend accepts configurable HTTP backend URLs, and Node serves HTTP. Production TLS termination, HTTPS enforcement, security headers, proxy routing, firewall exposure, and release configuration need deployment-level verification. Local HTTP defaults alone do not prove production traffic is unencrypted.
- Registration allows six-character passwords. Consider a stronger minimum and breached-password screening; login rate limiting is already present.

## Validation completed

- `npm test` in backend: all 11 test files passed, covering authentication rate limiting, CORS, outsider chat access, truck/trip ownership, booking integrity, completion, ratings, and payment ownership/auditing.
- `npm audit --omit=dev --json` in backend and `npm audit --json` in the root: registry access succeeded and produced the findings above.
- Bounded isolated probes confirmed anonymous data exposure, signing-key impersonation mechanics, negative pagination, oversized message acceptance, and socket authorization after token expiration. The local helper is `tmp/security-check.cjs`; it uses a synthetic key and an in-memory database and terminates its child server.
- Read-only Git/environment checks confirmed secret tracking and key reuse between HEAD and the local environment. The existing SQLite database was opened read-only for aggregate counts only.

No deployment was contacted, credentials rotated, Git history rewritten, user data modified, or application fixes applied. Flutter/Dart packages were inspected at the manifest level but did not receive a complete advisory scan. Secret checking focused on relevant first-party configuration, not an exhaustive historical scan of every Git object. Passing the existing tests does not resolve the reproduced issues.

Recommended order: rotate/remove committed secrets and data first; reduce public data exposure and upgrade affected dependencies; then enforce socket expiry and resource limits, followed by session-storage and deployment hardening.
