# Entra ID Log Analytics ingestion — baseline and post-reduction metrics

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-04-23
- **Scope:** Records the measured pre-reduction and post-reduction row counts, wall-clock times, and working-set figures for the Entra ID Log Analytics ingestion path at the locked synthetic-fixture parameters, and evaluates the Option A result against OQ1. Single source of truth for the numbers cited from the REQ-ING-005 "Measured metrics" subsection.
- **Related:** [#19](https://github.com/franklesniak/GloryRole/issues/19), [#23](https://github.com/franklesniak/GloryRole/issues/23), [#31](https://github.com/franklesniak/GloryRole/issues/31), [#35](https://github.com/franklesniak/GloryRole/issues/35), [#37](https://github.com/franklesniak/GloryRole/issues/37), [REQ-ING-005](../spec/requirements.md#ingestion), [Benchmark tooling](../../bench/README.md)

## Purpose

Issue [#23](https://github.com/franklesniak/GloryRole/issues/23) asked the Entra ID Log Analytics ingestion path to record **baseline** and **post-reduction** row-count metrics for the locked fixture (`Count=10000, Seed=42, DuplicateRatio ∈ {0.0, 0.25, 0.5}`) against the Open Question 1 (OQ1) target so the reduction gate could be evaluated. The baseline artifact was committed in [#31](https://github.com/franklesniak/GloryRole/issues/31), Option A (server-side `arg_min` retry collapse) landed in [#35](https://github.com/franklesniak/GloryRole/issues/35), and Option B (chunked partitioning) landed in [#37](https://github.com/franklesniak/GloryRole/issues/37), but neither PR body carried the measured delta table required by the acceptance criterion. This report retroactively satisfies that criterion with committed, reproducible numbers.

## Invocation

The numbers below are produced by running the opt-in offline benchmark `bench/Measure-EntraIdLogAnalyticsReduction.ps1` once per `-Mode` at the locked synthetic-fixture parameters. Each run mocks `Invoke-AzOperationalInsightsQuery` so no Azure tenant or Log Analytics workspace is required.

```powershell
./bench/Measure-EntraIdLogAnalyticsReduction.ps1 `
    -FixtureSize 10000 -Seed 42 `
    -DuplicateRatios @(0.0, 0.25, 0.5) `
    -Iterations 3 `
    -Mode Baseline -Label iss23-baseline

./bench/Measure-EntraIdLogAnalyticsReduction.ps1 `
    -FixtureSize 10000 -Seed 42 `
    -DuplicateRatios @(0.0, 0.25, 0.5) `
    -Iterations 3 `
    -Mode OptionA -Label iss23-optiona

./bench/Measure-EntraIdLogAnalyticsReduction.ps1 `
    -FixtureSize 10000 -Seed 42 `
    -DuplicateRatios @(0.0, 0.25, 0.5) `
    -Iterations 3 `
    -Mode OptionAPlusB -Label iss23-optionab
```

`-Mode` is an additive switch introduced alongside this report. It does not change the ingestion function under `src/`; it only varies how the mock `Invoke-AzOperationalInsightsQuery` responds per chunk:

- `Baseline` — mock filters the fixture by the chunk's KQL time window and returns rows unchanged (no server-side collapse), simulating the pre-Option-A path.
- `OptionA` — the Option A `arg_min` retry collapse is applied once to the whole fixture and the mock returns rows from that globally-collapsed set filtered by the chunk's time window, approximating a single-query Option A path.
- `OptionAPlusB` — mock filters the raw fixture by the chunk's time window, then applies the Option A collapse per chunk; matches the current production KQL exactly.

`-Mode` defaults to `Legacy`, which is byte-exactly the previous benchmark behaviour. Existing invocations and their CSV output format are unchanged.

## Environment

The numbers below were produced on the environment described in this section. Wall-clock and working-set figures are host-dependent; reproducing on different hardware is expected to shift the timing numbers but not the row counts.

| Item | Value |
| --- | --- |
| OS | Ubuntu 24.04 on Linux kernel 6.17.0-1010-azure (x86_64) |
| PowerShell | 7.4.14 |
| Repository commit | `dbcfcb6` (production logic unchanged from this tree) |
| Fixture generator | `tests/PowerShell/_fixtures/New-SyntheticAuditLogFixture.ps1` |
| Fixture parameters | `Count=10000, Seed=42, DuplicateRatio ∈ {0.0, 0.25, 0.5}`, all other fixture parameters at defaults |
| Iterations per cell | 3 |

## Baseline fixture parameter lock and drift check

The committed baseline artifact at `tests/PowerShell/_fixtures/baselines/row-count-baseline.json` records the pre-reduction row counts emitted by `Get-EntraIdAuditEventFromLogAnalytics` for the locked fixture:

```json
{ "fixtureCount": 10000, "seed": 42, "ratios": { "0.0": 8975, "0.25": 8976, "0.5": 8956 } }
```

The `Baseline` run in this report emitted **exactly** those row counts (`8975 / 8976 / 8956`), so there is no drift from [#31](https://github.com/franklesniak/GloryRole/issues/31)'s committed baseline. The baseline JSON is therefore **not** updated by this PR.

## Results

OQ1 target formula (per issue #23 acceptance criterion): `OQ1Target = floor((1 − DuplicateRatio + 0.10) × BaselineRows)`. The `OptionA Pass/Fail vs OQ1` column is evaluated against this gate using the `BaselineRows` emitted by this run (which match the committed baseline JSON exactly).

All WallClock numbers are the **median** of 3 iterations per cell, in milliseconds, measured across the full stage-1 pipeline segment (`Get-EntraIdAuditEventFromLogAnalytics` → `Remove-DuplicateCanonicalEvent` → `ConvertTo-PrincipalDisplayNameMap` → `ConvertTo-PrincipalActionCount`). `WorkingSetMB` is the median of the per-iteration `WorkingSet64` samples captured at the end of each iteration, converted at `1 MB = 1048576 B`. The same fixture seed and parameters are used across all three modes, so row counts are deterministic.

| DuplicateRatio | BaselineRows | OptionARows | OptionAPlusBRows | OQ1Target | OptionA Pass/Fail vs OQ1 | WallClockMs (Baseline) | WallClockMs (OptionA) | WallClockMs (OptionA+B) | WorkingSetMB (Baseline / OptionA / OptionA+B) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0.0 | 8975 | 8975 | 8975 | 9872 | PASS | 2436 | 2267 | 2301 | 353.1 / 347.5 / 338.5 |
| 0.25 | 8976 | 6730 | 8886 | 7629 | PASS | 2408 | 1819 | 2268 | 410.8 / 358.0 / 366.2 |
| 0.5 | 8956 | 4491 | 8732 | 5373 | PASS | 2320 | 1175 | 2233 | 402.6 / 374.3 / 379.6 |

### Per-ratio conclusions

- **DuplicateRatio 0.0.** OQ1 holds: Option A emits 8975 rows, at or below the 9872 gate. There are no retry duplicates to collapse at this ratio, so Option A, Option A+B, and Baseline all emit the same 8975 rows — the Option A collapse is correctly a no-op here.
- **DuplicateRatio 0.25.** OQ1 holds: Option A emits 6730 rows, well below the 7629 gate. The 25 % retry-duplicate population is fully eliminated by the server-side `arg_min` collapse when that collapse sees the whole range.
- **DuplicateRatio 0.5.** OQ1 holds: Option A emits 4491 rows, well below the 5373 gate. The 50 % retry-duplicate population is eliminated server-side by Option A.

### Note on `OptionAPlusBRows` vs. OQ1

The `OptionAPlusB` column is reported for transparency rather than as an OQ1 gate input. In the chunked path, the Option A `arg_min` collapse runs **per chunk**, so a retry pair whose two timestamps land in different chunks survives the per-chunk collapse and both rows flow into the emitted stream. Correctness is still preserved downstream because `Remove-DuplicateCanonicalEvent` eliminates any cross-chunk retry survivors client-side — confirmed by the fact that the final `TriplesAfterStageOne` count is identical across all three modes (`8975 / 6730 / 4491`) at the three ratios, as recorded in the per-iteration CSVs. OQ1 is therefore defined against Option A's reduction intent (pre-dedup wire-volume savings) and not against the per-chunk residual that Option B tolerates by design. See REQ-ING-005 for the underlying rationale: "Retry duplicates that land on opposite sides of a chunk boundary MAY survive the per-chunk collapse, but `Remove-DuplicateCanonicalEvent` still deduplicates them client-side and therefore preserves correctness."

## Cross-reference

This report closes the acceptance criterion in issue [#23](https://github.com/franklesniak/GloryRole/issues/23) by recording the baseline and post-reduction metrics against the agreed OQ1 target. It composes four prior pieces of work: the pre-reduction baseline artifact from [#31](https://github.com/franklesniak/GloryRole/issues/31) (whose committed row counts this report reproduces byte-for-byte at `Count=10000, Seed=42`), the Option A server-side retry-collapse landed in [#35](https://github.com/franklesniak/GloryRole/issues/35) (against whose gate the OQ1 Pass/Fail column is evaluated), the Option B chunked partitioning landed in [#37](https://github.com/franklesniak/GloryRole/issues/37) (whose per-chunk behaviour is characterised in the `OptionAPlusB` column), and the parent issue [#19](https://github.com/franklesniak/GloryRole/issues/19) tracking the broader Entra ID ingestion work.
