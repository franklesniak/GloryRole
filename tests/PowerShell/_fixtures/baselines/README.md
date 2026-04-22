# Committed baselines

## Metadata

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-04-22
- **Scope:** Documents committed baseline artifacts under
  `tests/PowerShell/_fixtures/baselines/` that capture pre-reduction
  behavior of stage-1 pipeline segments. Does not cover the reduction
  work itself or the Phase 2 CI gate implementation.
- **Related:** Issue #23 (Entra ID Log Analytics ingestion reduction),
  [Documentation Writing Style](../../../../.github/instructions/docs.instructions.md)

## Purpose

This directory holds committed baseline artifacts that capture the current
(pre-reduction) behavior of stage-1 pipeline segments for the Phase 2
CI-enforced row-count gate and related reduction work.

## `row-count-baseline.json`

Captures the **pre-reduction baseline** for the Entra ID Log Analytics
ingestion path (`Get-EntraIdAuditEventFromLogAnalytics.ps1`) at the fixed
fixture parameters used by issue #23 Phase 2's CI-enforced row-count gate.

### Shape

```json
{
  "fixtureCount": 10000,
  "seed": 42,
  "ratios": {
    "0.0":  <int baseline_rows at DuplicateRatio 0.0>,
    "0.25": <int baseline_rows at DuplicateRatio 0.25>,
    "0.5":  <int baseline_rows at DuplicateRatio 0.5>
  }
}
```

Each value under `ratios` is the number of events emitted from stage 1 of
the ingestion pipeline (`EventsEmittedFromIngestion` in the benchmark CSV)
on the synthetic fixture produced by `New-SyntheticAuditLogFixture` with
the `fixtureCount` and `seed` recorded above and the named duplicate ratio.

This is the `baseline_rows` value used by the OQ1 row-count gate:

> Option A's emitted-event count from pipeline stage 1 MUST be
> ≤ `(1 − dup_ratio + 0.10) × baseline_rows` for each
> DuplicateRatio ∈ {0.0, 0.25, 0.5}.

### Fixture parameter lock

The committed values in `row-count-baseline.json` are valid **only** for
the following exact fixture parameters:

- `Count = 10000`
- `Seed = 42`
- `DuplicateRatio ∈ {0.0, 0.25, 0.5}`
- All other `New-SyntheticAuditLogFixture` parameters at their defaults

If any of these parameters is changed, both this committed baseline **and**
Phase 2's row-count gate MUST be updated in lockstep. Do not edit the
numbers by hand; regenerate them with the benchmark runner.

### How the numbers were produced

```powershell
pwsh -NoProfile -Command @'
    & ./bench/Measure-EntraIdLogAnalyticsReduction.ps1 `
        -FixtureSize 10000 `
        -DuplicateRatios @(0.0, 0.25, 0.5) `
        -Iterations 1 `
        -Seed 42 `
        -Label phase1-baseline
'@
```

The `EventsEmittedFromIngestion` column from the produced CSV at each
`DuplicateRatio` is what appears in the `ratios` object. The fixture
generator is deterministic for a fixed seed, so these numbers do not
change across runs or hosts.
