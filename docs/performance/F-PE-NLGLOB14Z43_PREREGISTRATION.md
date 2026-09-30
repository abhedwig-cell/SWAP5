# F-PE-NLGLOB14Z43 preregistration — moving-interface manager production-admission candidate preparation

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authorities:

- Z31R: `QUALIFIED_Z31R_REGIME_LOCALIZED_BIAS` — independent adaptive driving reaches 540 d with no hard physical blocker and ~20% deterministic work reduction;
- Z34: `QUALIFIED_Z34_MANAGER_SEAM_READY`;
- Z35: `QUALIFIED_Z35_MANAGER_PHYSICAL_BINDING_SMOKE` — explicit reduced/fallback/bypass/no-leak semantics qualified;
- Z36: compact O05/O14/B12 same-origin holdout physically equivalent;
- Z39: residual manager overhead <0.3% of real Richards solve cost;
- Z40: real reduced Heritage HeadCalc binding qualified;
- Z41: favorable active-dimension/profile-size timing trend;
- Z42: `QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN` — N=64 sequential trajectory gives wall ratio ~0.927 and work ratio ~0.766 with zero fallback.

## Purpose

Prepare, but do not yet canonically admit, a non-default production-admission candidate for the moving-interface manager.

Z43 must answer whether the accumulated evidence is sufficiently portable and operationally bounded to justify a canonical admission workunit.

## Frozen evidence reuse

Do not rerun already-qualified properties unless the new holdout contradicts them.

Reuse as authority:

- Z35 explicit forced fallback;
- Z35 explicit ineligible bypass;
- Z35 rollback/no-leak;
- Z31R moving-interface/event behavior;
- Z40 provider/service binding;
- Z42 real trajectory timing.

## New compact heterogeneous trajectory holdout

Run exactly three N=64 trajectories using the Z42 real manager route:

1. O05, initial tail 49:64;
2. O14, initial tail 49:64;
3. B12, initial tail 49:64.

Common:

- 64 nodes;
- dz = 10 cm;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- zero sources/sinks;
- 4,000 nominal intervals;
- independent full and adaptive trajectories;
- real Heritage/reference HeadCalc on both paths;
- no full-state repair of adaptive state.

The holdout is intentionally compact and is not a BOFEK-wide campaign.

## Frozen physical gates

Each new trajectory must satisfy:

- all values finite;
- no reduced reconstruction failure;
- no nonlinear solve failure;
- per-interval adaptive physical ledger <= 5e-8 cm;
- contiguous saturated tail;
- ownership change <=1 face/interval;
- no accepted-origin leakage;
- max |h adaptive-full| <= 5e-3 cm;
- max |theta adaptive-full| <= 5e-6;
- final tail equal or within one face with matching ordered ownership directions.

## Frozen operational gates

Across the three holdouts require:

- reduced route usage >=95% in every case;
- fallback + bypass <=5% in every case;
- every fallback/bypass reason explicit;
- no fallback storm;
- persistent request/candidate buffers remain bounded;
- no production-default change.

## Frozen performance gates

Admission-candidate timing is intentionally weaker than a release benchmark.

Require:

- no holdout trajectory wall ratio >1.05;
- geometric-mean wall ratio <1.00;
- geometric-mean deterministic work ratio <0.90.

A single mildly neutral material is allowed if aggregate performance remains favorable and no case regresses >5%.

## Non-default configuration seam

Z43 must add or identify one explicit typed runtime/application configuration for the manager.

Required semantics:

- default disabled;
- when disabled, existing production route is unchanged;
- when enabled, moving-interface manager may be selected only where eligible;
- explicit full fallback remains available;
- configuration does not itself own physical state;
- diagnostics expose whether manager was enabled/used/fell back.

Do not rename or alter `LEGACY_NUMERICS` default behavior.

## Frozen classifications

### `QUALIFIED_Z43_PRODUCTION_ADMISSION_CANDIDATE_READY`

Require:

- all three new physical holdouts pass;
- all operational gates pass;
- aggregate timing/work gates pass;
- non-default config seam is explicit and defaults disabled;
- prior Z35 fallback/bypass/no-leak authority remains compatible.

### `Z43_HOLDOUT_PHYSICAL_FAILURE`

Any physical holdout gate fails.

### `Z43_OPERATIONAL_FALLBACK_FAILURE`

Fallback/bypass behavior becomes ambiguous or excessive.

### `Z43_PERFORMANCE_NOT_PORTABLE`

Physical/operational gates pass, but performance aggregate fails.

### `Z43_CONFIGURATION_SEAM_BLOCKED`

No clean default-off typed configuration can be introduced without violating existing production ownership/defaults.

## Consequence

A positive Z43 result authorizes a separate canonical admission workunit.

It does not itself change the production default.

Canonical admission must still:

1. reconcile to current canonical;
2. run required CI/admission evidence;
3. preserve default-off behavior;
4. document qualified scope and fallback boundary.

## Stop rules

Do not:

- broaden holdout after exposure;
- change gates after results;
- introduce fitted corrections;
- redistribute mass;
- change historical strict-reference conclusions;
- set manager enabled by default;
- claim whole-MultiSWAP speedup from Z43.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43

BASELINE: `4e0d267300963cce380c17500b3f381773bcc200`

BRANCH: `research/f-pe-nlglob14z43-admission-candidate`

NEXT SAFE STEP: add default-off configuration seam, parameterize/reuse Z42 N=64 trajectory for the frozen O05/O14/B12 holdout, then evaluate admission-candidate criteria.

## Production boundary

Candidate preparation only.

`LEGACY_NUMERICS` remains production default.
