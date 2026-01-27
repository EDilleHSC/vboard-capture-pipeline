# TODAY — Usage & Daily Ritual

Purpose
-------
`TODAY` is your daily execution surface — temporary, human-facing, decision-oriented.

Required structure
------------------
TODAY/
├── README_TODAY.md
├── _events.log
└── [items YOU must handle today]

Rules (non-negotiable)
----------------------
- Items appear in `TODAY` only after review (Executive Secretary or equivalent).
- Files in `TODAY` are short-lived: you empty `TODAY` every day.
- No raw intake (use `CAPTURE_HOLE`), and no department queues (those live under `OFFICE_BOXES`).
- Use `scripts/check_today_once.ps1` daily to detect items older than 24h; it logs events to `_events.log`.

Daily inspection ritual (2–3 minutes)
-------------------------------------
- Check `TODAY` at the start of your day.
- Resolve or move items to `PROJECTS` / `OFFICE_BOXES` / `CAPTURE_HOLE` as appropriate.
- Run `pwsh ./scripts/check_today_once.ps1 -TodayPath "$HOME/TODAY"` and review `_events.log`.

Why this matters
-----------------
`TODAY` prevents work from being scattered or forgotten. It is a small, enforceable control surface that keeps your attention focused and the system auditable.
