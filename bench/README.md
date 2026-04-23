# Benchmark Tools for Entra ID Log Analytics Ingestion

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-04-20
- **Scope:** How-to guide for generating synthetic Entra ID audit log fixtures,
  running the stage-1 ingestion equivalence tests, and running the opt-in
  offline benchmark. Does not cover the real Azure Log Analytics / Entra ID
  ingestion path or production benchmarking.
- **Related:**
  [franklesniak/GloryRole#19](https://github.com/franklesniak/GloryRole/issues/19),
  [franklesniak/GloryRole#23](https://github.com/franklesniak/GloryRole/issues/23),
  [Documentation Writing Style](../.github/instructions/docs.instructions.md)

## What these tools exist for

These tools measure the performance and correctness of the Entra ID Log Analytics
ingestion pipeline (`Get-EntraIdAuditEventFromLogAnalytics` through the stage-1
deduplication, display-name mapping, and aggregation steps) without touching a real
Azure tenant. They exist to produce baseline numbers for
[franklesniak/GloryRole#23](https://github.com/franklesniak/GloryRole/issues/23),
which describes planned semantic and scale improvements to the ingestion path.

## How to generate a fixture

The synthetic fixture generator creates deterministic arrays of `[pscustomobject]`
rows matching the post-KQL-projection shape that
`Get-EntraIdAuditEventFromLogAnalytics` receives from
`Invoke-AzOperationalInsightsQuery.Results`.

```powershell
# Load the fixture generator
. tests/PowerShell/_fixtures/New-SyntheticAuditLogFixture.ps1

# Generate 10,000 rows with 50% retry-duplicates (default parameters)
$arrFixture = @(New-SyntheticAuditLogFixture -Count 10000 -Seed 42)

# Generate a smaller fixture with no duplicates
$arrSmall = @(New-SyntheticAuditLogFixture -Count 500 -DuplicateRatio 0.0 -Seed 42)
```

Key parameters:

- `-Count`: Total rows to emit (default 10000).
- `-DuplicateRatio`: Fraction of rows that are retry-duplicates (default 0.5,
  range 0.0-0.95).
- `-NullCorrelationIdRatio`: Fraction with empty CorrelationId (default 0.02).
- `-UnmappedActivityRatio`: Fraction with unmapped OperationName (default 0.1).
- `-ServicePrincipalRatio`: Fraction initiated by service principals (default 0.2).
- `-Seed`: RNG seed for reproducibility (default 42). Same seed produces
  identical output across all supported PowerShell versions.

## How to run the equivalence tests

### Default (comparison) run

The comparison tests load committed golden baselines from
`tests/PowerShell/_fixtures/golden/` and compare current pipeline outputs against
them. A mismatch means the pipeline behavior has changed.

```powershell
Invoke-Pester -Path tests/PowerShell/Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1 -ExcludeTag Golden -Output Detailed
```

Or run all tests excluding Golden (as CI does):

```powershell
$config = New-PesterConfiguration
$config.Run.Path = "tests/"
$config.Filter.ExcludeTag = 'Golden'
$config.Output.Verbosity = "Detailed"
Invoke-Pester -Configuration $config
```

### Golden regeneration

To regenerate the golden baselines on disk:

```powershell
Invoke-Pester -Path tests/PowerShell/Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1 -Tag Golden -Output Detailed
```

**Important:** Regeneration is only appropriate when the new output is
**intentionally** different (e.g., after a planned semantic change in the
ingestion pipeline). If the comparison tests fail unexpectedly, that is a bug,
not a golden-update trigger. Investigate the root cause before regenerating.

## How to run the benchmark

```powershell
.\bench\Measure-EntraIdLogAnalyticsReduction.ps1 -Label baseline
```

Parameters:

- `-FixtureSize`: Number of synthetic rows (default 10000).
- `-DuplicateRatios`: Array of duplicate ratios to test (default `@(0.0, 0.25, 0.5)`).
- `-Iterations`: Number of timing passes per configuration (default 3).
- `-OutputPath`: Directory for CSV output (default `bench/results/`).
- `-Label`: Label prefix for the output CSV filename (default `'baseline'`).
- `-Seed`: RNG seed (default 42).
- `-Mode`: Opt-in mode selector. One of `Legacy` (default; pre-existing
  behaviour preserved byte-exactly), `Baseline` (no server-side collapse;
  mock filters by chunk time window only), `OptionA` (global `arg_min`
  collapse simulating a single-query Option A path), or `OptionAPlusB`
  (per-chunk `arg_min` collapse; matches current production).

Results are written to `bench/results/{Label}-{yyyymmdd-HHmmss}.csv` and a
Markdown summary table is printed to stdout.

## Reports

- [`docs/benchmarks/issue-23-entra-reduction.md`](../docs/benchmarks/issue-23-entra-reduction.md)
  — retroactive baseline and post-reduction metrics for issue
  [#23](https://github.com/franklesniak/GloryRole/issues/23) with the OQ1
  Pass/Fail table.

## How to produce baseline numbers for issue #23

After this infrastructure merges, follow these steps to produce baseline numbers:

1. Check out the `main` branch:

   ```bash
   git checkout main
   git pull
   ```

2. Run the benchmark with the baseline label:

   ```powershell
   .\bench\Measure-EntraIdLogAnalyticsReduction.ps1 -Label baseline
   ```

3. Copy the Markdown summary table from stdout.

4. Paste the table into a comment on
   [franklesniak/GloryRole#23](https://github.com/franklesniak/GloryRole/issues/23).

5. Include the host information (see Reference-host note below).

## Reference-host note

Wall-clock measurements are host-dependent. When posting benchmark results, document
the host that produced them: operating system, PowerShell version
(`$PSVersionTable.PSVersion`), CPU model, and available RAM. This allows readers to
interpret the numbers in context and reproduce them on comparable hardware.
