# F-PE-MIQUAL09 preregistration — paired equilibrium serialized-runtime benchmark

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

Parent authorities:

- MIQUAL06: `QUALIFIED_MIQUAL06_SERIALIZED_RUNTIME_SEAM`;
- MIQUAL07: `MIQUAL07_DYNAMIC_REFERENCE_BLOCKED`;
- MIQUAL08: `MIQUAL08_NO_EXISTING_DYNAMIC_REFERENCE_IN_MANAGER_ENVELOPE`.

## Purpose

Measure whether the qualified moving-interface manager retains a measurable runtime benefit after full serialized transaction, candidate publication and commit overhead on the already-valid equilibrium production-shaped workload.

This workunit does not make a dynamic-performance claim.

## Frozen workload

Reuse MIQUAL07 W0 without changing physics:

- N=16;
- initial saturated tail at node 13;
- B110 default MvG hydraulics from MIQUAL07;
- top flux = 0;
- qbot = 0;
- no source/sink;
- no optional physics;
- SWKIMPL=0;
- conductivity mean method=1;
- dt=0.00125 d;
- full accepted state authority;
- checkpoint -> serialized trial -> candidate -> kernel commit every interval.

For timing only, extend the trajectory length from 4,000 to exactly 40,000 committed intervals. This is repetition of the same equilibrium production transaction, not a physics change.

## Variants

- LEGACY: manager not configured.
- MANAGER: explicit execution-ready moving-interface profile.

Everything else must be identical.

## Preflight

Before timed pairs run both variants once.

Require:

- 40,000/40,000 committed intervals;
- zero retries;
- zero mass/solver/admission/commit rejection;
- hard mass <=1e-8 cm;
- final physical state identical within 1e-12;
- MANAGER reduced route fraction =100%;
- zero fallback;
- zero bypass;
- typed manager diagnostics.

## Timing protocol

- one untimed warmup per variant after preflight;
- exactly 11 paired repetitions;
- odd pairs: LEGACY then MANAGER;
- even pairs: MANAGER then LEGACY;
- no post-hoc outlier deletion;
- no rerun substitution.

Primary metric:

- paired wall elapsed ratio MANAGER/LEGACY around the complete executable trajectory.

Secondary:

- emitted process CPU ratio;
- deterministic work ratio.

Report:

- all 11 paired wall ratios;
- median paired wall ratio;
- geometric-mean paired wall ratio;
- paired CPU ratios and median;
- deterministic work ratio.

## Frozen performance classification

`QUALIFIED_MIQUAL09_EQUILIBRIUM_RUNTIME_GAIN` requires:

- physical preflight passes;
- all timed pairs complete;
- median wall ratio < 0.99;
- geometric-mean wall ratio < 0.99;
- median CPU ratio < 0.99;
- deterministic work ratio < 0.90.

Otherwise, if semantics remain valid:

`MIQUAL09_EQUILIBRIUM_PERFORMANCE_NOT_READY`.

Other classes:

- `MIQUAL09_PHYSICAL_MISMATCH`
- `MIQUAL09_MANAGER_ROUTE_FAILURE`
- `MIQUAL09_EXECUTION_INVALID`.

## Claim boundary

A positive result qualifies only the equilibrium/basic-Richards serialized runtime envelope. It does not establish dynamic, whole-SWAP or MultiSWAP speedup.

## Production boundary

No default change.

`LEGACY_NUMERICS` remains production default.
