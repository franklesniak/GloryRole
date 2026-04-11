---
applyTo: "**/*.md"
description: "Documentation standards:  contract-first, traceable, drift-resistant Markdown."
---

# Documentation Writing Style

**Version:** 1.1.20260112.1

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-01-12
- **Scope:** Defines documentation standards for all Markdown files in this repository, including specs, design docs, runbooks, ADRs, and developer documentation. Does not cover code comments or inline documentation in source files.
- **Related:** [Repository Copilot Instructions](../copilot-instructions.md)

## Purpose and Scope

Documentation in this repository is treated as a **first-class engineering artifact**, not an afterthought.  Docs are expected to function as:

- A **contract** (what the system does, does not do, and why)
- A **design record** (how it works, constraints, trade-offs, failure modes)
- A **maintenance tool** (how to safely change and operate it without regressions)

This file governs all Markdown documentation (including `README.md`, `docs/**`, ADRs, runbooks, and release notes).

## Core Principles

- **Contract-first:** State behavior precisely.  Prefer normative language:  **MUST**, **SHOULD**, **MAY**, **MUST NOT**, **SHOULD NOT**.
- **Deterministic and explicit:** Avoid vague words like "simple," "fast," "robust," "soon," "etc." Replace with measurable claims or concrete boundaries.
- **Traceable:** Requirements, design decisions, and implementation details must connect via stable identifiers and links.
- **Drift-resistant:** Docs evolve with code; no "document later" in canonical docs.
- **Explain "why," not just "what":** Capture rationale and trade-offs so future changes can be made safely.

## Documentation Taxonomy

- **Product spec:** `docs/spec/` (requirements + design; the source of truth)
- **Developer docs:** `docs/` (how to build, test, extend)
- **Operational docs / runbooks:** `docs/runbooks/` (diagnosis, remediation, safe operations)
- **Architecture Decision Records (ADRs):** `docs/adr/` (durable decisions)

If you introduce new doc categories, they MUST be added to this taxonomy section.

> **Customize for your project:** The taxonomy categories shown above are recommendations, not requirements. Projects SHOULD update this taxonomy to reflect their actual documentation structure. Categories MAY be added, removed, or renamed as appropriate for the project's needs.

## Canonical Source of Truth

Projects SHOULD define a canonical specification document (e.g., `docs/spec/requirements.md`) that serves as the authoritative reference for system behavior and requirements. If a canonical spec is defined, all other documentation (design docs, runbooks, README, etc.) MUST align with it.

> **Customize for your project:** The location and structure of your canonical specification is project-specific. Common patterns include `docs/spec/requirements.md`, `docs/SPEC.md`, or similar. Choose a location that fits your project's documentation organization and update this guidance accordingly.

## Required Header Block for Non-Trivial Docs

For any document longer than ~30 lines or intended as a durable reference (specs, designs, runbooks, ADRs), include this header near the top:

- **Status:** Draft | Active | Deprecated
- **Owner:** Person or team
- **Last Updated:** YYYY-MM-DD
- **Scope:** What this doc covers (and does not cover)
- **Related:** Links to related docs and relevant requirement IDs / ADR IDs

## Writing Rules

### Clarity and Structure

- Use informative headings that allow skimming.
- Prefer short paragraphs and bullet lists.
- Use tables only when they increase clarity (avoid tables for "pretty formatting").
- Every list of "things" should be complete or explicitly labeled as partial.

### Normative Language

- Use **MUST/SHOULD/MAY** for requirements and guarantees.
- Use **CAN** only for capability, not obligation.
- Label assumptions explicitly as **Assumption:** and keep them testable.

### Examples

- When documenting behavior, include at least one example that shows:
  - Input
  - Output
  - Explanation (why that output is correct)
- For edge cases, include at least one "failure or ambiguous input" example and the expected handling.

### Markdown Conventions

- Use fenced code blocks with language tags.
- Avoid trailing whitespace; keep blank lines truly blank.
- Prefer relative links within the repo (e.g., `docs/spec/requirements.md`).
- Avoid raw URLs in prose; use descriptive link text when possible.

## ADR Standards

ADRs exist to prevent re-litigating decisions.

- File naming pattern: `docs/adr/ADR-0001-short-title.md`
- ADRs MUST include:
  - **Status:** Proposed | Accepted | Superseded | Deprecated
  - **Context**
  - **Decision**
  - **Consequences:** positive and negative
  - **Alternatives Considered**
  - **Date:** YYYY-MM-DD

ADRs MUST be short and specific. If an ADR grows into a design doc, split it.

## Requirements Documentation Standards

> **Customize this section** for your project. The patterns below are recommendations for projects that track formal requirements.

When writing or updating requirements in specification documents:

- Each requirement SHOULD have a stable identifier (example pattern):
  - `PROJ-REQ-001`, `PROJ-REQ-002`, ...
- Each requirement MUST be phrased as a testable statement:
  - "The system MUST …"
- Each requirement entry SHOULD include:
  - **Rationale:** why it exists
  - **Acceptance Criteria:** objective checks (bullets)
  - **Priority:** P0/P1/P2 (or repo standard)
  - **Verification:** how it will be tested (unit/integration/e2e/manual)

Avoid "implementation leakage" in requirements unless the constraint is truly required (e.g., "MUST NOT store secrets at rest").

### Traceability to Implementation

For each non-trivial requirement, maintain a "Traceability" note that points to:

- An ADR (if it drove a durable decision)
- The implementation module/package path
- The primary test file(s)

This can be minimal, but it SHOULD exist for high-priority requirements.

## Design Documentation Standards

Design docs SHOULD be written to survive refactors. They describe architecture and invariants, not incidental code structure.

A design section SHOULD include:

- **Context:** problem statement and why now
- **Goals / Non-Goals:** explicit boundaries
- **Key Constraints:** security, privacy, performance, portability, cost, toolchain
- **System Overview:** components and responsibilities
- **Data Flow:** what moves where, in what format, and why
- **Interfaces and Contracts:** inputs/outputs, error semantics, validation rules
- **Failure Modes:** what can fail, detection, recovery, and user-visible behavior
- **Alternatives Considered:** at least 2 credible alternatives and why rejected
- **Open Questions:** enumerated, each with an owner or next step

Design sections SHOULD reference requirement IDs they satisfy when applicable.

## Runbook Standards

Runbooks MUST optimize for "2 a.m. usability."

- **Symptoms:** what the operator sees
- **Immediate Triage:** safe checks first
- **Diagnostics:** commands/steps with expected output patterns
- **Mitigations:** reversible actions first; call out risks explicitly
- **Escalation:** when to stop and who to contact
- **Postmortem Notes:** what to capture for later analysis

All commands in runbooks MUST be copy/paste safe and must not destroy data without an explicit warning.

## Change Hygiene and "Definition of Done" for Docs

A change is not complete unless docs remain correct.

For any PR/commit that changes externally observable behavior, at least one of the following MUST be updated:

- spec docs (if any contract/behavior/design constraints changed)
- a design doc section (if architecture/invariants changed)
- an ADR (if a durable decision changed)
- a runbook (if operational behavior changed)
- README / developer docs (if onboarding/build/test steps changed)

Before merging, verify:

- No contradictions across docs
- Examples still match actual behavior
- Open questions are either resolved or explicitly tracked

## Prohibited Patterns

- "TODO:  document later" in spec docs (use "Open Question" instead)
- Contradictory statements between the spec and other docs
- Vague guarantees without measurable definitions
- Unowned open questions ("someone should figure out…")

## AI Authorship Expectations

When generating or editing docs:

- Prefer correctness over eloquence.
- Do not invent requirements, interfaces, or behavior.  If unknown, label as **Open Question**.
- Keep language neutral and engineering-focused; avoid marketing tone.
