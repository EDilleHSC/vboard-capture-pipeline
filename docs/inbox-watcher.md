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

## Manual watcher (prototype)

A simple, **manual** watcher prototype is provided as `scripts/watch_inbox_once.ps1`.

Principles (non-negotiable)

- **No background daemon** — this script is **invoked manually only**.
- **No inotify / no systemd** — no services or units are installed.
- **No file moves/renames/deletes** — the script only triggers the snapshot and records an event.
- **Append-only events log** — events are written to `INBOX/_snapshots/events.log` as newline-delimited JSON (NDJSON).
- **Deterministic** — same inputs → same snapshot; watcher is a thin trigger.

Usage

From the repo root (or local copy):

```bash
pwsh ./scripts/watch_inbox_once.ps1 -InboxPath "$HOME/Desktop/INBOX"
# optional: include hashes
pwsh ./scripts/watch_inbox_once.ps1 -InboxPath "$HOME/Desktop/INBOX" -IncludeHashes
```

Events log format

Events are appended as compressed JSON on a single line (NDJSON). Example entry:

```json
{"timestamp":"2026-01-27T20:15:30Z","action":"snapshot","snapshot":"snapshot-20260127T201530Z.json","snapshot_path":"/home/alice/Desktop/INBOX/_snapshots/snapshot-20260127T201530Z.json","file_count":3,"command":"pwsh -NoProfile -NonInteractive ./scripts/capture_inbox_snapshot.ps1 -InboxPath /home/alice/Desktop/INBOX"}
```

Notes

- The watcher **does not** validate or interpret file contents — it only records that a snapshot was taken.
- The snapshot script remains the single source of truth for snapshot shape and content.
- This prototype is intentionally conservative: manual, local, and read-only.
