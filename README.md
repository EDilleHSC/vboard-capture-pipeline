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
│   └── workflows/
│       └── upgrade-validation.yml
├── docs/
│   └── pipeline-overview.md
├── scripts/
│   ├── README.md
│   └── upgrade_validation_check.ps1
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

## Next Steps

- Merge upgrade-validation workflow to `main`
- Create versioned upgrade branches
- Trigger CI manually
- Review artifacts before rollout