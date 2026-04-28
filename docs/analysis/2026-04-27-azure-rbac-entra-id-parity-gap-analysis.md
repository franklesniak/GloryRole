# GloryRole Parity Gap Analysis: Azure RBAC vs. Entra ID

- **Status:** Active
- **Owner:** Repository Maintainers
- **Last Updated:** 2026-04-27
- **Scope:** Analyzes Azure RBAC vs. Entra ID parity gaps across source code, tests, documentation, artifacts, and contributor guidance. This document is an engineering analysis artifact and does not define normative product requirements; normative requirements live in [`docs/spec/requirements.md`](../spec/requirements.md).
- **Related:** [`docs/spec/requirements.md`](../spec/requirements.md), [`.github/instructions/docs.instructions.md`](../../.github/instructions/docs.instructions.md), [`.github/copilot-instructions.md`](../../.github/copilot-instructions.md)
- **Taxonomy:** Developer docs (`docs/`). This file is classified under the existing `docs/` documentation bucket; `docs/analysis/` is used as an organizational subdirectory for analysis documents and is not intended to define a separate top-level taxonomy category.

## Executive Summary

**Breaking changes are absolutely acceptable for this work.** Backward compatibility, deprecation shims, alias periods, and preservation of legacy names are **not** constraints. The repository should prefer the cleanest, most internally consistent design that treats **Azure RBAC** and **Entra ID** as equal first-class peers across source code, tests, documentation, artifacts, public API shape, and contributor guidance.

**Overall verdict: MOSTLY equal, but not yet fully equal.**

The repository has made conscious, deliberate progress toward peer parity. The orchestration layer (`Invoke-RoleMiningPipeline.ps1`) explicitly refuses to default a platform for schema-neutral inputs (`REQ-ROL-004`); both platforms have dedicated source files, test files, sample CSVs, and role-definition generators; the migration note explicitly states *"the previous behavior treated Azure RBAC as the implicit default, which made no principled sense."* These are strong signals of intent.

However, a cluster of residual RBAC-first structural biases remains across **helper defaults, parameter naming, parameter validation, output-artifact naming, sample-file naming, public function names, spec data-contract names, code-branch structure, package metadata, documentation framing, test-coverage depth, ValidateSet category-axis coherence, spec prose framing, and agent-instruction documents**. The most consequential gaps are:

- A schema-neutral CSV importer that silently defaults to Azure RBAC (and can silently corrupt Entra `microsoft.directory/*` actions)
- Unprefixed Azure parameter/function/file/type names paired with explicitly-prefixed Entra equivalents
- An asymmetric validation contract (Entra parameters have `[ValidateRange]`; the Azure triad does not)
- An undocumented retry-architecture asymmetry between the two ingestion adapters
- Shared-pipeline contract tests that are richer in the Azure CSV happy-path than in the Entra CSV happy-path
- Spec design-goal and data-contract naming that frames RBAC as canonical and Entra as the variant
- An `InputMode` surface whose values mix incompatible naming axes (`CSV`, `ActivityLog`, `LogAnalytics`, `EntraId`)
- Agent-instruction documents (`.github/copilot-instructions.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) that do not codify a parity rule, allowing future contributions to regress the convention

### Structural-vs-prose imbalance — the central insight

It is not the case that Entra ID is the visible underdog. By raw word count Entra ID actually gets **more** documentation prose than Azure RBAC across the README, the spec, and the orchestration script. The asymmetry runs the other way: **Azure RBAC occupies the structurally privileged positions** — the unqualified parameter namespace, the unprefixed output filenames, the unqualified `CanonicalAdminEvent` PSTypeName, the DC-1/DG-1 spec slots, the `else`-branch defaults, and the unmarked transport-named `InputMode` slot — while **the Entra path has received the more recent engineering investment** (chunking, equivalence harnesses, golden fixtures, retry/backoff, validation ranges).

Reframed: the Az path is **structurally privileged but engineering-under-invested**; the Entra path is **structurally namespaced as the variant but engineering-better-developed**. Bringing the Az path's engineering bar up to parity (D2 retry, validation, test depth, generalized bench tooling) is itself a parity action, and removing Az's structural privileges (H1–H6, D1, D5) removes the asymmetry. Both directions of work are required.

### Severity summary

| Severity | Findings | Open decisions | Total |
| --- | ---: | ---: | ---: |
| **High** | 7 | 3 (D1, D2, D5) | 10 |
| **Medium** | 18 | 3 (D3, D6, D7) | 21 |
| **Low** | 8 | 0 | 8 |
| **Convention to adopt** | 0 | 1 (D4 — only one defensible answer; record as decision, do not deliberate) | 1 |
| **Total tracked items** | **33** | **7** | **40** |

The lower count relative to a purely enumerative issue list reflects consolidation of closely-related ordering/framing observations into broader actionable findings.

---

## What the repo already does well

These behaviors should be preserved through any remediation:

1. **Top-level schema neutrality is explicit and enforced.** `Invoke-RoleMiningPipeline.ps1` refuses to default for schema-neutral sources (CSV, LogAnalytics): `"RoleSchema is required when InputMode is '{0}'. Pass -RoleSchema 'AzureRbac' or 'EntraId'…"`
2. **The spec codifies neutrality** in `REQ-ROL-004`: *"The tool MUST NOT assume a default platform for schema-neutral inputs."*
3. **The README explains the neutral contract** at the top: `-InputMode` selects the data source; `-RoleSchema` selects the role-definition schema; `-RoleSchema` is required when the source is schema-neutral.
4. **The shared downstream pipeline is genuinely shared.** After ingestion, both providers flow through the same dedup, display-name map, aggregation, quality, prune, read-weighting, TF-IDF, vectorization, clustering, and export stages.
5. **Both platforms have dedicated, parallel implementation artifacts**: `New-AzureRoleDefinitionJson` / `New-EntraIdRoleDefinitionJson`, dedicated test files, sample CSVs, and six `.EXAMPLE` blocks covering all six valid mode×schema combinations.
6. **CI workflows are platform-neutral** — no platform-specific jobs; both paths are covered by the same Pester run.
7. **PR template, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md** are all platform-neutral.
8. **`ConvertTo-NormalizedAction` is explicitly documented as RBAC-only.** The function's RBAC exclusivity is correct; the gap is that its public name is too generic for a provider-specific normalizer.
9. **Historical defaults are already called out honestly.** The migration note explicitly admits that older behavior defaulted toward Azure RBAC.

---

## Test-coverage parity (quantitative)

| Platform | Dedicated test files | Total LOC |
| --- | --- | ---: |
| Azure RBAC (3 files) | `ConvertFrom-AzActivityLogRecord.Tests.ps1`, `Get-AzActivityAdminEvent.Tests.ps1`, `New-AzureRoleDefinitionJson.Tests.ps1` | 970 |
| Entra ID (7 files) | `ConvertFrom-EntraIdAuditRecord.Tests.ps1`, `ConvertTo-EntraIdResourceAction.Tests.ps1`, `Get-EntraIdAuditEvent.Tests.ps1`, `Get-EntraIdAuditEventFromLogAnalytics.Tests.ps1`, `Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1`, `Get-EntraIdRoleDisplayName.Tests.ps1`, `New-EntraIdRoleDefinitionJson.Tests.ps1` | 3 813 |

**Test-file disparity is driven by feature parity, not bias.** Entra has more tests because it has more code paths: LA + Graph adapters, activity-to-action mapping table, role-name helper, equivalence/golden harnesses. The Entra-only golden/equivalence harness (`tests/PowerShell/_fixtures/golden/`, `Equivalence.Tests.ps1`) reflects recent Entra performance work, not Azure neglect.

Three remaining parity issues are identified in the findings:

- **M6**: even where shared pipeline contracts apply, the Entra CSV happy-path context skips assertions the Azure CSV happy-path makes.
- **L8**: ingestion-adapter test depth differs by ~2.3× (9 `It` blocks vs. 21), partly driven by the retry-architecture asymmetry (D2). Once D2 is closed, the residual test-depth gap should be audited.
- **D7 (bench tooling)**: bench/equivalence/golden tooling is currently Entra-only — the *opposite* direction of bias (Entra has tooling RBAC lacks), reflecting recent issue-driven engagement.

## Documentation mention parity (quantitative)

Approximate case-insensitive counts (RBAC ≈ "AzureRBAC|Azure RBAC|RBAC|AzActivity|AzureRole" / Entra ≈ "EntraId|Entra ID|EntraID|Microsoft Entra|Azure AD"):

| File | RBAC mentions | Entra mentions | Notes |
| --- | ---: | ---: | --- |
| `README.md` | 14 | 30 | Entra dominates because of the "Entra ID Log Analytics ingestion" subsection. RBAC has no equivalent subsection. |
| `docs/spec/requirements.md` | 10 | 39 | Entra dominates because of REQ-ING-005's chunking detail. RBAC sub-requirements (e.g., adaptive slicing for `Get-AzActivityLog`) are documented at lower detail. |
| `src/Invoke-RoleMiningPipeline.ps1` | 29 | 101 | Entra parameter triad and unmapped-activity diagnostics inflate the Entra count. |

**Net effect:** Entra ID gets *more prose*, but RBAC gets *more structurally privileged positions* (defaults, unprefixed names, output filenames, DC-1, DG-1, `else` branches, and the unmarked transport-axis ValidateSet slot). Neither side is the visible underdog by word count, but the structural privileges concentrate on RBAC.

---

## Open decisions and detailed closeout plan

The following items require a deliberate decision before implementation. **The recommended logical order to close these is D4 → D1 → D5 → D2 → D6 → D3 → D7**, because D4's naming rule governs the surface form of D1's selector renames and D5's contract renames; D2 has the highest implementation-risk profile and benefits from being analyzed against the rule set already chosen; D3, D6, and D7 are each scoped to one concept and can be closed in any order after D4.

Each entry lists the decision to make, why the answer is not obvious from static inspection alone, what input or research is required, what testing is required, and the default recommendation.

### D4 — Global naming strategy for provider-specific vs shared concepts

**Severity if unresolved: governs every other rename — close first.** This is technically a decision in form but in substance there is only one option compatible with the document's other constraints. It is recorded here so the choice is explicit and so the rule can be cited from the agent-doc parity rule (M15) and the spec conventions section (M18).

**Decision to make:** Establish a repo-wide naming rule so Azure RBAC and Entra ID do not drift back into "unqualified Azure, qualified Entra" conventions.

**Why this is open in name only:** Of the four plausible options below, three are dominated:

1. *Prefix both providers explicitly everywhere provider-specific.* — overshoots; harms shared neutral concepts.
2. *Use neutral names wherever possible, even when implementation is provider-specific.* — actively bad; restates the current bug.
3. *Keep current convention but document it.* — explicitly contradicts the breaking-changes-acceptable constraint.
4. *Hybrid rule:* shared concepts neutral; provider-specific concepts explicitly prefixed `AzureRbac` or `EntraId`. — **only option compatible with H1–H6 and M15.**

**Recommended resolution:** Adopt the **hybrid rule**:

- Shared concepts stay neutral (e.g., `Invoke-RoleMiningPipeline`, `ConvertTo-PrincipalActionCount`, `Get-ClusterActionSet`).
- Provider-specific concepts are explicitly prefixed (`AzureRbac` or `EntraId`).
- Future platforms (AWS IAM, GCP IAM, Active Directory, etc.) follow the same rule.

**Closeout owner tasks:**

1. Approve the rule.
2. Encode it in `.github/copilot-instructions.md`, `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` (see M15 for full text).
3. Apply it consistently across code, tests, docs, metadata, and artifacts during P1.

---

### D1 — Source-mode taxonomy: retain `InputMode`, rename it, or redesign it as `InputSource`

**Severity if unresolved: High.** Public API surface, user-visible parameter name on every invocation, and the source of M11's category-axis incoherence.

**Decision to make:** Determine the long-term shape of the user-facing selector that currently accepts `CSV`, `ActivityLog`, `LogAnalytics`, and `EntraId`.

**Why this is open:** The current values mix incompatible axes:

- `CSV` = file format
- `ActivityLog` = transport/API
- `LogAnalytics` = transport/API
- `EntraId` = platform

This is conceptually inconsistent and subtly privileges Azure by leaving Azure's direct path transport-named while Entra's direct path is platform-named.

Source: [`src/Invoke-RoleMiningPipeline.ps1` (line 255)](../../src/Invoke-RoleMiningPipeline.ps1#L255).

```powershell
[ValidateSet('CSV', 'ActivityLog', 'LogAnalytics', 'EntraId')]
[string]$InputMode,
```

**Options to evaluate:**

1. Keep `InputMode` and current values; document the inconsistency.
2. Keep `InputMode` but rename `EntraId` → `GraphAuditLog` so all values are source/transport-oriented.
3. Rename the parameter to `InputSource` and use source-oriented values: `CSV`, `ActivityLog`, `LogAnalytics`, `GraphAuditLog`.
4. Expand into fully-qualified composite values such as `AzureRbacActivityLog`, `AzureRbacLogAnalytics`, `EntraIdGraphAuditLog`, `EntraIdLogAnalytics`, `Csv`.

**Input required:**

- Product/maintainer preference on whether user ergonomics should optimize for source-oriented naming or fully explicit composite mode names.
- Confirmation whether preserving the conceptual split between "source" and "schema" is desired. Given that breaking changes are acceptable, this is a design choice rather than a compatibility constraint.

**Research required:**

- Review every help block, example, issue template, README section, and test file that references `InputMode`.
- Confirm whether any downstream automation, sample scripts, or docs outside the repo depend on the current value names. This is not a blocker, but it affects migration messaging.

**Testing required:**

- **Synthetic / repo-local testing required:** yes.
  - Update and re-run all tests covering valid source×schema combinations.
  - Add explicit tests for every accepted selector value.
  - Review help output and parameter-binding error messages.
- **Live-environment testing required:** no, unless this redesign is combined with behavior changes in ingestion itself.

**Recommended default resolution:**
Prefer **`InputSource` with source-oriented values** (`CSV`, `ActivityLog`, `LogAnalytics`, `GraphAuditLog`) while preserving `RoleSchema` as the separate schema/output selector. This cleanly preserves the existing good architectural split and removes the mixed-axis vocabulary problem. M11 is closed by this decision.

**Closeout owner tasks:**

1. Decide final parameter name and final accepted values.
2. Update `Invoke-RoleMiningPipeline.ps1`, README, spec, tests, issue templates, and all examples in one atomic change.
3. Add explicit tests for the accepted value set and every valid source×schema combination.

---

### D5 — Canonical data-contract restructuring in code and spec

**Severity if unresolved: High.** PSTypeName values are externally observable from PowerShell consumers and constitute public API surface; the current asymmetry is a public-API parity issue equivalent in kind to H6.

**Decision to make:** Determine how the repo should model canonical event contracts so Azure RBAC is not the unqualified canonical event and Entra the special-case sibling.

**Why this is open:** The current structure uses unqualified `CanonicalAdminEvent` for Azure and qualified `CanonicalEntraIdEvent` for Entra, in both code (PSTypeName values in `src/ConvertFrom-AzActivityLogRecord.ps1`, `src/Get-AzActivityAdminEvent.ps1`, `src/ConvertTo-PrincipalActionCount.ps1`) and spec (DC-1 vs DC-6 in `docs/spec/requirements.md`). This is structurally asymmetric.

**Options to evaluate:**

1. Leave the names as-is; clarify the docs only.
2. Rename Azure explicitly to `CanonicalAzureRbacAdminEvent` and keep separate sibling concrete contracts.
3. Introduce a neutral umbrella abstraction plus two provider-specific concrete contracts.
4. Collapse both into one universal canonical event type.

**Input required:**

- Maintainer preference on whether to keep sibling concrete contracts or introduce a more abstract top-level model.
- Confirmation whether PSTypeName stability matters for any external consumer. Since breaking changes are acceptable, this is likely low risk, but it should still be confirmed.

**Research required:**

- Review all test assertions and code that inspect `PSTypeName` directly.
- Confirm whether any serialization or formatting logic depends on the existing type names.

**Testing required:**

- **Synthetic / repo-local testing required:** yes.
  - Update tests expecting `CanonicalAdminEvent`.
  - Validate dedup/aggregation logic still treats both event shapes correctly.
- **Live-environment testing required:** no.

**Recommended default resolution:**
Rename Azure explicitly and keep **two sibling provider-specific concrete contracts** (`CanonicalAzureRbacAdminEvent` and `CanonicalEntraIdEvent`). Renumber the spec contracts so the two canonical-event contracts sit adjacent: DC-1 Azure RBAC Admin Event, DC-2 Entra ID Event, then the shared contracts (Sparse Triple, Vector Row, K-Means Result, Auto-K Result). Update internal cross-references.

**Closeout owner tasks:**

1. Rename the Azure contract and its PSTypeName.
2. Reorganize spec contract ordering so the two canonical-event contracts sit adjacent.
3. Update tests and any code relying on the old type name.

---

### D2 — Retry / backoff parity between Azure Activity Log and Entra Graph ingestion

**Severity if unresolved: High.** Operational resilience is a user-visible product attribute. The current state is under-specified and potentially under-engineered on the Azure side.

**Decision to make:** Determine whether Azure Activity Log ingestion should gain retry/backoff behavior comparable to Entra Graph ingestion, or whether the asymmetry is acceptable and should be explicitly documented.

**Why this is open:** `Get-EntraIdAuditEvent.ps1` implements explicit retry/backoff with exponential backoff, jitter, retry-status classification, and configurable `-MaxRetries` (default 3) / `-RetryBaseDelaySeconds` (default 2). `Get-AzActivityAdminEvent.ps1` does not currently expose an equivalent retry model — failed time segments are skipped with `Write-Warning`, and subscription context-switch failures are skipped with `Write-Error`:

Source: [`src/Get-AzActivityAdminEvent.ps1` (lines 145-151)](../../src/Get-AzActivityAdminEvent.ps1#L145-L151).

```powershell
} catch {
    Write-Debug ("Get-AzActivityLog query failed: {0}" -f $_.Exception.Message)
    Write-Warning ("Failed to query activity log for segment {0} to {1}: {2}" -f $objSegment.S, $objSegment.E, $_.Exception.Message)
    continue
} finally {
    $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
}
```

The disparity is reflected in test coverage: ~2 retry-adjacent tests on the Az side vs. ~8 retry/backoff-specific tests on the Entra side. The disparity may be defensible (Graph API is throttle-prone; subscription-per-slice Activity Log is more tolerant, and Az cmdlets may already retry internally), but the spec is silent.

**Options to evaluate:**

1. Keep the asymmetry and document it clearly in the spec and code comments.
2. Add equivalent retry/backoff knobs and semantics to the Azure Activity Log path.
3. Add a simpler Azure retry layer for transient failures without trying to make it behaviorally identical to the Entra path.
4. Introduce a shared retry policy helper and use it in both paths where technically appropriate.

**Input required:**

- Maintainer preference on whether "equal treatment" means "identical operational resilience features where feasible" or "documented asymmetry when APIs differ materially."
- Tolerance for introducing more complex error-handling logic into the Azure path.

**Research required (this decision is the only one that requires deeper code analysis before implementation):**

- **Code analysis required:** yes.
  - Read `Get-AzActivityAdminEvent.ps1` in detail to identify exact failure paths, partial-failure behavior, segment skipping behavior, and whether duplicate collection risks arise under retries.
  - Review Az cmdlet behavior to determine whether transient failures are already retried internally or surfaced in a way that makes outer retries useful.
- **Testing strategy analysis required:** yes.
  - Decide whether mocked transient failures are sufficient or whether live-environment validation is necessary to understand `Get-AzActivityLog` behavior under throttling/network interruption.

**Testing required:**

- **Synthetic / mocked testing required:** yes.
  - Add Pester tests that simulate transient failures and confirm the retry semantics.
- **Live-environment testing recommended:** **yes.**
  - Validate behavior against a real Azure context for representative failure classes if Azure retry behavior is added or materially changed.
  - Reason: mocked tests alone may not reveal whether Az modules already retry internally or how partial slices behave under real failures.

**Recommended default resolution:**
**Default to implementing equivalent Azure retry semantics** (option 2 or option 4) **unless code analysis reveals a duplicate-window or partial-state ambiguity that retries would amplify.** If code analysis shows such a risk, fall back to option 1 with explicit spec and code commentary justifying the asymmetry. Mocked-only testing is *not* sufficient for this decision; a live-environment validation pass should accompany any code change in `Get-AzActivityAdminEvent.ps1`.

**Closeout owner tasks:**

1. Audit `Get-AzActivityAdminEvent.ps1` failure paths.
2. Decide whether Azure retry semantics are worthwhile and safe.
3. If implementing retries, add both mocked and live validation.
4. If not implementing, add explicit spec and code commentary justifying the asymmetry.

---

### D6 — `Resolve-PrincipalKey` disposition

**Severity if unresolved: Medium.** Public exported function in `GloryRole.psd1`'s `FunctionsToExport`; an Azure-specific helper wearing a generic name is the same kind of bug as H6 but at lower public-surface impact.

**Decision to make:** Determine whether `Resolve-PrincipalKey` is actually a provider-specific Azure helper wearing a generic name, and if so, whether it should be renamed, split, or replaced.

**Why this is open:** The docstring and examples strongly suggest Azure Activity semantics (Azure AD object-id claim resolution), while Entra principal resolution lives separately in `ConvertFrom-EntraIdAuditRecord`. The function should not be changed on assumption alone; the function body and call sites must confirm whether it is conceptually Azure-specific or merely documented that way. **This is the only finding flagged with a verify-before-acting caveat.**

**Options to evaluate:**

1. Keep the function name and fix only the docs.
2. Rename it to an Azure-specific helper.
3. Split principal resolution into sibling provider-specific resolvers under a shared conceptual model.
4. Replace both with a single schema-aware resolver.

**Input required:**

- Maintainer preference on whether principal resolution should remain inline in adapters or be extracted into explicit provider-specific helpers.

**Research required:**

- **Code analysis required:** yes.
  - Inspect the function body and every call site.
  - Confirm whether it is used only by Azure Activity Log paths or whether it has broader utility.

**Testing required:**

- **Synthetic / repo-local testing required:** yes, after any change.
- **Live-environment testing required:** no.

**Recommended default resolution:**
Do **not** act until code analysis confirms the actual role of the helper. If it is Azure-specific, prefer explicit sibling provider-specific resolvers (e.g., `Resolve-AzureRbacActivityPrincipalKey` and `Resolve-EntraAuditPrincipalKey`) rather than one overloaded schema-aware function.

**Closeout owner tasks:**

1. Analyze the function body and call graph.
2. Decide whether rename-only or split-by-provider is warranted.
3. Implement only after the role is confirmed.

---

### D3 — Azure role display-name parity

**Severity if unresolved: Medium.** Real UX parity gap, not a correctness blocker. Entra clusters get descriptive role names (`"GloryRole-User & Group Manager-0"`); Azure clusters get cluster-number-only names (`"GloryRole-Cluster-0"`).

**Decision to make:** Determine whether Azure RBAC output should gain a descriptive role-name generator parallel to `Get-EntraIdRoleDisplayName`.

**Why this is open:** Entra output currently receives richer role naming via `Get-EntraIdRoleDisplayName.ps1`. Azure RBAC role names are generated by simple inline format string in `Invoke-RoleMiningPipeline.ps1` (`"{0}-{1}" -f $RoleNamePrefix, $objCluster.ClusterId`), producing generic names. There is no equivalent that analyzes `Microsoft.Compute/`, `Microsoft.Storage/` action namespaces. This is a real UX parity gap, but it is not a correctness blocker. Multiple legitimate resolutions exist.

**Options to evaluate:**

1. Keep Azure names generic and document that descriptive naming is Entra-only.
2. Add `Get-AzureRbacRoleDisplayName` with Azure provider namespace heuristics.
3. Replace both with a unified schema-aware `Get-RoleDisplayName` that dispatches by schema.
4. Simplify both schemas to generic cluster-number naming only.

**Input required:**

- Maintainer preference on whether parity means matching feature richness or simply removing structural favoritism.
- Naming-style preference: schema-specific helpers or one schema-aware abstraction.

**Research required:**

- Review the current `Get-EntraIdRoleDisplayName` heuristics and assess whether equivalent Azure namespace heuristics would produce stable, useful names.
- Decide whether Azure action namespaces (`Microsoft.Compute/*`, `Microsoft.Storage/*`, etc.) are rich enough to support meaningful descriptive naming without frequent false precision.

**Testing required:**

- **Synthetic / repo-local testing required:** yes.
  - Unit tests for representative Azure action sets.
- **Live-environment testing required:** no.

**Recommended default resolution:**
Prefer a **unified schema-aware display-name abstraction** (`Get-RoleDisplayName`) or, second best, add a dedicated `Get-AzureRbacRoleDisplayName`. If implementation time is constrained, this can follow the higher-priority structural fixes.

**Closeout owner tasks:**

1. Decide whether feature parity here is in scope now.
2. If yes, design heuristics and unit tests.
3. Update the export branch in `Invoke-RoleMiningPipeline.ps1`.

---

### D7 — Benchmark and advanced fixture/tooling parity

**Severity if unresolved: Medium.** This is an asymmetry of investment, not structural favoritism, and currently runs in the *opposite* direction from the other parity gaps (Entra has tooling RBAC lacks).

**Decision to make:** Determine whether benchmark and advanced equivalence/golden tooling should be made symmetric across Azure RBAC and Entra ID, or whether current asymmetry should simply be documented as issue-driven.

**Why this is open:** The richer benchmark/equivalence harness currently exists on the Entra side because of recent Entra-specific ingestion optimization work (issue #23 chunking and reduction work). This is an asymmetry of investment, but not necessarily evidence of structural favoritism. Currently includes `bench/Measure-EntraIdLogAnalyticsReduction.ps1`, `bench/README.md`, `docs/benchmarks/issue-23-entra-reduction.md`, and the equivalence/golden harnesses.

**Options to evaluate:**

1. Leave the tooling as-is and document that the asymmetry is issue-driven, not hierarchical.
2. Add Azure-specific sibling benchmark/equivalence tooling.
3. Generalize the benchmark/equivalence framework across providers (`-Platform AzureRbac|EntraId`).
4. Reduce emphasis on the Entra-specific benchmark tooling in docs.

**Input required:**

- Maintainer preference on whether full tooling symmetry is a current goal or a future investment.
- Appetite for building generalized benchmark abstractions now.

**Research required:**

- Review whether Azure Activity / Azure Log Analytics ingestion has comparable benchmark questions that would benefit from the same infrastructure.
- Decide whether benchmarking belongs to the product contract or remains issue-specific engineering scaffolding.

**Testing required:**

- **Synthetic / repo-local testing required:** yes, if new tooling is added.
- **Live-environment testing required:** not necessarily; synthetic fixtures are likely sufficient for structural tooling parity.

**Recommended default resolution:**
In the near term, document that current tooling asymmetry is **issue-driven** and not evidence of platform preference. If long-term symmetry is desired, prefer a generalized framework over one-off duplicate tooling.

**Closeout owner tasks:**

1. Decide whether tooling symmetry is in scope now.
2. If not, document the rationale.
3. If yes, choose between parallel Azure tooling and generalized multi-provider tooling.

---

## Findings

> Permalinks use `main`. Substitute `https://github.com/franklesniak/GloryRole/blob/main/<path>#L<lines>` to link any `path:Lstart-Lend` reference.

### High severity (functional correctness risk, public API / output-shape parity blocker, or structural privilege with user-visible consequences)

#### H1 — `Import-PrincipalActionCountFromCsv` defaults `-RoleSchema` to `'AzureRbac'`

**File:** `src/Import-PrincipalActionCountFromCsv.ps1:81–82`

Source: [`src/Import-PrincipalActionCountFromCsv.ps1` (lines 81-82)](../../src/Import-PrincipalActionCountFromCsv.ps1#L81-L82).

```powershell
[ValidateSet('AzureRbac', 'EntraId')]
[string]$RoleSchema = 'AzureRbac'
```

A public exported function silently defaults to Azure RBAC when called directly, lower-casing actions via `ConvertTo-NormalizedAction` — which **destroys** Entra `microsoft.directory/*` camelCase (e.g., `oAuth2PermissionGrants` → `oauth2permissiongrants`) and produces invalid Graph role JSON. The orchestrator forces explicit choice; the underlying helper does not. The `.PARAMETER` doc compounds this by explicitly framing the default as *"preserves the historical behavior."*

The test file `tests/PowerShell/Import-PrincipalActionCountFromCsv.Tests.ps1:152–195` locks this in with a `"When -RoleSchema default is used (AzureRbac)"` context, including a test (line 179) showing camelCase destruction.

**Why this is high severity:** Both a parity problem and a correctness risk. A schema-neutral helper should not silently choose Azure RBAC, especially when the wrong choice silently corrupts the other platform's data.

**Fix:** Make `-RoleSchema` mandatory (drop the default). Update the `.EXAMPLE` block at lines 31–37 (currently omits `-RoleSchema`), the `.PARAMETER` description ("preserves the historical behavior" language), and replace the existing default-tests with explicit-schema-required tests.

---

#### H2 — `[ValidateRange]` exists for the Entra parameter triad but not the Azure triad

**File:** `src/Invoke-RoleMiningPipeline.ps1:270–272` vs `279–286`

Source: [`src/Invoke-RoleMiningPipeline.ps1` (lines 270-286)](../../src/Invoke-RoleMiningPipeline.ps1#L270-L286).

```powershell
# Azure (no validation)
[int]$InitialSliceHours = 24,
[int]$MinSliceMinutes = 15,
[int]$MaxRecordHint = 5000,

# Entra (validated)
[ValidateRange(1, 168)]
[int]$EntraIdInitialSliceHours = 24,

[ValidateRange(1, 1440)]
[int]$EntraIdMinSliceMinutes = 15,

[ValidateRange(1000, 500000)]
[int]$EntraIdMaxRecordHint = 450000,
```

Callers can pass `$InitialSliceHours = 0` or `$MaxRecordHint = -1` for the Azure path with no parameter-binding error; the same nonsensical values on the Entra path throw immediately. The spec (`requirements.md:193–195`) specifies the Entra constraints but is silent on the Azure equivalents. This is a concrete capability gap, not just cosmetic.

**Why this is high severity:** This is a user-visible capability gap. One platform gets hard parameter validation; the other relies on downstream behavior.

**Fix:** Add `[ValidateRange]` to the Azure triad with parity ranges (or document the deliberate divergence in the spec).

---

#### H3 — Output artifact filenames structurally privilege Azure RBAC

**Files:** `src/Invoke-RoleMiningPipeline.ps1:870, 888`; `docs/spec/requirements.md:359–364`; `README.md:138–139`

Azure RBAC role files take the unmarked filename; Entra files are namespaced:

Source: [`README.md` (lines 138-139, excerpt)](../../README.md#L138-L139).

```text
| `role_cluster_<id>.json`        | One Azure custom role definition per cluster (when `-RoleSchema AzureRbac`) |
| `entra_role_cluster_<id>.json`  | One Entra ID custom role definition per cluster (when `-RoleSchema EntraId`) |
```

This re-installs RBAC as the "default" platform in the on-disk layout users see. Adding a third platform later (e.g., AWS) would produce three asymmetric naming patterns.

**Why this is high severity:** Output artifacts are user-visible product surface. The current naming encodes Azure as the default platform.

**Fix:** Rename to symmetric provider-qualified filenames:

- `azure_rbac_role_cluster_<id>.json`
- `entra_id_role_cluster_<id>.json`

(Or fully neutral `role_<schema>_cluster_<id>.json`.) Update the orchestrator, spec, README, and tests (`Invoke-RoleMiningPipeline.Tests.ps1`, `New-AzureRoleDefinitionJson.Tests.ps1`).

---

#### H4 — Sample CSV naming structurally privileges Azure RBAC

**Files:** `samples/principal_action_counts.csv`, `samples/entra_id_principal_action_counts.csv`; referenced at `README.md:48, 54`

The RBAC sample is unqualified; the Entra sample is explicitly qualified. Same pattern as H3 — RBAC takes the unmarked default slot.

**Why this is high severity:** Samples are part of the user-facing mental model. The current pattern teaches that Azure is the default sample and Entra is the variant.

**Fix:** Rename the RBAC sample to `samples/azure_rbac_principal_action_counts.csv`. Update README, the test fixture path `$script:strCsvPath`, and any other references.

---

#### H5 — Provider-specific parameter naming is asymmetric

**File:** `src/Invoke-RoleMiningPipeline.ps1:267–286, 277, 305`

Two distinct asymmetries:

Source: [`src/Invoke-RoleMiningPipeline.ps1` (lines 267-305)](../../src/Invoke-RoleMiningPipeline.ps1#L267-L305).

```powershell
# Azure adaptive-slicing triad — UNPREFIXED
[int]$InitialSliceHours = 24,
[int]$MinSliceMinutes = 15,
[int]$MaxRecordHint = 5000,
...
# Entra equivalents — explicitly EntraId-prefixed
[int]$EntraIdInitialSliceHours = 24,
[int]$EntraIdMinSliceMinutes = 15,
[int]$EntraIdMaxRecordHint = 450000,
...
# Role-name prefix asymmetry
[string]$EntraIdRoleNamePrefix = 'GloryRole'         # platform-prefixed name, plain default
[string]$RoleNamePrefix = 'GloryRole-Cluster'        # generic name, suffix-laden default
```

The asymmetry is documented in `README.md:127` and `docs/spec/requirements.md:197–210` on grounds of differing API limits, but that justifies *distinct* names — not RBAC-unmarked.

**Why this is high severity:** The unqualified namespace belongs to Azure while Entra is explicitly namespaced. This is a recurring structural pattern and part of the public CLI surface.

**Fix:** Apply explicit provider prefixing to all four affected parameters:

- `-RoleNamePrefix` → `-AzureRbacRoleNamePrefix`
- `-InitialSliceHours` → `-AzureRbacInitialSliceHours`
- `-MinSliceMinutes` → `-AzureRbacMinSliceMinutes`
- `-MaxRecordHint` → `-AzureRbacMaxRecordHint`

Harmonize defaults so both produce the same naming shape; per-platform suffix logic should be the only divergence. Combine with H2 to add `[ValidateRange]` to the renamed Azure triad. Update `Get-AzActivityAdminEvent.ps1`, the spec, and the README.

---

#### H6 — Public provider-specific function names are asymmetric and Azure occupies the generic namespace

**Files:** `src/New-AzureRoleDefinitionJson.ps1:3`; `src/ConvertTo-NormalizedAction.ps1:3–22, 41–46`

"Azure" alone is ambiguous — Entra ID *is* an Azure service. `New-AzureRoleDefinitionJson` generates the **Azure RBAC** schema specifically; the Entra cousin is precisely named (`New-EntraIdRoleDefinitionJson`).

`ConvertTo-NormalizedAction` carries an explicit warning *"Azure RBAC only: …MUST NOT be used for Entra ID `microsoft.directory/*` actions"* — yet its public name claims to be **the** action normalizer:

Source: [`src/ConvertTo-NormalizedAction.ps1` (lines 13-22)](../../src/ConvertTo-NormalizedAction.ps1#L13-L22).

```powershell
# WARNING - Azure RBAC only: This function applies culture-invariant
# lowercasing and MUST NOT be used for Entra ID
# microsoft.directory/* actions. Entra ID resource action strings
# contain camelCase segments (e.g., oAuth2PermissionGrants,
# servicePrincipals, conditionalAccessPolicies) that the Microsoft
# Graph unifiedRoleDefinition API requires to be preserved exactly.
```

A consumer searching the API surface for "how do I normalize an action?" finds only a function that silently corrupts Entra IDs.

**Why this is high severity:** These are exported public functions. Ambiguous generic names in the Azure path paired with explicit Entra names reproduce Azure-as-default semantics in the module API.

**Fix:**

- Rename `New-AzureRoleDefinitionJson` → `New-AzureRbacRoleDefinitionJson`.
- Rename `ConvertTo-NormalizedAction` → `ConvertTo-NormalizedAzureRbacAction`.
- Create the parallel `ConvertTo-NormalizedEntraIdAction` (currently inlined in `Import-PrincipalActionCountFromCsv.ps1:107`).
- Update `src/GloryRole.psd1:42`, `src/Invoke-RoleMiningPipeline.ps1:886`, and tests.

---

#### H7 — Shared-pipeline contract testing is richer in the Azure CSV happy-path than in the Entra CSV happy-path

**File:** `tests/PowerShell/Invoke-RoleMiningPipeline.Tests.ps1`

The Azure RBAC CSV context (lines 25–121) has 9–11 `It` blocks asserting: non-null result, five-property contract, `RecommendedK` integer type, `OutputPath`, presence of all six output artifacts (`principal_action_counts.csv`, `features.txt`, `quality.json`, `autoK_candidates.csv`, `clusters.json`, plus `role_cluster_*.json`), and `ClusterActions.Principals` array shape.

The Entra CSV context (lines 430–537) has only 3–4 `It` blocks: non-null result, `entra_role_cluster_*.json` exists, no `role_cluster_*.json` files, plus camelCase preservation. Missing parallel assertions: five-property contract, `RecommendedK` type, `OutputPath`, `features.txt`, `quality.json`, `autoK_candidates.csv`, `clusters.json`, `ClusterActions.Principals`.

**Why this is high severity:** These are not Entra-specific concerns — they verify the **shared pipeline contract** that should hold equally for both schemas. The Entra path could regress on any of these and the tests would not catch it.

**Fix:** Expand the Entra context with the missing parallel assertions.

---

### Medium severity (naming asymmetry, spec/doc framing, inconsistent API taxonomy, missing test symmetry)

#### M1 — Adapter naming uses asymmetric prefixes: `Az…` (RBAC) vs `EntraId…` (Entra)

**Files:** `src/Get-AzActivityAdminEvent.ps1`, `src/ConvertFrom-AzActivityLogRecord.ps1` vs `src/Get-EntraIdAuditEvent.ps1`, `src/ConvertFrom-EntraIdAuditRecord.ps1`, `src/Get-EntraIdAuditEventFromLogAnalytics.ps1`

`Az` is the prefix of the `Microsoft.PowerShell.Az.*` module — reusing it as a stand-in for "Azure RBAC" makes the RBAC prefix look like a generic "we use the Az module" tag while Entra is platform-explicit.

**Fix:** Rename `Get-AzActivityAdminEvent` → `Get-AzureRbacActivityAdminEvent` and `ConvertFrom-AzActivityLogRecord` → `ConvertFrom-AzureRbacActivityLogRecord`. Update `GloryRole.psd1:16, 28`, the orchestrator, and tests. Subject to the repo-wide naming rule chosen in D4.

---

#### M2 — `Resolve-PrincipalKey` is potentially Azure-Activity-specific behind a generic name

**File:** `src/Resolve-PrincipalKey.ps1:7–18`

The header documents Azure AD object-id semantics (`"The object identifier claim from Azure AD (for human users)"`), and Entra principal resolution is implemented separately inside `ConvertFrom-EntraIdAuditRecord`. The unqualified name implies a universal principal resolver that does not exist.

**Fix:** Close out Decision D6 first. *Verify before renaming:* confirm the function is genuinely Azure-Activity-specific in its body, not just in its docstring. If Entra paths actually reuse it, this finding is a false positive and should be downgraded to a docstring fix. If confirmed Azure-specific, rename to `Resolve-AzureRbacActivityPrincipalKey` and surface the Entra equivalent as a sibling helper.

---

#### M3 — Provider-specific knobs are not modeled with a clearly articulated policy

**File:** `src/Invoke-RoleMiningPipeline.ps1:81–87`

`EntraIdFilterCategory` has no Azure sibling. Not every provider needs identical knobs, but if one gets explicit surfaced controls and the other gets implicit behavior, the UX reads asymmetrically.

**Fix:** Add a brief policy statement in the spec and contributor guidance: provider-specific ingestion parameters may exist where source APIs differ, but they must use explicit provider naming and documented rationale.

---

#### M4 — The Log Analytics branch uses RBAC as the unnamed fallback path

**File:** `src/Invoke-RoleMiningPipeline.ps1:489–528`

Source: [`src/Invoke-RoleMiningPipeline.ps1` (lines 489-528)](../../src/Invoke-RoleMiningPipeline.ps1#L489-L528).

```powershell
if ($RoleSchema -eq 'EntraId') {
    # ...Entra branch...
} else {
    # ...Azure RBAC branch (the unnamed default)...
}
```

Functionally fine because `[ValidateSet]` prevents other values, but it visually privileges RBAC as the "default."

**Fix:** Rewrite as `switch ($RoleSchema) { 'AzureRbac' { ... } 'EntraId' { ... } }` — both arms named, neither is fallback.

---

#### M5 — Pipeline error-message branch uses the same RBAC-as-fallback pattern

**File:** `src/Invoke-RoleMiningPipeline.ps1:574–589`

The `LogAnalytics` arm of `switch ($InputMode)` uses the `if ($RoleSchema -eq 'EntraId') { ... } else { ...AzureRbac... }` pattern. Same `switch` rewrite as M4.

---

#### M6 — Spec design goal DG-1 named "RBAC fidelity"

**File:** `docs/spec/requirements.md:19–23`

> **DG-1 — RBAC fidelity:** Actions MUST be derived from `Authorization.Action`… Entra ID actions MUST be derived from directory audit activity display names…

The headline name picks one platform; Entra is a parenthetical inside the same bullet. There is no `DG — Entra ID fidelity` peer.

**Fix:** Rename DG-1 to "Action fidelity" and either expand the body to give both platforms equal prominence, or split into `DG-1a` (Azure RBAC action fidelity) and `DG-1b` (Entra ID action fidelity) at equal standing.

---

#### M7 — Spec REQ-CAN-001 / REQ-CAN-002 describe Azure RBAC behavior as universal

**File:** `docs/spec/requirements.md:256–262`

> REQ-CAN-001: Actions MUST be normalized to lowercase with whitespace trimmed.
> REQ-CAN-002: Principal keys MUST follow the precedence: ObjectId > AppId > Caller.

But `ConvertTo-NormalizedAction.ps1:9–20` explicitly forbids lowercasing Entra `microsoft.directory/*` actions, and Entra principal resolution lives in a different code path. The "universal" requirements are actually Azure-specific.

**Fix:** Split into provider-specific requirements (`REQ-CAN-AZ-*` / `REQ-CAN-ENTRA-*`) or rewrite each requirement with provider-specific clauses.

---

#### M8 — Spec data-contract ordering treats Azure as primary and Entra as the appended variant

**File:** `docs/spec/requirements.md:44–118`

DC-1 (Azure) is unmarked; DC-2/3/4/5 are neutral; DC-6 (Entra) is appended last as if retrofitted.

**Fix:** Reorder so the two canonical-event contracts sit adjacent: DC-1 Azure RBAC Admin Event, DC-2 Entra ID Event, then the shared contracts (Sparse Triple, Vector Row, K-Means Result, Auto-K Result). Update internal cross-references. (Closes alongside D5.)

---

#### M9 — Spec REQ-ING-005 frames Entra ID as a *deviation from* the Azure path

**File:** `docs/spec/requirements.md:182–230`

> "The triad is intentionally named distinctly from the Az path's `-InitialSliceHours` / `-MinSliceMinutes` / `-MaxRecordHint` triad because the two underlying APIs have fundamentally different quantitative limits…"

The reasoning (different API limits → distinct names) is correct, but the prose narrates Azure as the *reference path* and Entra as the *deviation*. Even after H5 renames the Az triad to `-AzureRbacInitialSliceHours` etc., this paragraph will still read as "we named Entra distinctly because Az is the canonical baseline" unless the framing is rewritten.

**Fix:** Rewrite as: *"Each platform's adaptive-slicing triad reflects the underlying API's quantitative limits. The Azure RBAC path queries `Get-AzActivityLog`, whose default record ceiling is 5,000 rows per call. The Entra ID Log Analytics path queries the LA Query API, whose hard ceiling is 500,000 rows per query — two orders of magnitude higher. Each platform therefore carries its own validated triad with sensible defaults; sharing parameter names with radically different sensible defaults would be a footgun."*

---

#### M10 — Spec ordering and naming consistently makes Azure RBAC the named primary

**Files:** `docs/spec/requirements.md` (DG-1, DC-1, REQ-ROL-002 listed before REQ-ROL-003, etc.)

Defensible alphabetically (AzureRbac < EntraId), but combined with DG-1 framing, DC-1 naming, and other Azure-first ordering, the cumulative effect is that RBAC always wins ordering disputes.

**Fix:** Add a "Conventions" header at the top of the spec stating *"When both platforms are listed, alphabetical order is used and carries no precedence."* Then re-audit all enumerations to comply (this also addresses M11, M12, M13 below, plus L4, L5).

---

#### M11 — `InputMode` ValidateSet mixes incompatible naming axes

**File:** `src/Invoke-RoleMiningPipeline.ps1:255`

Source: [`src/Invoke-RoleMiningPipeline.ps1` (line 255)](../../src/Invoke-RoleMiningPipeline.ps1#L255).

```powershell
[ValidateSet('CSV', 'ActivityLog', 'LogAnalytics', 'EntraId')]
```

The values are categorized inconsistently:

- `'CSV'` names a **file format**
- `'ActivityLog'` and `'LogAnalytics'` name a **transport / API**
- `'EntraId'` names a **platform**

Sorting the values alphabetically (lining up apples and oranges) does not fix the deeper category-axis problem.

**Fix:** Close out Decision D1. M11 is fully resolved by D1.

---

#### M12 — README "How It Works" stage 1 enumerates ingestion modes RBAC-first

**File:** `README.md:17`; mirrored in `docs/spec/requirements.md:34–37` (DG-5)

> "Supports four modes: Azure Log Analytics (KQL summarization for Azure RBAC or Entra ID audit logs), `Get-AzActivityLog` (adaptive time-slicing), Entra ID directory audit logs (Microsoft Graph API), and local CSV."

**Fix:** Reorder alphabetically (ActivityLog, CSV, EntraId, LogAnalytics) or lead with neutral CSV. Mirror the change in DG-5.

---

#### M13 — README "Quick Start" sequences examples Azure-first within every grouping

**File:** `README.md:46–95`

Five Azure-leading clauses to two Entra-leading. The CSV pair already alternates; extend that pattern.

**Fix:** Alphabetize by `InputMode`, then by `RoleSchema` within shared modes. Document the convention.

---

#### M14 — Issue templates underrepresent Entra as a first-class ingestion mode

**Files:** `.github/ISSUE_TEMPLATE/bug_report.yml:93, 271`; `.github/ISSUE_TEMPLATE/feature_request.yml:138`

Two specific issues:

1. **Ingestion area dropdown omits `EntraId`.** Both templates list `Ingestion (CSV, ActivityLog, LogAnalytics)`. `EntraId` is a first-class `InputMode` value but is not listed; bug filers must choose "Other."
2. **`bug_report.yml` "How did you run it?" placeholder is RBAC-only AND out of date.** Both example commands at line 271 use `samples/principal_action_counts.csv` (RBAC) without `-RoleSchema AzureRbac`. The placeholder is both RBAC-biased and out of date relative to the v2.0 migration that made `-RoleSchema` mandatory for schema-neutral sources — it gives advice that fails.

**Fix:**

- Update both Ingestion-area dropdowns to `Ingestion (CSV, ActivityLog, LogAnalytics, EntraId)`.
- Add a parallel Entra example (`entra_id_principal_action_counts.csv -RoleSchema EntraId`) to the placeholder.
- Add the now-required `-RoleSchema AzureRbac` to the existing Azure example.

---

#### M15 — Agent-instruction documents lack a parity rule, allowing future contributions to regress the convention

**Files:** `.github/copilot-instructions.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`

These four documents govern how AI assistants (Copilot, Claude, Gemini, generic agents) and most human contributors writing new code understand the project's conventions. None of them currently codifies a parity rule between Azure RBAC and Entra ID. Without one, every new contribution will reproduce the existing biases:

- The "Azure RBAC and Entra ID" prose ordering (Azure-first by convention)
- The unprefixed-Azure / prefixed-Entra parameter convention
- The RBAC-as-implicit-default branch shape (`if EntraId { ... } else { ...RBAC... }`)
- The unmarked-Azure-name convention for new helpers

If P1 fixes are implemented but the agent docs are silent on the convention, the parity work will quietly regress over the following release cycles. **This is the highest-leverage single action in the entire plan.**

**Fix:** Add the following identical paragraph to all four files:

Suggested snippet (paste into each of the four agent-instruction files):

````markdown
## Azure RBAC and Entra ID parity rule

Azure RBAC and Entra ID are peers, not primary-and-variant. When writing or modifying code, documentation, tests, parameters, function names, file names, output artifact names, type names, or examples:

- **Never use one platform as the implicit default.** Provider-specific knobs MUST carry an explicit `AzureRbac` or `EntraId` prefix; neither platform may occupy the unprefixed namespace.
- **Shared concepts stay neutral.** Helpers that genuinely apply to both platforms (e.g., `Invoke-RoleMiningPipeline`, `Get-ClusterActionSet`, `ConvertTo-PrincipalActionCount`) keep neutral names. Provider-specific concepts MUST be explicitly prefixed.
- **In any enumeration** (ValidateSets, doc tables, prose, examples, tags, keywords), use **alphabetical order** and treat it as carrying **no precedence**.
- **Branch structure must name both arms.** Prefer `switch ($RoleSchema) { 'AzureRbac' { ... } 'EntraId' { ... } }` over `if ($RoleSchema -eq 'EntraId') { ... } else { ... }`.
- **Schema-neutral helpers MUST require `-RoleSchema` explicitly.** Do not default to either platform.
- **When introducing a provider-specific feature** (e.g., retry/backoff, partition tuning, filter categories), either implement an equivalent feature for the other platform or add an explicit spec callout justifying the deliberate asymmetry.
- **When citing one platform's cmdlet or API** (e.g., `Get-AzActivityLog`), cite the other platform's parallel cmdlet/API in the same sentence (e.g., `Get-MgAuditLogDirectoryAudit`).
- **Future platforms (AWS IAM, GCP IAM, Active Directory) will be additional peers** under the same rule; design accordingly.
````

Codify the rule once; reference it from `CONTRIBUTING.md` and the spec's "Conventions" header (M10).

---

#### M16 — Bench / advanced fixture infrastructure is richer on the Entra side, but the repo does not explain why

**Files:** `bench/README.md`, `docs/benchmarks/issue-23-entra-reduction.md`, `tests/PowerShell/_fixtures/golden/`, equivalence tests

This is **not evidence that Entra is favored overall**; it reflects where recent optimization work happened (issue #23 and friends). It runs in the *opposite* direction from the rest of the parity bias and is therefore worth distinguishing from structural privilege. Still, the repo would benefit from stating that this is issue-driven tooling depth, not platform hierarchy.

**Fix:** Close out Decision D7. Either document the current asymmetry as issue-driven or invest in symmetric/generic tooling.

---

#### M17 — `package.json` description and keywords are RBAC-only; `GloryRole.psd1` Tags are RBAC-first

**Files:** `package.json:4, 10–17`; `src/GloryRole.psd1:8, 57`

Source: [`package.json` (lines 4-17)](../../package.json#L4-L17).

```json
"description": "Unsupervised role mining engine for cloud RBAC — derives least-privilege custom role definitions from activity logs",
...
"keywords": ["powershell","rbac","role-mining","azure","security","least-privilege"]
```

`"description"` says *cloud RBAC* — no Entra mention. `"keywords"` lists `rbac` and `azure` but not `entra-id`, `entra`, or `microsoft-graph`.

Source: [`src/GloryRole.psd1` (line 52)](../../src/GloryRole.psd1#L52).

```powershell
Tags = @('Azure', 'RBAC', 'RoleMining', 'KMeans', 'Clustering', 'LeastPrivilege', 'Security', 'IAM', 'EntraID', 'MicrosoftGraph')
```

`Azure` and `RBAC` precede `EntraID` and `MicrosoftGraph`. Tags drive PSGallery search ordering. The `'RBAC'` tag is *bare* (assumed-Azure) while the Entra tag is qualified `'EntraID'` — use `'AzureRBAC'` for parity. The module Description doesn't mention Entra at all.

**Fix:**

- `package.json`: Replace the description with the README opening sentence (already balanced). Add keywords `entra-id`, `entra`, `microsoft-graph`. Reorder alphabetically.
- `GloryRole.psd1`: Reorder Tags alphabetically. Use `'AzureRBAC'` instead of bare `'RBAC'`. Update Description to mention both platforms.

---

#### M18 — README "Who It's For" omits Entra ID / Microsoft 365 admin personas

**File:** `README.md:142–148`

All four bullets reference Azure or RBAC. A Microsoft 365 admin, identity architect, or Entra ID governance engineer reading the README could conclude this is primarily an RBAC tool.

**Fix:** Add an Entra-flavored bullet (e.g., *"Identity engineers governing Entra ID role assignments who want to discover which `microsoft.directory/*` permissions are actually used across admin workflows"*) or qualify each existing bullet with `(Azure RBAC or Entra ID)`.

---

### Low severity (cosmetic ordering and phrasing)

#### L1 — `Get-ClusterActionSet.ps1` and Stage 9 comment use "RBAC fidelity" for a schema-agnostic operation

**Files:** `src/Get-ClusterActionSet.ps1:11`; `src/Invoke-RoleMiningPipeline.ps1:774–775`

Source: [`src/Invoke-RoleMiningPipeline.ps1` (line 774)](../../src/Invoke-RoleMiningPipeline.ps1#L774).

```powershell
# Use original (pre-TF-IDF) counts for action extraction to maintain RBAC fidelity.
```

The function operates on both Azure RBAC and Entra ID action sets; the fidelity concern applies equally to Entra.

**Fix:** Replace "RBAC fidelity" with "action fidelity" or "fidelity to the original action strings."

---

#### L2 — README line 7: bolded phrases asymmetric in length

**File:** `README.md:7`

"both **Azure RBAC** … and **Entra ID custom roles**" — RBAC bold is 9 chars; Entra bold is a longer phrase.

**Fix:** Use parallel phrasing: "**Azure RBAC custom roles** … and **Entra ID custom roles**".

---

#### L3 — README line 11 frames permission sprawl in RBAC terms only

**File:** `README.md:11`

**Fix:** Add one sentence reflecting Entra ID admin-role sprawl (e.g., over-assigned Global Administrator).

---

#### L4 — README/spec stage descriptions name-check `Get-AzActivityLog` (RBAC) but no parallel name-check for the Microsoft Graph cmdlet

**Files:** `README.md:17`; `docs/spec/requirements.md:34–37`

**Fix:** Cite both: `Get-AzActivityLog` (Azure RBAC) / `Get-MgAuditLogDirectoryAudit` (Entra ID).

---

#### L5 — Stage 8 read-action heuristic documented in RBAC terms only

**File:** `docs/spec/requirements.md:295–298`

> "Actions ending in `/read` are considered read actions."

The heuristic catches both RBAC `Microsoft.*/.../read` and Entra `microsoft.directory/.../read`, but the spec doesn't say so.

**Fix:** One-line clarification noting both action namespaces are caught.

---

#### L6 — `[ValidateSet('AzureRbac', 'EntraId')]` ordering is alphabetical but undocumented

**Files:** `src/Import-PrincipalActionCountFromCsv.ps1:81`; `src/Invoke-RoleMiningPipeline.ps1:262`

Alphabetical and defensible, but no comment confirms the rationale. Combined with the non-alphabetical `InputMode` ValidateSet (M11), the convention is ambiguous.

**Fix:** Add an inline comment near each ValidateSet: `# Order is alphabetical (AzureRbac, EntraId); no preference is implied.`

---

#### L7 — README Stage 10 lists Azure-RBAC output before Entra ID output

**File:** `README.md:26`

> "valid Azure custom role definition JSON file (for Azure RBAC modes) or Entra ID custom role definition JSON file (for Entra ID mode)"

**Fix:** Acceptable alphabetically, but combined with other ordering biases, recompose neutrally: "one of two valid custom-role-definition JSON files: an Azure RBAC role JSON or an Entra ID `unifiedRoleDefinition` JSON, depending on `-RoleSchema`."

---

#### L8 — `Get-AzActivityAdminEvent.Tests.ps1` has 9 `It` blocks vs `Get-EntraIdAuditEvent.Tests.ps1`'s 21

**Files:** `tests/PowerShell/Get-AzActivityAdminEvent.Tests.ps1`; `tests/PowerShell/Get-EntraIdAuditEvent.Tests.ps1`

Mostly driven by the retry/backoff coverage delta (see D2). Beyond that, confirm adaptive time-slicing edge cases, subscription-skip-on-failure behavior, and canonical event output contract are tested to comparable depth.

**Fix:** Audit and supplement Az test coverage to parity, ideally **after D2 is resolved** (most of the gap collapses once the retry decision lands).

---

## Decision closure rubric

The following rubric should be used when selecting among open-decision options. Score each option from **1–5** (higher is better), then evaluate totals and qualitative fit.

| Criterion | Meaning |
| --- | --- |
| **Parity** | How well the option removes Azure-first / Entra-special-case treatment |
| **Clarity** | How understandable the resulting UX/API/docs are for users and contributors |
| **Consistency** | How well the option aligns with the rest of the repo's architecture and naming |
| **Implementation simplicity** | How easy it is to implement correctly |
| **Future extensibility** | How well it accommodates future platforms or new ingestion modes |
| **Verification burden** | How easy it is to verify safely (higher = easier) |

**Selection rule:** Favor options that maximize **Parity**, **Clarity**, and **Consistency**. Because breaking changes are acceptable, low compatibility cost should **not** outweigh a cleaner long-term design. `Implementation simplicity` and `Verification burden` should influence sequencing, not whether a clean design is rejected.

---

## Recommended sequencing

### P0 — Establish the rule set before broad implementation

1. **D4** — Adopt the hybrid naming rule (only one defensible answer; record the choice and move on).
2. **M15** — Add the parity rule paragraph (text in M15) to all four agent docs:
   - `.github/copilot-instructions.md`
   - `AGENTS.md`
   - `CLAUDE.md`
   - `GEMINI.md`
3. **M10** — Add a Conventions section to `docs/spec/requirements.md`:
   - shared concepts use neutral names
   - provider-specific concepts use explicit `AzureRbac` / `EntraId` prefixes
   - alphabetical order carries no precedence
   - schema-neutral surfaces must not default to a platform

### P1 — Fix the highest-confidence structural and correctness gaps

1. **H1** — Remove the CSV importer's Azure default; make `-RoleSchema` mandatory.
2. **H2** — Add Azure-side `[ValidateRange]` parity.
3. **H3, H4** — Rename output artifacts and sample CSV symmetrically.
4. **H5** — Rename the four asymmetrically-prefixed parameters.
5. **H6** — Rename provider-specific public functions (`New-AzureRoleDefinitionJson`, `ConvertTo-NormalizedAction`); add the parallel `ConvertTo-NormalizedEntraIdAction`.
6. **H7** — Expand Entra CSV shared-pipeline contract tests.
7. **M4, M5** — Replace RBAC-as-fallback `if/else` with explicit two-arm `switch` dispatch.

### P2 — Close the open decisions that require design judgment or deeper analysis

1. **D1** — Resolve the selector taxonomy (closes M11).
2. **D5** — Restructure canonical data contracts (closes M8).
3. **D2** — Resolve retry/backoff parity (highest research burden; **requires code analysis and likely live-environment validation**).
4. **D6** — Analyze and resolve `Resolve-PrincipalKey` disposition (closes M2; **requires code analysis before action**).

### P3 — Spec, metadata, and documentation closeout

1. **M6** — Rename DG-1 from "RBAC fidelity" to "Action fidelity"; split into platform-equal sub-goals.
2. **M7** — Rewrite REQ-CAN-001/002 as provider-aware, not Azure-as-universal.
3. **M9** — Rewrite REQ-ING-005 framing so Entra is a peer, not a deviation.
4. **L1** — Replace "RBAC fidelity" inline strings in code with "action fidelity."
5. **M12, M13** — Reorder README "How It Works" and "Quick Start" examples by alphabet.
6. **M14** — Update issue templates (add Entra to Ingestion dropdowns; add Entra example and `-RoleSchema AzureRbac` to placeholder).
7. **M17** — Update `package.json` and `GloryRole.psd1` metadata symmetrically.
8. **M18, L2, L3, L4, L5, L6, L7** — README and spec wording fixes.

### P4 — Feature and tooling parity follow-ons

1. **D3** — Decide whether Azure display-name parity is in scope now.
2. **D7** — Decide whether benchmark/tooling symmetry should be documented or implemented.
3. **L8** — Audit `Get-AzActivityAdminEvent.Tests.ps1` for non-retry coverage gaps (after D2 resolves).
4. **M1** — Rename `Az…`-prefixed adapters to `AzureRbac…` (low-risk after P0/P1 stabilizes).
5. **M3** — Document the provider-specific-knob policy in the spec.

---

## Explicit manual intervention / testing requirements summary

### Requires deeper code analysis before implementation

- **D2** — Retry/backoff parity between Azure and Entra ingestion (read `Get-AzActivityAdminEvent.ps1` failure paths; assess Az cmdlet internal retry behavior).
- **D6** — `Resolve-PrincipalKey` actual scope and intended role (inspect function body and every call site).

### Requires synthetic / mocked testing after implementation

- **H1** — CSV importer schema requirement.
- **H2** — Azure validation additions.
- **H3, H4, H5, H6** — naming and artifact refactors.
- **H7** — Entra shared-pipeline test expansion.
- **D1** — selector taxonomy redesign.
- **D3** — role display-name parity implementation.
- **D5** — canonical contract / type-name changes.

### Likely benefits from live-environment testing

- **D2** — Azure retry/backoff changes, if implemented.
  - Recommended to validate against a real Azure environment because mocked failures may not fully capture Az module behavior.

### Does not require live-environment testing if only documentation / conventions are updated

- **M3, M6–M18 (excluding M14 which has YAML schema concerns), L1–L7**
- Agent-doc parity rule (P0)
- Spec wording and ordering fixes
- Metadata and README framing fixes

---

## Bottom line

The repository is already directionally aligned with parity at the top-level orchestration layer, but it still carries a structurally privileged Azure namespace in several important places, and the Entra path has received the more recent engineering investment (chunking, retry, validation, equivalence harnesses). **The structural privilege concentrates on Azure; the engineering investment concentrates on Entra.** Both directions need correction.

Because breaking changes are acceptable, the repo should **not** compromise with shims, compatibility aliases, or half-measures if a cleaner peer model is available.

The highest-confidence immediate fixes are:

1. **Codify the parity rule in agent docs and the spec before broad refactoring begins** (P0 — highest leverage; without it, P1 work regresses over time).
2. **Remove Azure-default behavior from schema-neutral CSV import** (H1 — silent Entra corruption today).
3. **Add Azure-side validation symmetry** (H2).
4. **Rename provider-specific parameters, functions, sample files, and output artifacts so neither platform occupies the unqualified namespace** (H3–H6).
5. **Strengthen shared-pipeline test symmetry** (H7).

The most important open decisions are:

- **Selector taxonomy (`InputMode` / `InputSource`)** — D1
- **Retry/backoff parity** — D2 (the only open decision that requires live-environment validation)
- **Canonical data-contract restructuring** — D5
- **`Resolve-PrincipalKey` disposition** — D6 (verify before acting)
- **Whether descriptive role-name parity and benchmark/tooling parity are in-scope now or later** — D3, D7

Once P0 and P1 are complete, the repo can credibly claim that Azure RBAC and Entra ID are treated as equal first-class peers in the product surface. Once the open decisions are closed and P2/P3/P4 are finished, the repo will also be internally consistent enough to resist regression over time.

---

## Files reviewed (consolidated)

**Source (`src/`):** `Invoke-RoleMiningPipeline.ps1`, `Import-PrincipalActionCountFromCsv.ps1`, `Import-PrincipalActionCountFromLogAnalytics.ps1`, `Get-AzActivityAdminEvent.ps1`, `Get-EntraIdAuditEvent.ps1`, `Get-EntraIdAuditEventFromLogAnalytics.ps1`, `ConvertFrom-AzActivityLogRecord.ps1`, `ConvertFrom-EntraIdAuditRecord.ps1`, `ConvertTo-EntraIdResourceAction.ps1`, `ConvertTo-NormalizedAction.ps1`, `ConvertTo-PrincipalActionCount.ps1`, `New-AzureRoleDefinitionJson.ps1`, `New-EntraIdRoleDefinitionJson.ps1`, `Get-EntraIdRoleDisplayName.ps1`, `Get-ClusterActionSet.ps1`, `Resolve-PrincipalKey.ps1`, `GloryRole.psd1`.

**Tests (`tests/PowerShell/`):** `Invoke-RoleMiningPipeline.Tests.ps1`, `Import-PrincipalActionCountFromCsv.Tests.ps1`, `Get-AzActivityAdminEvent.Tests.ps1`, `Get-EntraIdAuditEvent.Tests.ps1`, `Get-EntraIdAuditEventFromLogAnalytics.Tests.ps1`, `Get-EntraIdAuditEventFromLogAnalytics.Equivalence.Tests.ps1`, `New-AzureRoleDefinitionJson.Tests.ps1`, `New-EntraIdRoleDefinitionJson.Tests.ps1`, `ConvertFrom-AzActivityLogRecord.Tests.ps1`, `ConvertFrom-EntraIdAuditRecord.Tests.ps1`, `ConvertTo-EntraIdResourceAction.Tests.ps1`, `Get-EntraIdRoleDisplayName.Tests.ps1`. Fixtures: `_fixtures/New-SyntheticAuditLogFixture.ps1`, `_fixtures/baselines/`, `_fixtures/golden/`.

**Samples:** `samples/principal_action_counts.csv`, `samples/entra_id_principal_action_counts.csv`.

**Docs:** `README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `TODO.md`, `docs/spec/requirements.md`, `docs/benchmarks/issue-23-entra-reduction.md`, `bench/README.md`, `bench/Measure-EntraIdLogAnalyticsReduction.ps1`.

**Metadata / config:** `package.json`, `package-lock.json`, `LICENSE`, `.gitattributes`, `.gitignore`, `.markdownlint.jsonc`, `.pre-commit-config.yaml`, `.vscode/settings.json`, `build/Build-Module.ps1`.

**`.github/`:** `copilot-instructions.md`, `instructions/{docs,gitattributes,powershell}.instructions.md`, `linting/PSScriptAnalyzerSettings.psd1`, `pull_request_template.md`, `ISSUE_TEMPLATE/{bug_report,config,documentation_issue,feature_request}.yml`, `workflows/{auto-fix-precommit,build-module,check-placeholders,markdownlint,powershell-ci}.yml`, `dependabot.yml`, `CODEOWNERS`, `scripts/lint-nested-markdown.js`. Agent docs: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`.
