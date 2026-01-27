# OFFICE_BOXES — Purpose & Rules

Purpose
-------
`OFFICE_BOXES` are manual, auditable agent queues. They are not personal folders and are not active workspaces. They exist to make the terminal state of the capture pipeline visible and deterministic.

Canonical layout
----------------
OFFICE_BOXES/
├── 00_EXECUTIVE_SECRETARY   (MoneyPenny)
├── 10_CFO
├── 20_CTO        (includes CISO function)
├── 30_COO
├── 40_SALES
├── 50_CMO_MARKETING
├── 60_CLO_LEGAL
└── README_OFFICE_BOXES.md

Rules (non-negotiable)
----------------------
- Each department has one box; no duplicates.
- Boxes are *queues*, not workspaces: do not perform primary work inside these folders.
- No personal or ad-hoc boxes on the Desktop; all department queues live under `OFFICE_BOXES`.
- The only active mandatory box is `00_EXECUTIVE_SECRETARY` (MoneyPenny) — all unclear or overflow items route there first.
- Every box contains `_snapshots/` and `_events/` for auditability.

Operator guidance
-----------------
- After snapshotting CAPTURE_HOLE, move classified items (manually) into the appropriate box.
- Keep boxes lightweight — they reflect work that awaits an agent.
- If an item sits too long, escalate via `00_EXECUTIVE_SECRETARY` and `TODAY`.

Inspection checklist
--------------------
- Office boxes exist and are named exactly as above.
- Boxes are empty or lightly populated.
- Unclear items are in `00_EXECUTIVE_SECRETARY`.

Rationale
---------
This structure keeps the capture pipeline auditable and reduces accidental divergence between human intent and system state.
