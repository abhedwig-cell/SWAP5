# F-PE-REPAIR01 result — inactive-root qbot scratch ownership

Date: 2026-09-26

Status: `QUALIFIED_REPAIR`

PR:
`#635 — F-PE-REPAIR01: inactive-root qbot scratch ownership`

## Production change

Relative to parent head `8812d72695fa05cc98d34146defa13f8b190d036`, REPAIR01 changes exactly one production file:

`src/adapter/mod_reference_richards_legacy_binding.f90`

The mode-5 qbot materializer now uses:

- the existing `sum(provider_root_sink)` when `request%evaluation%root_sink` is associated;
- `qrosum = 0.0_real64` when root extraction is inactive.

No solver tolerance, temporal policy, retry policy, constitutive physics or root-active calculation was changed.

## Confirmed regression repair

The REPRO01 D8 poison test was rerun on the repaired production source.

All provider scratch arms now pass 40/40, including the formerly deterministic failure arm:

- ZERO: 40/40;
- THETA: 40/40;
- K: 40/40;
- CAPACITY: 40/40;
- DKDH: 40/40;
- ROOT_SINK: 40/40.

Before the repair, ROOT_SINK poison was 0/40.

Therefore the production repair removes the confirmed inactive-root read-before-write dependency without bulk workspace zeroing.

## Root-active preservation

The existing prescribed-root tangent equivalence fixture passed on the repaired source.

Observed:

- reference root flux: approximately `-0.1626392064 cm/day`;
- accepted substeps: 2;
- retries: 4;
- physical head difference ROOT versus GENERIC: 0;
- directional head difference: 0;
- integrated exchange-direction difference: 0;
- MODFLOW endpoint-direction difference: 0.

Preservation markers passed:

- root/generic physical identity;
- root/generic directional identity;
- root coverage provenance;
- MODFLOW endpoint authority;
- no extra nonlinear solve.

Thus the conditional ownership repair does not remove or alter the authoritative root contribution when a root-sink provider is actually bound.

## Fixed-build repeatability

The decisive PROFILE05 repeatability workload was repeated after the repair using one fixed compiled exact/A2C binary pair and 20 fresh processes per arm.

Result:

- exact: 20/20 PASS, 0 FAIL;
- A2C: 20/20 PASS, 0 FAIL.

Before repair the same protocol produced:

- exact: 12/20 PASS, 8 FAIL;
- A2C: 16/20 PASS, 4 FAIL.

The status-6 first-corrector nondeterminism was therefore eliminated in the qualification sample.

## Live A1 preservation

The live A1 control passed with exact endpoint identity:

- final MODFLOW head difference: 0;
- final SWAP groundwater exchange difference: 0;
- accepted interface ledger difference: 0;
- coupled iterations: 2 versus 2;
- tangent cache: 1 fresh, 3 reused.

One short-loop timing observation was approximately `2.42%` speed-positive. This timing remains descriptive rather than an admission threshold.

## A2C live coupled requalification

Six independent live SWAP + MODFLOW6 A2C replicas all passed.

All six retained exact equality for:

- final MODFLOW head;
- final SWAP groundwater exchange;
- cumulative accepted interface ledger exchange;
- coupled iteration count.

Observed A2C coupled-loop speedups:

- 0.72%;
- 2.68%;
- 3.73%;
- 3.53%;
- 3.39%;
- 10.31%.

Median approximately:

`3.46%`

Mean approximately:

`4.06%`

The loop is sub-millisecond, so these values are timing observations, not additive performance claims.

Most importantly, no status-6 failure occurred in the six-replica requalification.

## Application-shaped A2C preservation

The 20-step application sequence passed.

Current observation:

- speedup: approximately `22.17%`;
- nonlinear iterations: 60 versus 60;
- accepted substeps: 20 versus 20;
- retries: 0 versus 0;
- backtracking attempts: 60 versus 60;
- maximum mass residual: 0;
- cumulative net-flow difference: 0;
- cumulative storage difference: 0;
- maximum step-net difference: 0.

The runtime gain is therefore not interpreted as a simple iteration-count ratio.

## Other repository workflows

The dedicated REPAIR01 workflow is fully green.

Several older moving-preservation/publication workflows remain red because they enforce frozen source-scope or inherited stacked-lineage assumptions. Examples include:

- RossFast owner-surface preservation;
- PUB-ME source-scope gates;
- current canonical preservation reporting pre-existing `mod_transaction_reference.f90` postimage drift.

These failures do not identify a behavioral regression caused by the six-line REPAIR01 production delta. REPAIR01's direct regression, root-active preservation, exact repeatability, A1, A2C coupled and application-shaped gates all pass.

## Decision

The inactive-root mode-5 qbot scratch ownership defect is repaired and qualified.

The exact live route is repeatable again in the qualification sample.

A1 remains preserved.

A2C coupled robustness is re-established on the repaired postimage.

PROFILE05 combined practical-stack performance measurement may now resume in a separate observation-only continuation.
