# Pipeline Overview — VBoard Capture

This document describes the **authoritative ingestion and capture flow** for VBoarder.

---

## 1️⃣ Input Sources (Untrusted)

Inputs entering the system are assumed to be:
- Unstructured
- Messy
- Inconsistent
- Potentially incomplete

Examples:
- PDFs (native or scanned)
- Office documents
- Image files
- Email attachments
- Mailroom drops

No assumptions are made about correctness at this stage.

---

## 2️⃣ Capture Layer (Normalization)

The Capture Layer is responsible for:

- File type detection
- Text extraction
- Layout preservation
- Structural reconstruction
- Metadata capture (pages, bounding boxes, provenance)

**Key rule:**  
> Capture does not interpret meaning — it preserves structure.

---

## 3️⃣ Structure & Validation

Captured content is transformed into:

- Hierarchical document models
- Typed elements (sections, tables, figures, captions)
- Explicit metadata
- Deterministic identifiers

Validation ensures:
- Required fields exist
- Types are correct
- Output matches declared schema

Failures stop the pipeline.

---

## 4️⃣ Chunking & Context Preservation

Validated documents are chunked by:
- Sections
- Tables
- Figures
- Semantic boundaries (not fixed token size)

Each chunk retains:
- Parent context
- Source reference
- Provenance metadata

This enables:
- High-quality RAG
- Explainable answers
- Source linking

---

## 5️⃣ Downstream Consumers

Structured outputs are consumed by:

- RAG pipelines
- AI agents
- Human review tools
- Audit / compliance systems

The Capture Pipeline **does not** execute agents.

---

## 6️⃣ Tooling Strategy (Docling)

Docling is used as a **pluggable capture engine**, providing:
- Multi-format parsing
- Structured document models
- Provenance metadata
- Schema-driven extraction

Docling versions are pinned and validated before use.

---

## 7️⃣ Safety & Governance

- No silent upgrades
- No direct installs on `main`
- CI validation required
- Full traceability from input → output

---

## 📌 Key Takeaway

> **Capture is infrastructure.**
>
> If capture is wrong, everything downstream is wrong — faster.

This pipeline exists to make that impossible.

✅ What to do right now

Paste both files

Commit them