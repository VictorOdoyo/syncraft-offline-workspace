# Architecture and consistency contract

## Local first

Each device owns a SQLite database containing immutable operations, a durable
outbox, attachment bytes, a device identity, and the last acknowledged pull
cursor. Editing and enqueueing are one local transaction. A successful HTTP
response is required before an outbox item is acknowledged. Pulling and advancing
the cursor are another transaction. WebSockets carry invalidation hints only;
HTTP cursor replay is the source of truth after a disconnect.

## Conflict semantics

Each operation has a random ID, record ID, field, string value, and the IDs of
the field versions observed by its author (`parents`). The operation set is
grow-only. Dart's `crdt` package replicates immutable records; its HLC is not
used to decide which inspection value wins. A field's frontier contains all
operations not superseded by another operation. One value is unambiguous;
multiple different values are a conflict. Resolution writes a new operation
that names every observed frontier ID. Unseen concurrent work survives.

This is a field-level multi-value register, NOT character-by-character rich-text
collaboration. Deletion is an explicit archive field, never operation removal.
No operation compaction or tombstone collection is supported in version 1.

## Server trust boundary

The Go service authenticates a workspace member and registered device, checks
batch limits and causal references, then atomically stores immutable operations
and audit entries. IDs are idempotency keys: replay of identical content succeeds;
reusing an ID with different content fails. PostgreSQL workspace row locks
serialize sequence allocation with commit, preventing cursor gaps that could
skip a concurrent transaction. Demo mode uses an in-memory adapter explicitly.

Revoked devices cannot push, pull, or receive hints. Revocation cannot erase
already downloaded data. Recovery imports operations into a NEW device identity;
tokens are excluded from exported recovery bundles. Clients must treat imported
bundles as untrusted input. All data must be served over TLS outside loopback.

## Boundaries

Background synchronization means periodic sync while the app is running or
resumed. It does not promise execution while a mobile operating system suspends
the process. SQLite is not encrypted at rest by this application. Attachments
are bounded binary objects, never executable paths. Public demos use synthetic
records only. Production identity, retention, and encryption require review.
