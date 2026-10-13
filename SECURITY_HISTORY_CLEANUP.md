# Security history cleanup — 13 October 2026

Stability checks passed before the authorized history rewrite. The application
security fixes and cleaned history have been published to `origin`. The app runs
only on this computer; no hosted application deployment was changed.

## Verification

- Backend: all 12 test files passed.
- Flutter: all 64 tests passed, including visual snapshots.
- Full `flutter analyze --no-pub`: no issues found.
- Release JavaScript web build: succeeded with a verification-only HTTPS API URL.
- Root and production backend npm dependency audits: zero reported vulnerabilities.
- After rewriting history, all 172 previously tracked source files were byte-identical
  to the tested files. The subsequent changes are documentation only.
- Local environment and live database hashes were unchanged by the rewrite.
- All local refs were checked: neither `backend/.env` nor `backend/backhaul.db`
  remained in their history. Scanning 8,803 reachable blobs found no retired signing key.
- Old reflogs were expired, unreachable objects pruned, and `git fsck --full --no-reflogs`
  completed successfully. The user's sanitized stash was preserved as one entry.

The web build reported Socket.IO WebAssembly compatibility and Cupertino font
warnings. Native device packaging was not verified; Windows native plugin setup
requires Developer Mode/symlink support. These checks establish the tested scope,
not a guarantee that every platform or security scenario is covered.

## Repository changes

Removed the historical environment file, database, and retired signing key embedded
in older source. Sanitized local checkpoint trees as well as commit refs.

The affected `origin` branches were pushed atomically with explicit leases:

- `main`: cleaned application commit `3116d8e3a737a2d57f735c396c68017169b24436`
  (followed by this documentation update).
- `codex/review-repository-for-logical-changes`:
  `e14e2843d9997ed914cffa53203bb79c7a62a562`.

The `titedj` remote's `main` history did not contain the sensitive paths or retired
key and was left unchanged. Local checkpoint and stash refs were not published.
The untracked `.claude/settings.local.json` was left untouched.

Existing clones must re-clone or carefully rebase their work onto the cleaned
history. Merging old history can reintroduce the removed data.

## Remaining GitHub cleanup

GitHub updated PR #1's head, but its read-only merge ref still points to
`5bffd76fc92a6232eba0ba5f82f2ac8627dc671e` from the old history. Branch pushes do
not remove this ref or guarantee removal of cached views or external copies.
Follow [GitHub's sensitive-data removal process](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
and contact GitHub Support. No support request has been submitted by this task.

Suggested support request:

> Please remove sensitive cached history and affected pull-request references for
> `morty07-os/camoins`, including PR #1. We removed a committed environment file,
> a SQLite account database containing password hashes and contact information,
> and a signing key embedded in historical source. The signing key has been rotated.
> Both affected branches have been rewritten and force-pushed. The first changed
> commits reported by git-filter-repo are
> `482bc1998c3b150a3eb2d566303acd811b1d48ed` and
> `d544fb6577bd699497f7fb217d7f11e14ecd42bb`.
> `refs/pull/1/merge` still points to
> `5bffd76fc92a6232eba0ba5f82f2ac8627dc671e`.
> Please assess removal of affected PR refs/cached views and server-side garbage
> collection. Key rotation does not address the historical account-data exposure.

## Private recovery material

A verified pre-rewrite bundle and local environment/database backups remain in
`tmp/security-history-20261013`, which is ignored by Git. This deliberate recovery
copy contains the retired secret and account data. Keep it private; never commit,
share, or upload it. It is outside active Git history and has not been published.
Local runtime data and the rotated signing key were preserved.

Restart any existing Flutter run session to load the authentication and dependency
changes, then sign in again. Browser refresh requires a new login because web
tokens are now held in memory. Server-side logout revokes the current session;
an offline logout shows an error so it can be retried.
