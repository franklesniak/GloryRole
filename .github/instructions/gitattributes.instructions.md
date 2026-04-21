---
applyTo: "**/.gitattributes"
description: "Rules for .gitattributes entries, including line-ending pinning for byte-exact text artifacts."
---

# `.gitattributes` Rules

**Version:** 1.0.20260421.0

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-04-21
- **Scope:** Applies to any `.gitattributes` file in repositories that adopt these instructions, independent of programming language. Governs how committed text artifacts are protected against platform-dependent checkout rewriting.
- **Related:** [Repository Copilot Instructions](../copilot-instructions.md)

## Purpose and Scope

This file defines the normative rule for entries in `.gitattributes` that protect byte-exact text artifacts from platform-dependent line-ending rewriting. It applies to every `.gitattributes` file in any repository that adopts these instructions, regardless of the programming languages used in the repository.

> **Note:** This document uses [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) keywords (**MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, **MAY**) to indicate requirement levels.

## Quick Reference Checklist

- **[All]** Any committed text file whose identity is its exact byte sequence **MUST** be pinned to LF in `.gitattributes` using a path pattern as specific as practical. See [Rule: Pin Byte-Exact Text Artifacts to LF](#rule-pin-byte-exact-text-artifacts-to-lf).

## Rule: Pin Byte-Exact Text Artifacts to LF

Any committed text file whose identity is its exact byte sequence **MUST** be pinned to LF line endings in `.gitattributes` using a pattern as specific as practical to the affected artifact class. Examples of byte-exact artifacts include, but are not limited to:

- Golden or snapshot test baselines
- Expected-output fixtures compared by exact equality
- Files used as hash inputs (for example, inputs to checksum or digest computation)
- Signed payloads or signature verification inputs

The pattern **MUST** be expressed using standard `.gitattributes` syntax with both the `text` and `eol=lf` attributes. The pattern **SHOULD** be as narrow as practical (for example, scoping to a specific directory and extension) so that rules remain intentional and easy to audit.

**Example:**

```gitattributes
tests/**/golden/*.json text eol=lf
```

### Blanket Rules Are Not a Substitute

A blanket rule such as `* text=auto` **MUST NOT** be treated as a substitute for per-path `eol=lf` pinning. `text=auto` lets Git auto-detect text files and normalize to LF in the repository, but it does **not** force LF on Windows checkouts when `core.autocrlf=true` is in effect: Git still applies the working-tree line-ending conversion configured on the host and can rewrite LF to CRLF on checkout. Only explicit `eol=lf` on an artifact path guarantees that the bytes in the working tree match the bytes in the repository on every platform.

## Defaults Shipped by This Template

This template ships a repo-root `.gitattributes` file with LF-pinning defaults for common byte-exact fixture locations:

- `tests/**/golden/**`
- `tests/**/goldens/**`
- `tests/**/snapshots/**`
- `tests/**/__snapshots__/**`
- `tests/**/fixtures/**`
- `testdata/**`

These paths are assumed to contain **text** fixtures. To keep the defaults safe when binary assets are committed under the same directories (for example, `.png` screenshots under `__snapshots__/`), the shipped `.gitattributes` also declassifies a curated list of common binary extensions (images, documents and archives, compiled artifacts, audio and video, fonts) using the `binary` macro so that Git does not apply line-ending conversion to them.

Downstream adopters **MUST** extend these entries whenever they introduce a new byte-exact fixture location that is not already covered (for example, a project-specific `expected/` directory, a `golden_files/` tree, or signed payloads under a custom path). New entries **SHOULD** follow the "as narrow as practical" guidance above. Existing template entries **SHOULD NOT** be removed unless the maintainer has confirmed that no byte-exact comparison exists in the repository that depends on those paths.

### Excluding Binary Files Under Fixture Paths

If a project stores binary assets (for example, `.png` screenshots or `.zip` archives) inside a directory that is pinned to `text eol=lf`, those binaries **MUST** be declassified explicitly so Git does not rewrite them as if they were text. The standard idiom is a later-evaluated pattern that sets Git's built-in `binary` macro. Later patterns override earlier ones per attribute, so the binary override wins over the directory-wide pin:

```gitattributes
tests/**/snapshots/**    text eol=lf
*.png                    binary
*.zip                    binary
```

The shipped `.gitattributes` already declassifies a curated list of common binary extensions. Adopters **SHOULD** extend that list if they commit binary fixtures in formats not covered (for example, custom binary serialization formats, proprietary container formats, or simulator traces stored as opaque blobs). A narrower path-scoped form **MAY** be used (for example, `tests/**/fixtures/*.bin binary`) when a binary extension is project-specific and scoping it globally would be too broad.

## Interaction With Language-Specific Producer/Consumer Rules

The Git-layer rule defined here is necessary but not sufficient for byte-exact stability. Code that produces or compares these artifacts may also require language-specific normalization or read rules, for example:

- Tools that **generate** fixtures **SHOULD** write LF line endings explicitly, rather than relying on the host default.
- Tools that **compare** fixtures **SHOULD** read bytes in a mode that does not perform its own newline translation (for example, binary mode) when the comparison is byte-exact.
- Hashing and signing tools **SHOULD** operate on raw bytes and **MUST NOT** depend on on-disk text normalization.

These language-specific concerns are out of scope for this instructions file; they are addressed in the relevant language instructions (for example, `python.instructions.md`, `powershell.instructions.md`). The Git-layer rule and the producer/consumer rules are complementary: each alone is insufficient, and both are needed for stable byte-exact artifacts across platforms.

## Rationale

Git's end-of-line handling is configurable per host. On Windows, the common default `core.autocrlf=true` rewrites LF to CRLF on checkout and CRLF to LF on commit. For a source file this is usually harmless; for a fixture whose identity is its exact byte sequence (for example, a file hashed into a test oracle), this silent rewriting breaks byte-exact comparisons — hash equality, signature verification, and snapshot diffs will fail on Windows even though the committed bytes are correct.

Per-path `eol=lf` pinning in `.gitattributes` is the durable Git-layer fix because it overrides `core.autocrlf` and any other host-level configuration for the specified paths. Producer-side normalization alone is insufficient: even if a generator writes LF bytes and a comparator reads in binary mode, a Windows checkout with `core.autocrlf=true` will still present CRLF bytes on disk, and any tool that reads the on-disk file (including hashing pipelines that are not explicitly reading in binary mode) will observe the rewritten bytes. Pinning the path to `eol=lf` is what guarantees that the bytes written to the working tree match the bytes stored in the repository, independent of host configuration.
