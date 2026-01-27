# Agent Box Rules & Flow

This describes the desktop agent boxes, ownership, and a simple flow for how items move (manually) through the system.

Ownership
- Executive_Secretary: MoneyPenny (choke point for uncertainty)
- CTO_Box: CTO / Engineering
- CLO_Box: Chief Legal Officer / Legal team
- COO_Box: Chief Operating Officer / Ops team
- CISO_Box: Security incidents & triage
- Compliance_Box: Compliance & privacy
- DataOps_Box: Parsers, OCR, and RAG staging
- Archive_Cold: Immutable archives (end of life storage)

Flow (manual):
1. Files land in `~/CAPTURE_HOLE` (intake)
2. Operator runs watcher to create a snapshot and events (no file moves by software)
3. Items are manually triaged and placed into one of the agent boxes above
4. Executive_Secretary receives unclear or overflow items
5. Downstream teams pick from their boxes for processing, then snapshot and archive as appropriate

Enforcement
- No automation at desktop layer
- Audit via `_snapshots/` and `_events/`
- Executive_Secretary is the single sink for uncertainty

This is a human-visible terminal design; keep processes simple and auditable.