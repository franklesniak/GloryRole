---
applyTo: "**/*.py"
description: "Python coding standards:  portability-first by default, modern-advanced when the stack requires it."
---

# Python Writing Style

**Version:** 1.1.20260113.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-01-13
- **Scope:** Defines Python coding standards for all Python files in this repository, including modules, scripts, tests, and tooling. Covers style, structure, error handling, testing, and documentation requirements.
- **Related:** [Repository Copilot Instructions](../copilot-instructions.md)

## Purpose and Scope

This guide establishes the Python coding standards for the repository.  Code **MUST** be maintainable, deterministic, and security-conscious.  The style adapts to project constraints:  **stdlib-first, portability-first** by default, shifting to **modern-advanced** when required by the technology stack (async frameworks, type-heavy APIs, etc.).

> **Note:** This document uses [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) keywords (**MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, **MAY**) to indicate requirement levels.

## Executive Summary:  Author Profile

The default style is a highly disciplined **stdlib-first, portability-first** approach.  When code can reasonably run on a minimal, widely available Python baseline, it **SHOULD**:  minimize dependencies, avoid unnecessary metaprogramming, and prefer clarity over cleverness.

This baseline is not dogma.  When external constraints require modern Python (e.g., `typing`-heavy APIs, async I/O, Pydantic models, FastAPI), the style intentionally shifts to a **modern-advanced** posture.

## Quick Reference Checklist

### Layout and Formatting

- **[All]** **MUST** use 4 spaces; never tabs.
- **[All]** **MUST** follow PEP 8/PEP 257; line length target **<= 100** (**MAY** exceed for URLs/long strings when readability wins).
- **[All]** **MUST** keep formatting tool-friendly: **MUST NOT** hand-align with extra whitespace.
- **[All]** **SHOULD** use f-strings for interpolation; **SHOULD NOT** use `%` or `.format()` formatting except when required.
- **[All]** **MUST NOT** include trailing whitespace; files **MUST** end with a single newline.

### Naming and Structure

- **[All]** **MUST** use `snake_case` for functions/variables; `PascalCase` for classes; `UPPER_SNAKE_CASE` for constants.
- **[All]** Modules **SHOULD** be nouns; functions **SHOULD** be verbs.
- **[All]** **SHOULD NOT** use abbreviations; names **SHOULD** be explicit and descriptive.
- **[All]** **SHOULD** keep functions small and single-purpose; **SHOULD** avoid deep nesting.

### Documentation

- **[All]** Every public module/class/function **MUST** have a docstring.
- **[All]** Docstrings **MUST** emphasize contract:  inputs, outputs, errors, edge cases, examples.
- **[All]** Inline comments **SHOULD** explain "why," not "what."

### Error Handling

- **[All]** **SHOULD** use exceptions over sentinel values unless explicitly modeling "no result."
- **[All]** **MUST** catch narrowly; **MUST NOT** use bare `except:` unless re-raising immediately.
- **[All]** Errors **MUST** be actionable: **MUST** include context, **MUST** preserve original exceptions (`raise ... from e`).

### Types, Testing, and Tooling

- **[Baseline]** **MAY** use type hints opportunistically for public APIs and complex structures.
- **[Modern]** Type hints are expected broadly; **MUST** run static checking (e.g., mypy/pyright) in CI.
- **[All]** Tests **MUST** exist for non-trivial logic; **SHOULD** use `pytest` unless repo standard differs.
- **[All]** **SHOULD** use Black for formatting and Ruff for linting (configured via `pyproject.toml` and pre-commit hooks).

## Baseline vs Modern-Advanced Mode

### Baseline Mode (Default)

Use this mode unless the project's constraints clearly require modern-only features.

**Goals:**

- Minimal dependencies (stdlib-first).
- Deterministic behavior; explicit control flow.
- Easy to read without specialized tooling.

**Rules:**

- **SHOULD** avoid metaprogramming, magic decorators, and clever one-liners.
- **SHOULD** use explicit loops over heavily nested comprehensions when clarity improves.
- **SHOULD** use plain datatypes (`dict`, `list`, `tuple`) over heavy frameworks for simple tasks.
- **SHOULD** keep I/O boundaries obvious (pure functions where possible; isolate side effects).

### Modern-Advanced Mode (When Required)

Use when:

- The repo depends on modern frameworks (FastAPI, Pydantic, async stacks, etc.).
- The domain benefits from stronger contracts (rich types, schemas, validation).
- Performance or concurrency requirements demand modern primitives.

**Rules:**

- **MUST** use type hints pervasively (inputs/outputs, key variables in complex logic).
- **SHOULD** use `pathlib.Path` over `os.path` for paths.
- **SHOULD** use structured logging when available.
- For async:  **SHOULD** use `async`/`await`, `anyio`/`asyncio` patterns; **MUST** keep sync/async boundaries explicit.
- **MAY** raise domain-specific exceptions where helpful.

## Code Layout and Formatting

- Indentation: **MUST** use 4 spaces, no tabs.
- Imports:
  - **MUST** group as:  standard library, third-party, local.
  - Within each group: **SHOULD** sort alphabetically, one import per line when reasonable.
  - **MUST NOT** use wildcard imports.

Example:

```python
from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from pathlib import Path

# import third_party_package  # Third-party imports go here

from myproject.core.models import Requirement
```

## Naming Conventions

- Functions: **SHOULD** use `verb_noun` (e.g., `parse_markdown`, `build_index`, `validate_input`).
- Classes: **SHOULD** use `NounPhrase` (e.g., `RequirementGraph`, `DesignAnalyzer`).
- Variables: **MUST** be explicit, non-abbreviated (e.g., `requirements_text`, not `req_txt`).
- Boolean variables: **SHOULD** use `is_`, `has_`, `should_` prefixes (e.g., `is_valid`, `has_errors`).

## Documentation and Comments

### Docstrings

**MUST** use docstrings for all public interfaces.  **SHOULD** use a consistent, readable style:

- Short summary line.
- Longer description if needed.
- Arguments, returns, raises.
- Examples for tricky behavior.

Example:

```python
def parse_requirements_markdown(markdown_text: str) -> list[str]:
    """
    Parse requirements from a markdown document.

    Args:
        markdown_text: Raw markdown content.

    Returns:
        A list of normalized requirement strings.

    Raises:
        ValueError:  If the markdown is empty or cannot be parsed.
    """
```

### Inline Comments

- **SHOULD** explain rationale and invariants.
- **SHOULD NOT** narrate obvious code.

## Error Handling

- **MUST** raise specific exceptions (`ValueError`, `KeyError`, `TypeError`, or custom domain exceptions).
- **MUST** always add context.  **MUST** preserve the original exception when wrapping:

```python
try:
    parsed = json.loads(text)
except json.JSONDecodeError as error:
    raise ValueError(f"Invalid JSON in requirements file: {path}") from error
```

- **MUST NOT** swallow errors silently.  If you must continue, **MUST** log at `debug` or `warning` with rationale.

## Logging and Output

- **MUST** use `logging` for non-test code.  **MUST NOT** use `print` except in CLI entrypoints.
- Logging messages **MUST** be human-actionable and **SHOULD** include identifiers/paths when relevant.

## Data Modeling

### Baseline

- **SHOULD** use `dataclasses` for lightweight models.
- **SHOULD** avoid "magic" model behavior unless it clearly reduces complexity.

### Modern

- If using Pydantic or similar, **SHOULD** enforce schema boundaries at the edges (I/O) and keep the core logic mostly framework-agnostic.

## Filesystem and Paths

- **SHOULD** use `pathlib.Path`.
- **SHOULD NOT** rely on current working directory; **SHOULD** resolve paths from a clear root (e.g., repo root or config).

## Tests

- Non-trivial logic **MUST** have tests.
- Tests **MUST** be deterministic and **MUST NOT** depend on network unless explicitly marked/integration-only.
- **SHOULD** use table-driven tests for parsing/validation logic.

## Performance and Safety

- **SHOULD** prefer clarity first; optimize only when needed and measured.
- **SHOULD** avoid quadratic algorithms in obvious hot paths (parsers, matchers, large loops).
- **MUST** validate untrusted input at boundaries; **MUST NOT** use `eval`.

## "Done" Definition for Python Changes

A PR/commit is considered complete when:

- **All pre-commit hooks MUST pass** (Black formatting, Ruff linting, trailing whitespace, etc.).
  - **MUST** run `pre-commit run --all-files` locally before pushing.
  - Pre-commit hooks **MAY** modify files (auto-fix formatting/linting). **MUST** always review and commit these changes before pushing.
  - **If pre-commit CI fails:** **MUST** pull the branch, run `pre-commit run --all-files`, commit fixes, and push again.
- Code **MUST** conform to this style guide.
- Public APIs **MUST** have docstrings.
- Errors **MUST** be explicit and actionable.
- Tests **MUST** exist for core logic and pass locally/CI.
- **MUST NOT** include debug prints; logging **SHOULD** be appropriate for runtime visibility.
- All CI checks **MUST** pass.
