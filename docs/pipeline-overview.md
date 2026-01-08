# Pipeline Overview

This document explains how the VBoard Capture Pipeline fits into the larger VBoarder ecosystem.

---

## Why This Exists

AI systems fail most often at the **edges**, not in the models.

This pipeline protects the system by enforcing:
- controlled ingestion
- reproducible snapshots
- upgrade verification
- human-review checkpoints

---

## Core Stages

### 1. Capture (Mailroom)
- Files arrive via watched inbox, API, or sync
- No interpretation occurs here
- Files are treated as untrusted input

### 2. Snapshot
- Directory contents are snapshotted into JSON
- Filenames, sizes, timestamps recorded
- Snapshots are immutable once written

### 3. Validation
- Parsers / extractors are tested against snapshots
- CI verifies:
  - file integrity
  - parser compatibility
  - regression safety
- Results are written as artifacts

### 4. Routing
- Only validated content proceeds
- Routing targets may include:
  - agent inboxes
  - RAG stores
  - archives
  - quarantine

---

## What This Pipeline Does NOT Do

- ❌ No UI rendering
- ❌ No embeddings
- ❌ No agent reasoning
- ❌ No chat logic
- ❌ No model inference (unless explicitly validated)

---

## Upgrade Strategy

All upgrades follow this pattern:

1. Branch created (`upgrade/<tool>-<date>`)
2. CI validates against known snapshots
3. Artifact reviewed
4. Merge only after approval

---

## Trust Boundary

This repo is a **hard trust boundary**.

If something breaks here, it **must fail**.
Silent success is considered a bug.

---

## Key Takeaway

> **Capture is infrastructure.**
>
> If capture is wrong, everything downstream is wrong — faster.