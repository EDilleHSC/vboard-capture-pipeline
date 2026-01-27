# Agent Boxes (Desktop)

These are the 8 canonical _agent boxes_ (desktop folders) that represent terminal endpoints in the capture pipeline. They are intentionally simple: visible on the desktop, manually managed, and auditable.

Canonical list (created on desktop):

- Executive_Secretary (MoneyPenny) — choke point for uncertainty and first sink for misclassified/ambiguous items
- CTO_Box — technical ownership & engineering follow-up
- CLO_Box — legal oversight, contracts, and privileged review
- COO_Box — operations, SLAs, process issues
- CISO_Box — security incidents and suspicious items
- Compliance_Box — regulatory, privacy, and audit artifacts
- DataOps_Box — parser, OCR, and RAG staging/ops
- Archive_Cold — long-term immutable storage

Rules (global):

- All boxes are **manual**; nothing is processed automatically by default.
- Every box must include a `_snapshots/` directory and `_events/` for append-only events (NDJSON).
- Executive_Secretary is the choke point. Overflow or uncertain items route there first.

Mapping to Capture Pipeline

- Incoming files drop into `CAPTURE_HOLE` (intake)
- Operators run watcher: `pwsh ./scripts/watch_inbox_once.ps1 -InboxPath ~/CAPTURE_HOLE`
- Snapshot is produced and validated (schema locked)
- After manual triage, items are moved (by humans) to the appropriate agent box for processing or archiving

This file documents naming, location, and high-level flow for the desktop agent boxes. No automation is included in this change.
