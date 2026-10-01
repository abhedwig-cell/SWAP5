# F-PE-MIQUAL01 preregistration — broad post-admission moving-interface qualification

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

Parent authorities:

- Z43E: `QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`;
- Z43F: `QUALIFIED_Z43F_CANONICAL_ADMISSION_READY`;
- PR #920 merged the explicit non-default manager seam to canonical;
- `LEGACY_NUMERICS` remains production default.

## Purpose

Test the canonically admitted moving-interface manager on a broader repository-backed hydraulic-archetype bank before any discussion of broader production use or default activation.

This is post-admission qualification, not redesign.

## Scope boundary

The repository BOFEK01 bank contains four hydraulic archetypes rather than a complete BOFEK profile catalogue. Therefore MIQUAL01 may qualify portability across these four repository-backed hydraulic archetypes and two geometries, but may not claim BOFEK-wide portability.

## Frozen case bank

Use the four materials already frozen in `docs/performance/F-PE-BOFEK01_TESTBANK.json`:

- B01;
- B12;
- O05;
- O14.

For every material execute both frozen geometries:

- N32 with initial saturated-tail start node 25;
- N64 with initial saturated-tail start node 49.

Total: 8 trajectories.

Common trajectory contract:

- dz = 10 cm;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- zero sources/sinks;
- 4,000 nominal intervals;
- independent full and adaptive trajectories;
- actual compiled Heritage/reference HeadCalc on both paths;
- no adaptive-state repair from full.

## Frozen numerical profile

Use the same explicit non-default Z43E evidence profile:

- max_iterations = 16;
- max_backtracking = 8;
- conductivity implicit mode = 0;
- conductivity mean = 1;
- min step duration = 1e-6 d;
- compartment and total balance tolerance = 1e-12;
- head absolute and relative tolerance = 1e-9;
- ponding tolerance = 1e-10.

This does not establish MAXIT16 as a production default.

## Reference preflight

Every one of the 8 full-reference trajectories is executed before the corresponding adaptive trajectory.

If any reference trajectory cannot complete, classify:

`MIQUAL01_REFERENCE_DOMAIN_LIMITATION`

and report the failing cases. Do not silently drop or replace them.

## Frozen physical gates

For every reference-valid case require:

- full and adaptive completion;
- finite state;
- per-interval physical ledger <= 5e-8 cm;
- no accepted-origin/rollback leak;
- contiguous saturated tail;
- ownership change <= 1 face per interval;
- max |h adaptive-full| <= 5e-3 cm;
- max |theta adaptive-full| <= 5e-6;
- final tails equal or differ by at most one face;
- identical ordered ownership directions.

## Frozen operational gates

Per case report:

- reduced-route fraction;
- fallback count;
- bypass count;
- fallback reasons;
- active-dimension histogram;
- mean active dimension;
- persistent request/candidate reallocations.

Require:

- explicit route diagnostics;
- reduced route >=95%;
- fallback+bypass <=5%;
- no silent fallback.

## Frozen performance gates

Per case report:

- full wall time;
- adaptive wall time;
- adaptive/full wall ratio;
- deterministic work ratio.

Broad qualification requires:

- no case wall ratio >1.05;
- geometric-mean wall ratio <0.98;
- at least 4/8 cases wall ratio <0.95;
- geometric-mean deterministic work ratio <0.90.

Wall-clock evidence is solver/trajectory level, not whole-MultiSWAP runtime.

## Frozen classifications

### `QUALIFIED_MIQUAL01_BROAD_ARCHETYPE_PORTABILITY`

All 8 reference trajectories complete and all physical, operational and aggregate performance gates pass.

### `MIQUAL01_REFERENCE_DOMAIN_LIMITATION`

At least one frozen full-reference trajectory fails.

### `MIQUAL01_PHYSICAL_MISMATCH`

Reference-valid cases exist but one or more adaptive physical gates fail.

### `MIQUAL01_OPERATIONAL_FAILURE`

Physics pass but route/fallback/bypass contract fails.

### `MIQUAL01_PERFORMANCE_NOT_READY`

Physics and operations pass but aggregate performance gates fail without major regression.

### `MIQUAL01_PERFORMANCE_REGRESSION`

Any case wall ratio >1.10 or aggregate geometric mean >1.05.

### `MIQUAL01_EXECUTION_INVALID`

Build, timer, reporting or protocol execution is invalid.

## Execution policy

Exploratory calculations should run locally where possible.

The current execution container cannot resolve github.com and cannot materialize the repository clone. One focused GitHub Action is therefore authorized for this compiled Fortran qualification after all files are persisted.

Do not start parallel Actions sweeps.

## Positive consequence

A positive MIQUAL01 result authorizes the next separate workunit for forcing-regime expansion and then an application-scale end-to-end SWAP/MultiSWAP benchmark.

It does not authorize changing the production default.

## Stop rules

Do not:

- tune thresholds after exposure;
- drop difficult cases;
- change forcing or geometry inside this workunit;
- repair adaptive state from full;
- add correction coefficients;
- redistribute mass;
- change `LEGACY_NUMERICS` default;
- claim BOFEK-wide or whole-MultiSWAP speedup.

## Recovery point

WORK UNIT: F-PE-MIQUAL01

BASELINE: `0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

BRANCH: `research/f-pe-miqual01`

NEXT SAFE STEP: materialize the minimal Z43E qualification harness on current canonical, expand it to the frozen 8-case bank, then execute one focused qualification run.
