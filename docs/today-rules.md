# TODAY — Usage & Rules

## Goal

Keep `~/TODAY` useful and _not_ a junk drawer. This document describes minimal, enforceable rules and a manual check script to keep the folder tidy.

## Principles

- Ephemeral: `TODAY` is for tasks that must be handled **today** only.
- Minimal: keep the folder for items you will act on within 24 hours.
- Promote or archive: items that require long-term storage should be moved to `~/PROJECTS`; items that require capture should go to `~/CAPTURE_HOLE`.
- Visible: use the folder as a single glanceable place for daily work.

## Rules (enforceable)

- Files may live in `~/TODAY` for a maximum of 24 hours.
- If a file is older than 24 hours, it is considered a process failure and must be escalated or moved.
- No automated moves or deletions by default. The `scripts/check_today_once.ps1` helper detects violations and reports them.

## Manual helper: `check_today_once.ps1`

- Path: `scripts/check_today_once.ps1`
- Invocation: `pwsh ./scripts/check_today_once.ps1 -TodayPath "$HOME/TODAY"`
- Behavior:
  - Scans `TODAY` and lists items older than 24 hours (sorted oldest-first).
  - Writes an append-only status line to `TODAY/_events.log` for auditability (NDJSON).
  - Exit code 0 when no violations; non-zero when violations found.

## Events log format

```
{"timestamp":"2026-01-27T20:15:30Z","action":"check","violations":1,"violated_files":["old-note.pdf"],"note":"Files older than 24h"}
```

## Operational guidance

- Run the check at the start of your day: `pwsh ./scripts/check_today_once.ps1`.
- If violations appear, either move offending items to `PROJECTS` or `CAPTURE_HOLE`, or process and remove them from `TODAY`.
- Consider adding a desktop reminder if you want stricter enforcement (optional, outside repo scope).
