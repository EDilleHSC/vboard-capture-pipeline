# Staging Plan — Controlled, Auditable Batches

This document describes how to stage large corpora (e.g., ~20k files) into the capture pipeline safely and audibly.

Principles
- Stage only (copy), do not move raw files
- Small batches (200–500 files) to keep snapshots reviewable
- Each batch creates a manifest and a snapshot before any commit
- Every action is logged in `_events/` and `_manifests/`

Phases
1. Define sources (inventory and counts)
2. Stage batches by source/date/type (one dimension at a time)
3. For each batch: copy -> snapshot -> inspect -> commit
4. Executive Secretary triages from `CAPTURE_HOLE` into `OFFICE_BOXES` or `TODAY`

Scripts
- `pwsh ./scripts/stage_batch.ps1 -SourcePath <source> [-BatchSize 300] [-IncludeHashes]`
  - Copies up to N files into `CAPTURE_HOLE/_incoming_batches/batch-XXX/`
  - Writes `manifest-batch-XXX.json` to `CAPTURE_HOLE/_manifests/`
  - Triggers `capture_inbox_snapshot.ps1` against `CAPTURE_HOLE`
- Inspect manifest and snapshot
- `pwsh ./scripts/commit_batch.ps1 -BatchId batch-XXX`
  - Moves files from the incoming batch dir into `CAPTURE_HOLE/`
  - Archives the batch into `_batches/archive/`

Manual Review
- After staging, inspect manifest and snapshot JSON. Look for unexpected file counts, missing metadata, or suspicious items.
- Only commit after you are confident the batch is correct.

Auditability
- `_manifests/manifest-<batch>.json` — records original locations and metadata
- `_snapshots/` — snapshot of the whole CAPTURE_HOLE at staging time
- `_events/events.log` — NDJSON of staging and commit events

Rollbacks
- Batches are copied, not moved; original sources are unchanged.
- If a commit is wrong, you can move files back out of `CAPTURE_HOLE` and restore from archive. Keep manifests and snapshots as proof.

Example (quick):
1. `pwsh ./scripts/stage_batch.ps1 -SourcePath "/mnt/old_archive/export" -BatchSize 300`  # creates batch-001
2. Inspect `CAPTURE_HOLE/_manifests/manifest-batch-001.json` and `CAPTURE_HOLE/_snapshots`
3. `pwsh ./scripts/commit_batch.ps1 -BatchId batch-001`
4. Executive Secretary triages contents into `OFFICE_BOXES` or `TODAY`

This is the authoritative staging plan: conservative, reversible, and auditable.