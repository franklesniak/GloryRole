# Stage-1 golden fixtures

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-04-26
- **Scope:** Documents the on-disk stage-1 golden snapshots under
  `tests/PowerShell/_fixtures/golden/`, the `Golden`-tagged regeneration
  workflow, and the equivalence contract these snapshots support. Does not
  cover the production stage-1 pipeline behavior or the
  `Test-StageOneEquivalence` helper itself.
- **Related:**
  [#23](https://github.com/franklesniak/GloryRole/issues/23),
  [#35](https://github.com/franklesniak/GloryRole/issues/35),
  [#37](https://github.com/franklesniak/GloryRole/issues/37),
  [#39](https://github.com/franklesniak/GloryRole/issues/39),
  [Documentation Writing Style](../../../../.github/instructions/docs.instructions.md)

## Purpose

This folder holds JSON snapshots of the stage-1 output of the Entra ID Log
Analytics ingestion pipeline
([`src/Get-EntraIdAuditEventFromLogAnalytics.ps1`](../../../../src/Get-EntraIdAuditEventFromLogAnalytics.ps1))
run against the deterministic synthetic fixture from
[`New-SyntheticAuditLogFixture.ps1`](../New-SyntheticAuditLogFixture.ps1) (`Count = 500`, `Seed = 42`) at three
duplicate ratios.

| File pattern | Stage-1 output captured |
| --- | --- |
| `dup<ratio>-triples.json` | Sparse `(PrincipalKey, Action, Count)` triples. |
| `dup<ratio>-displaynames.json` | `PrincipalKey` → display-name map. |
| `dup<ratio>-unmapped.json` | Unmapped-activity accumulator (one entry per `(ActivityDisplayName, Category)` group, with `Count`, `SampleCorrelationId`, `SampleRecordId`). |

## Equivalence contract

Per Open Question 2 in #23 (which defines the valid-sample relaxation for
sample IDs), the equivalence contract that the runtime equivalence tests enforce
(via `Test-StageOneEquivalence` in
[`Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1`](../../Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1)) is:

| Field | Check |
| --- | --- |
| Triples (`PrincipalKey`, `Action`, `Count`) | **Strict equality** |
| Display-name map | **Strict equality** |
| Unmapped accumulator `Count` and activity/category keys | **Strict equality** |
| Unmapped accumulator `SampleCorrelationId`, `SampleRecordId` | **Valid-sample**: ID must exist on a fixture row that maps to the same `(ActivityDisplayName, Category)` group. |

The valid-sample relaxation exists because Options A and B (#35, #37 —
server-side deduplication strategies) collapse duplicate audit rows on the
server using `arg_min(TimeGenerated, ...)`, which
deterministically picks a row that is *different from but equivalent to* the
row the legacy per-record path would have picked. Both pick valid sample rows;
they just don't pick the same valid sample row.

## How to regenerate

These goldens are produced by the regeneration tests in
[`Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1`](../../Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1) inside the
`Context "Golden file regeneration"` block, which is tagged `Golden`. Default
CI runs with `-ExcludeTag Golden`, so the regen does **not** run automatically.

To regenerate after a deliberate change to stage-1 behavior:

```powershell
Import-Module Pester -MinimumVersion 5.0
$config = New-PesterConfiguration
$config.Run.Path = 'tests/PowerShell/Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1'
$config.Filter.Tag = 'Golden'
Invoke-Pester -Configuration $config
```

Then review the diffs, confirm they reflect the intended behavior change (and
nothing else), and commit them.

## When you should regenerate

- You intentionally changed stage-1 output shape, KQL semantics, or the
  activity-to-action mapping.
- You added a new invariant to the synthetic-fixture contract.

## When you should NOT regenerate

- An unrelated change caused a diff here. That's a regression — investigate
  before regenerating.
- The non-sample fields (Triples, display-name map, unmapped counts/keys)
  changed unexpectedly. Those are part of the strict-equality contract and
  must not drift silently.

## What runs in default CI vs. what is opt-in

The strict byte-for-byte comparison against these snapshots **does** run in
default CI: the
`Equivalence comparison against goldens for DuplicateRatio …` contexts in
[`Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1`](../../Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1)
read each on-disk JSON file and assert it matches a freshly generated stage-1
output via `Should -Be` (full string equality).

What is excluded from default CI is the **regeneration** that overwrites
these files in place. That work lives inside
`Context "Golden file regeneration" -Tag 'Golden'` and runs only when the
`Golden` tag is selected explicitly (default CI invokes Pester with
`-ExcludeTag Golden`).

The split is deliberate:

- The strict comparison includes `SampleCorrelationId` / `SampleRecordId`. Any
  change to chunking parameters or `arg_min` shape that shifts those values
  surfaces here loudly, so a contributor sees the drift in CI and decides
  whether to accept it via a deliberate regeneration rather than silently
  relax the contract.
- The looser valid-sample relaxation lives in `Test-StageOneEquivalence` and
  is exercised by the runtime-only equivalence contexts (chunked-wrapping,
  adaptive-subdivision, OQ2), which compare two runtime outputs directly
  without the on-disk JSON intermediary. Those tests are what catch real
  regressions when sample IDs shift for a benign reason.

## Related issues / PRs

- #23 — original scalability issue; OQ2 defines the equivalence contract above.
- #29 — synthetic fixture and equivalence test helper.
- #35 — Option A (server-side `arg_min` collapse).
- #37 — Option B (chunked partitioning); first instance of sample-ID drift.
- #39 — recorded the post-reduction metrics.
