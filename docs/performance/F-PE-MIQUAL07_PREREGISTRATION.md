# F-PE-MIQUAL07 preregistration — production-shaped serialized runtime benchmark

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

Parent authority:

- MIQUAL06: `QUALIFIED_MIQUAL06_SERIALIZED_RUNTIME_SEAM`;
- MIQUAL05: `QUALIFIED_MIQUAL05_DYNAMIC_TOP_EVENT_WINDOW`;
- moving-interface manager remains explicit opt-in;
- `LEGACY_NUMERICS` remains production default.

## Purpose

Measure end-to-end performance and preservation of the moving-interface manager through the normal serialized-reference transaction/runtime route, including candidate publication and commit between accepted intervals.

This benchmark must not use the older research trajectory harness as performance authority.

## Frozen variants

Exactly two runtime variants:

1. `LEGACY`
   - normal serialized-reference runtime;
   - moving-interface manager not configured.

2. `MANAGER`
   - same serialized-reference runtime;
   - explicit execution-ready moving-interface profile;
   - all other configuration identical.

## Frozen workload geometry and hydraulics

Use the MIQUAL06 qualified O05-shaped N=16 profile:

- 16 nodes;
- dz = 10 cm;
- initial saturated tail starts at node 13;
- full accepted state always remains 16-node physical authority;
- B110 default MvG hydraulic parameters identical to MIQUAL06;
- no optional processes;
- qbot = 0;
- zero source/sink arrays;
- SWKIMPL=0;
- conductivity mean method=1;
- MAXIT16 evidence profile.

## Frozen workloads

### W0 EQUILIBRIUM

Purpose: isolate serialized runtime/transaction overhead while preserving a permanently eligible reduced state.

- top flux = 0 cm/d;
- dt = 0.00125 d;
- 4,000 committed intervals;
- hydrostatic saturated-tail initial state.

### W1 MILD_DYNAMIC

Purpose: exercise repeated publication/commit on a changing physical trajectory without introducing a new process model.

- top flux = -0.01 cm/d;
- dt = 0.000125 d;
- 4,000 committed intervals;
- same initial saturated-tail state.

The smaller W1 dt is frozen before result exposure to keep the full-reference transaction inside the already observed solvability envelope without changing numerical tolerances.

## Transaction contract

Every interval must execute:

1. capture checkpoint from current committed state;
2. serialized backend `run_trial`;
3. require valid candidate;
4. commit candidate through the kernel transaction API;
5. use the new committed state as authority for the next interval.

No adaptive state repair or direct state assignment outside transaction authority is allowed.

Frozen transaction settings for both variants:

- external full-half temporal mode;
- temporal tolerance = 1.0;
- mass tolerance = 1e-10;
- max retries = 2;
- retry scale = 0.5;
- max committed substeps = 4.

## Preflight gate

Before timing repetitions, each workload must complete once in LEGACY and MANAGER mode.

Require:

- 4,000/4,000 committed intervals;
- no commit rejection;
- no invalid candidate;
- finite state;
- hard mass residual <=1e-8 cm;
- final full-state pressure head difference <=5e-3 cm;
- final water-content difference <=5e-6;
- final storage difference <=1e-5 cm;
- final tail identity equal or within one face;
- MANAGER reduced route fraction >=95%;
- manager fallback+bypass <=5%;
- all non-reduced reasons typed.

If W1 full-reference preflight fails, classify `MIQUAL07_DYNAMIC_REFERENCE_BLOCKED`; do not tune dt or temporal tolerance after exposure.

## Timing protocol

Only after both preflights pass:

- one untimed warmup per workload and variant;
- 7 paired timing repetitions per workload;
- alternate execution order by pair:
  - odd pair: LEGACY then MANAGER;
  - even pair: MANAGER then LEGACY;
- no post-hoc outlier deletion.

Primary metric:

- process wall elapsed time measured around one complete 4,000-interval trajectory.

Secondary metrics:

- process CPU time emitted by the executable;
- deterministic nonlinear work from serialized transaction diagnostics.

Per workload report:

- paired wall ratios MANAGER/LEGACY;
- median paired wall ratio;
- geometric-mean paired wall ratio;
- median CPU ratio;
- deterministic work ratio;
- retries/attempts;
- reduced/fallback/bypass counts.

## Performance gates

A production-shaped performance candidate requires:

- both workload preflights physically pass;
- no timed trajectory physical failure;
- geometric mean of the two workload median wall ratios < 0.99;
- neither workload median wall ratio > 1.03;
- at least one workload median wall ratio < 0.98;
- geometric mean deterministic work ratio < 0.90.

The benchmark may classify performance not ready even if runtime semantics remain qualified.

## Frozen classifications

- `QUALIFIED_MIQUAL07_PRODUCTION_RUNTIME_PERFORMANCE_CANDIDATE`
- `MIQUAL07_DYNAMIC_REFERENCE_BLOCKED`
- `MIQUAL07_PHYSICAL_MISMATCH`
- `MIQUAL07_MANAGER_ROUTE_FAILURE`
- `MIQUAL07_PERFORMANCE_NOT_READY`
- `MIQUAL07_EXECUTION_INVALID`

## Positive consequence

A positive result authorizes a focused production-admission workunit for the bounded serialized-runtime manager seam, followed by canonical PR/integration if live canonical remains compatible.

A performance-not-ready result preserves MIQUAL06 as a valid opt-in runtime seam but does not justify production admission of that seam for performance.

## Stop rules

Do not:

- change benchmark workload after exposure;
- retune dt/tolerances;
- remove slow timing pairs;
- broaden optional-process eligibility;
- change production default;
- infer MultiSWAP scaling from this single-column benchmark.

## Production boundary

`LEGACY_NUMERICS` remains production default.
