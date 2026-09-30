# F-PE-NLGLOB14Z42 preregistration — larger-profile production-shaped trajectory timing

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z41: `QUALIFIED_Z41_HEADCALC_SCALING_TREND_ONLY`;
- real reduced Heritage HeadCalc remains physically equivalent through N=64;
- strongest frozen N=64 solve-service timing ratio = about `0.905`;
- Z34/Z35 manager seam and physical binding are qualified;
- Z31R demonstrates independent adaptive trajectory viability in the original 16-node research scope.

## Purpose

Test whether the solve-service scaling gain survives sequential manager operation on one larger production-shaped profile.

Z42 is one trajectory benchmark, not a broad holdout campaign.

## Frozen profile

Use exactly one homogeneous O05 profile:

- full node count: 64;
- dz = 10 cm;
- initial contiguous saturated lower tail: nodes 49:64;
- initial active nonlinear dimension: 49;
- qbot = 0;
- fixed dry surface-flux top boundary;
- zero lateral/source-sink terms;
- unchanged O05 constitutive provider;
- same manager/reduced HeadCalc route qualified in Z40/Z41.

## Frozen forcing and timestep

Use:

- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- 4,000 nominal intervals;
- no adaptive dt in Z42.

This short trajectory is intentionally performance-shaped and is not a climate/process validation case.

## Full reference trajectory

Start from the frozen full accepted origin.

At each interval:

1. call full 64-node Heritage/reference solve service;
2. accept the full candidate into the independent full trajectory;
3. record tail identity, iterations, Jacobian builds and solve time.

## Adaptive manager trajectory

Start from the byte-identical origin.

At each interval:

1. derive contiguous saturated lower tail from the adaptive accepted state;
2. retain the shallowest saturated node as active guard;
3. set active dimension to that guard-node index;
4. run the actual reduced Heritage/reference service at active n;
5. reconstruct the lower saturated tail;
6. materialize the full 64-node candidate through the manager seam;
7. accept only the adaptive candidate into the adaptive trajectory;
8. use explicit full fallback only if the reduced route is ineligible or fails.

No full-reference state may repair the adaptive trajectory.

## Frozen physical gates

Require throughout:

- both trajectories remain finite;
- per-interval physical ledger <= 5e-8 cm;
- contiguous saturated tail;
- ownership changes at most one face per interval;
- no rollback leakage;
- provider route valid;
- max |theta adaptive-full| <= 5e-6;
- max |h adaptive-full| <= 5e-3 cm;
- final tail identities equal or differ by at most one face with identical ordered direction sequence.

These are Z42 practical trajectory gates and do not alter historical Z30/Z31 strict-reference outcomes.

## Frozen performance diagnostics

Report:

- full trajectory wall time;
- adaptive trajectory wall time;
- adaptive/full wall-time ratio;
- cumulative full and adaptive nonlinear iterations;
- cumulative full and adaptive Jacobian builds;
- active-dimension histogram;
- mean active dimension;
- fallback count and reasons;
- fraction of intervals on reduced route;
- cumulative solve-service work proxy:
  `sum(iterations * active_nodes)`.

Timing must include:

- manager view derivation;
- reduced request refresh;
- reduced HeadCalc solve;
- tail reconstruction;
- full candidate materialization;
- route selection.

Setup/compile time is excluded.

## Frozen performance classifications

### `QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN`

Require:

- all physical gates pass;
- reduced route used on >=95% of intervals;
- adaptive/full trajectory wall-time ratio <0.95;
- cumulative work ratio <0.90;
- no fallback storm (>5% intervals).

### `QUALIFIED_Z42_TRAJECTORY_PHYSICAL_ONLY`

Physical gates pass, but wall-time gain criterion is not reached and no regression criterion is triggered.

### `Z42_TRAJECTORY_TIMING_REGRESSION`

Physical gates pass, but adaptive/full wall-time ratio >1.05.

### `Z42_TRAJECTORY_PHYSICAL_MISMATCH`

Any frozen physical gate fails.

### `Z42_TRAJECTORY_EXECUTION_INVALID`

Build/timer/checksum invalid.

## Consequence

A positive timing gain authorizes production-admission-candidate preparation plus a small broader holdout.

A physical-only result permits one profiling pass before deciding whether the manager is worth further production optimization.

A timing regression closes the current production-performance route unless profiling identifies one bounded zero-waste defect.

## Stop rules

Do not:

- change forcing, horizon or gates after exposure;
- repair adaptive state from full;
- add fitted corrections;
- add mass redistribution;
- add anti-chatter logic;
- broaden to BOFEK-wide runs inside Z42;
- change production default.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z42

BASELINE: `377fa84a760cdcac2376b58d5460f9cba410e723`

BRANCH: `research/f-pe-nlglob14z42-large-profile-trajectory`

NEXT SAFE STEP: implement one compiled N=64 sequential full/adaptive manager trajectory benchmark.

## Production boundary

Research trajectory timing only.

`LEGACY_NUMERICS` remains production default.
