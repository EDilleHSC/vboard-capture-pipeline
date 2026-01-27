# Desktop INBOX: Watcher & Snapshot Spec

## Goal

A simple, deterministic, read-only intake boundary for desktop users. Files are dropped into `~/Desktop/INBOX`. Operators take a snapshot (immutable JSON) that records the state of the inbox at a moment in time.

## Design principles

- Read-only: no file moves, renames, or deletions
- Deterministic: same inputs → same snapshot format
- Auditable: snapshots are timestamped and stored alongside the INBOX
- Minimal: start with file metadata; add hashes/metadata later when needed

## Snapshot script

- Path: `scripts/capture_inbox_snapshot.ps1`
- Invocation: `pwsh ./scripts/capture_inbox_snapshot.ps1 -InboxPath "$HOME/Desktop/INBOX" [-IncludeHashes]`
- Behavior:
  - Validates `InboxPath` exists
  - Writes snapshot to `INBOX/_snapshots/snapshot-<YYYYMMDDTHHMMSSZ>.json`
  - Captures: `filename`, `relative_path`, `size`, `mtime` (UTC ISO 8601)
  - Optional: `sha256` when `-IncludeHashes` is provided
  - Returns non-zero on error

## Snapshot schema (example)

{
"snapshot_time": "2026-01-27T20:15:30.0000000Z",
"inbox": "/home/alice/Desktop/INBOX",
"file_count": 3,
"files": [
{"filename":"doc.pdf","relative_path":"doc.pdf","size":12345,"mtime":"2026-01-27T20:10:00Z","sha256":null}
]
}

## Operational guidance

- Initial workflow: manual snapshot after files are dropped in INBOX
- Keep `_snapshots` in the INBOX for locality and auditability
- Do not rely on snapshots for live routing until the watcher is matured and vetted in CI

## Icon & UX

- The INBOX folder is a normal desktop folder named `INBOX` with a custom icon (optional). See `assets/icons/inbox.svg` for a default.

## Next steps

- Add a read-only watcher prototype (separately) that invokes the snapshot script on-demand (no auto-moves)
- Add CI checks to validate snapshot schema (unit tests)
- Optionally include OCR verification metadata and hashing in snapshots as opt-in features
