# Synchronization protocol v1

All API routes use `/api/v1`. Login accepts a username and password and returns a
one-hour JWT. Subsequent requests use `Authorization: Bearer TOKEN`; device-scoped
requests also use `X-Device-ID`. Browser WebSockets send token/device in the first
JSON frame within five seconds. Tokens are never URL parameters.

## Operation and causal context

```json
{"id":"00000000-0000-4000-8000-000000000002","record":"00000000-0000-4000-8000-000000000010","field":"notes","value":"Valve seal inspected","parents":[]}
```

`parents` contains the IDs seen for that record's field at the start of an edit.
They must exist earlier in the batch or already on the server. The server rejects
cycles, duplicate parents, self-parenting, foreign record/field references, and
changed content under an existing ID. Parent order is immaterial.

POST `/sync/push` accepts `{"operations":[...]}` in causal order (1-100 operations,
2 MiB request). An identical replay is accepted without another audit event.
The returned server cursor is informational. It MUST NOT replace the client's
pull cursor: doing so could skip another device's operations.

GET `/sync/pull?after=0` returns up to 100 entries, `cursor`, and `more`.
Store downloaded operations and the returned cursor in one local transaction.
Sequence values are contiguous per workspace. PostgreSQL serializes allocation
under the workspace row lock until commit. Lost responses are safely retried.

## Field-level CRDT

The immutable operation set forms a grow-only set. Dart's `crdt` package provides
replica storage/merge; a causal multi-value register projects field frontiers.
Operations named as parents are superseded. Concurrent leaves remain visible.
Equal concurrent values need no warning; their IDs are still included in the
next edit's parent set. Rich text, arbitrary nested document CRDTs, and peer-to-peer
network discovery are outside this implementation.

## Device recovery and attachments

Register with POST `/devices` and `{id,name}`. Registration is idempotent for the
same owner; revocation is permanent. POST `/devices/{id}/revoke` is allowed to the
owner or a workspace admin. Downloaded local data survives revocation.

POST `/attachments/{id}` sends up to 5 MiB binary content with X-Record-ID,
URL-encoded X-Filename, and a supported Content-Type. SHA-256 is calculated by the
server. Metadata listing uses GET `/attachments?record=UUID`; downloads force
Content-Disposition attachment and application/octet-stream. Files are stored
as PostgreSQL bytea and SQLite BLOBs. No filesystem paths come from filenames.

Recovery bundles are versioned JSON, with a checksum over their encoded payload.
They contain operations and attachment bytes, never tokens or passwords. Restore
requires an empty workspace, validates the causal graph and attachment hashes,
and creates a new device identity with a fresh cursor. Checksums detect corruption;
they do not authenticate the person who supplied the file.

## Limits

Sync runs while the application is open and on resume. WebSockets are hints;
periodic HTTP replay recovers missed hints. Request limits are per API process,
not shared across replicas. Device and attachment listings are capped at 500.
Version 1 retains operations and audit history indefinitely; no compaction is
performed. Browser storage remains subject to browser quotas and eviction.
