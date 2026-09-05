# Syncraft Offline Workspace

Offline-first field notes and inspections built with Flutter, Dart, SQLite, Go,
PostgreSQL, WebSockets, and field-level CRDTs. Inspections save locally before
network synchronization. Concurrent edits remain visible until an inspector
resolves the values they have observed.

## Run locally

Install Flutter **3.47.2**, Go **1.27**, Node.js **22+**, and Docker with Compose.
On Windows, keep the Flutter SDK in a path without spaces. Git and the project
may remain under a user directory that contains spaces.

From PowerShell at the repository root:

```powershell
./scripts/start.ps1
```

This builds the Flutter web client, packages its offline assets, and starts the
API, PostgreSQL, and web containers. Open **http://127.0.0.1:5176**.
The API is at **http://127.0.0.1:8091**. Docker binds both ports to loopback.

Choose **Load demo** for fictional inspections or create your own inspection.
The app works offline immediately after its first successful load and cache
installation. Connect with `inspector`, `reviewer`, `observer`, or `admin` and
password `local-demo`. `observer` is a server-enforced read-only role; `admin`
can revoke other users' devices and read operational metrics.

```bash
docker compose stop
docker compose start
```

The PostgreSQL volume survives these commands. Browser data is stored in SQLite
backed by browser storage. Clearing site data removes that device's local data.

## Workflows

- Create inspections, edit field notes, change priority/status, and complete checks.
- Search by title, site, or notes; filter status, urgency, archived records, and conflicts.
- Review concurrent values and resolve only the versions visible when editing began.
- Pause sync, continue editing, resume, and replay queued changes after failures.
- Attach JPG, PNG, PDF, or text evidence up to 5 MiB; download verified copies for offline use.
- Inspect local edit history and server audit events.
- Export recovery bundles and restore into a fresh empty device with a new identity.
- Review registered devices and revoke synchronization access.

## Development

Without Docker, the API can use explicit in-memory demo mode:

```powershell
$env:SYNCRAFT_DEMO='true'
go run ./cmd/server
```

In another terminal:

```bash
cd apps/field
flutter pub get --enforce-lockfile
flutter run -d chrome --web-port 5176 --web-hostname 127.0.0.1
```

Service-worker offline reloads are verified against the release build, not the
Flutter development server. Build with `flutter build web --release
--no-web-resources-cdn`, then run `node scripts/package-offline.mjs` from the root.
Native Windows and Android target scaffolds are included; web is the primary
end-to-end tested target. Android emulator API access uses a build-time
`--dart-define=API_URL=http://10.0.2.2:8091` with an appropriately bound API.

## Verification

```bash
go vet ./...
go test ./...
cd apps/field
flutter analyze
flutter test --coverage
```

Set `TEST_DATABASE_URL` to a disposable PostgreSQL database to enable persistence
and concurrency integration tests. CI uses PostgreSQL 17 and runs Go race tests,
Flutter analysis, unit/widget tests, release builds, and container health checks.
Coverage artifacts are retained by CI. Browser verification uses Playwright.

## Architecture

`cmd/` contains the Go service and password-hash utility; `internal/` contains
authentication, validated operations, API routes, and memory/PostgreSQL adapters.
`apps/field/lib/` separates domain projections, SQLite storage, synchronization,
and Flutter views. `deploy/` and `scripts/` hold runtime setup and packaging.

See [architecture](docs/architecture.md), [wire protocol](docs/protocol.md), and
[operations](docs/operations.md) for consistency guarantees and deployment setup.

This is a working reference application, not a certified inspection system.
Background sync runs while open or resumed, not while the OS suspends the app.
SQLite and recovery files are not encrypted by the application. Browser quotas,
eviction, and platform restrictions still apply. Version 1 retains operation
history indefinitely and supports field-level conflicts rather than rich-text
character merging. Production identity and TLS settings must replace demo mode.
