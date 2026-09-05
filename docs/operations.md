# Operating Syncraft

## Production configuration

The included Compose file is a loopback demonstration with fixed demo credentials.
For a deployment, set SYNCRAFT_DEMO=false, DATABASE_URL, JWT_SECRET (at least 32
random bytes), USERS_JSON, and ALLOWED_ORIGINS. Serve API and web through TLS.
Configure the Flutter build with `--dart-define=API_URL=https://api.example.com`.
Origin lists are exact comma-separated origins; wildcard origins are rejected.

USERS_JSON maps usernames to password_hash, workspace, and role. Roles are
editor, viewer, and admin. Generate bcrypt hashes by piping a 12-72 byte password
to `go run ./cmd/password`. Keep passwords, signing keys, and the resulting
configuration outside Git. All authenticated users are restricted to their
configured workspace. Device IDs are bound to their registering actor.

JWTs expire after one hour. The application retains them only in memory and
requires reconnection after expiry/reload. Identity and role changes in server
configuration invalidate existing claims when checked. Restart services after
changing configuration. Device revocation is permanent, rechecked on writes and
periodically on WebSockets; it cannot erase downloaded records.

## Persistence and recovery

Back up PostgreSQL with pg_dump or a managed snapshot service, encrypt backups,
and test restoration into an isolated database. The first migration is embedded
in the Go service and guarded by a PostgreSQL advisory transaction lock. Future
schema changes must use explicit versioned migrations rather than editing
already deployed definitions. The initial bootstrap is idempotent.

Device export files contain sensitive content and evidence bytes. Their SHA-256
detects accidental corruption, not malicious authorship. Restore accepts only an
empty local workspace, validates causal parents, and creates a fresh device ID.
Register the new device and let immutable IDs deduplicate server replay.

Do not clear a device's site data until queued work is synchronized or exported.
Do not use `docker compose down -v` on a database you intend to retain.

## Monitoring

- `/health/live`: process liveness; `/health/ready`: storage connectivity.
- `/api/v1/metrics`: Prometheus text counters, admin role and active device required.
- Every response has an X-Request-ID; tokens and content are not logged.
- Audit events record operation acceptance, device lifecycle, and attachment storage.
- A rising pending-edit count or repeated sync failures needs investigation.

Metrics and request rate limits are per process. WebSocket hints are also local
to a process; clients polling every 15 seconds still converge across multiple
API instances. Use an ingress-wide rate limit for horizontally scaled deployments.

The server limits JSON to 2 MiB, sync batches to 100, attachment bodies to 5 MiB,
and incoming WebSocket authentication frames to 4096 bytes. Request timeouts,
database pool size, and retry intervals are bounded. Attachments are served for
download; malware scanning is not implemented. History is append-only at the
application level, not protected from a database administrator.

## Failure exercises

1. Load the release app, wait for offline assets to install, then disable networking.
2. Create an inspection, edit notes, and reload; confirm edits remain local.
3. Reconnect and sync; confirm pending count reaches zero.
4. Use two browser profiles, pause both, edit the same field, then resume both.
5. Resolve the resulting values; verify both profiles converge on the resolution.
6. Export, restore into a new profile, reconnect, and verify no duplicate records.

Mobile OS background execution, encrypted local storage, operation compaction,
antivirus scanning, rich-text CRDT editing, and external identity federation are
not implemented. These are explicit extension points, not production claims.
