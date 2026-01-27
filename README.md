# VBoard Capture Pipeline

**VBoard Capture Pipeline** is a standalone, auditable “mailroom” pipeline used by VBoarder systems to ingest, snapshot, validate, and route documents before they ever reach agents, RAG, or AI reasoning layers.

This repository is intentionally **minimal, deterministic, and CI-first**.

---

## Purpose

This repo exists to solve one problem extremely well:

> **Safely capture and validate inbound documents before they enter AI workflows.**

It is designed to:

- act as a trusted ingestion boundary
- snapshot inputs immutably
- validate upgrades (Docling, parsers, OCR, etc.)
- prevent silent regressions
- remain independent of UI and agent logic

---

## High-Level Flow

Inbound Files
↓
Mailroom / Capture
↓
Snapshot (immutable JSON)
↓
Validation (CI + local)
↓
Routing → Agents / RAG / Storage

---

## Repository Structure

VBoard-Capture-Pipeline/
├── .github/
│ └── workflows/
│ └── upgrade-validation.yml
├── docs/
│ └── pipeline-overview.md
├── scripts/
│ ├── README.md
│ └── upgrade_validation_check.ps1
├── README.md
└── .gitignore

---

## Design Principles

- **No UI**
- **No agents**
- **No side effects**
- **Everything auditable**
- **CI must fail loudly**
- **Upgrades are intentional, never silent**

---

## CI Philosophy

All upgrades (Docling, parsers, OCR, extraction logic) must:

1. Exist on `main`
2. Be manually dispatchable
3. Produce an artifact
4. Clearly PASS / FAIL / SKIP

No exceptions.

---

## Status

- Repo initialized on **D:** (authoritative)
- CI scaffold present
- Docling integration pending validation

---

## Linux Requirements & Runbook

This repository treats **Linux as a first-class platform** for CI and ops. The runbook below is intentionally minimal, deterministic, and geared for operators.

### Minimum Host Requirements

- Linux (tested) — primary
- Windows (supported) — secondary
- PowerShell Core (`pwsh`) — required for the included automation scripts
- `git`
- Node.js (LTS) and one of: `pnpm` (preferred) or `npm`
- Standard POSIX coreutils (e.g., `cat`, `grep`, `sed`)

### Quick Install (Debian/Ubuntu)

Install PowerShell Core and Node.js, then verify:

```bash
sudo apt update && sudo apt install -y powershell git
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
# pnpm optional
npm install -g pnpm

pwsh --version
git --version
node --version
pnpm --version # if installed
```

### Runbook (First Validation)

1. Clone the repo on the Linux host:
   ```bash
   git clone https://github.com/EDilleHSC/vboard-capture-pipeline.git
   cd vboard-capture-pipeline
   ```
2. Run the upgrade-validation helper (short smoke/ops check):
   ```bash
   pwsh ./scripts/upgrade_validation_check.ps1
   ```
3. Interpret outcomes:
   - **Missing deps**: install per "Minimum Host Requirements" above
   - **Path warnings**: standardize paths (see below)
   - **Hard failures**: attach logs to an upgrade PR and fix before rollout

### Notes on Operations

- Scripts use PID files and PowerShell `Get-Process` for runtime checks. These work under `pwsh` on Linux; validate process detection semantics once and document behavior.
- Path handling: scripts currently mix `\` and `/`. Prefer using `/` on Linux or use PowerShell `Join-Path` for cross-platform robustness.
- Capture Model (Desktop INBOX): treat `~/Desktop/INBOX` as the **Capture Root** (untrusted). Start by **watching only**; do not auto-move files until behavior is trusted. Example directories (optional):
  - `Desktop/INBOX/` (watch-only)
  - `Desktop/INBOX/_snapshots/`
  - `Desktop/INBOX/_quarantine/`
  - `Desktop/INBOX/_processed/`

---

## Next Steps

- Merge upgrade-validation workflow to `main`
- Create versioned upgrade branches
- Trigger CI manually
- Review artifacts before rollout
