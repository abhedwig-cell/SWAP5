# F-PE-NLGLOB06 closeout — Newton-trajectory exhaustion discrimination

Date: 2026-09-29

Final status:

`NLGLOB06_TRAJECTORY_CERTIFICATE_NONSPECIFIC`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@2332a59d2ec33245f53593960e0c334525eda148`

Qualification authority:

- run `36547506113`;
- job `109337328215`;
- conclusion: SUCCESS.

## Closure

NLGLOB06 tested one preregistered three-iteration trajectory certificate and closes that formulation negatively.

The result is not a failure of the storage-floor attribution.

It sharpens it.

T0 reduces the adequate-model false-positive rate below the frozen 5% gate while preserving perfect rejection of hard above-floor, storage-floor-absent and head/ponding-unresolved controls.

However:

- terminal certification is only 37/96 = about 38.5%;
- only 2/6 route-mode families reach the frozen >=50% family gate;
- early-trajectory false positives remain about 6.51%, above the frozen 5% maximum.

Therefore no endpoint acceptance replay is authorized.

## Scientific interpretation

The accumulated evidence now separates two statements:

1. the late TIMEINT17 endpoint failures genuinely reach the storage/balance representation floor;
2. residual-floor persistence, tiny corrections, poor rho and repeated backtracking non-improvement are still not sufficient to prove terminal exhaustion.

Some still-useful early Newton evolution already occurs while those numerical diagnostics appear exhausted.

The next discriminator must therefore observe whether the accepted candidate state itself continues to move meaningfully across Newton origins.

That is a different scientific question from tuning the rejected T0 thresholds.

## Closed routes

Do not reopen NLGLOB06 by changing:

- trajectory window length;
- factor-4 balance range;
- 0.75 no-progress threshold;
- `z_h_inf` threshold;
- merit-improvement threshold;
- rho threshold/count.

Do not open acceptance replay from T0.

## Direct successor

Open:

`F-PE-NLGLOB07 — representational accepted-state stationarity attribution`.

P0 must remain observational.

The successor should preregister, before result exposure, a state-displacement measure that compares consecutive accepted Newton-origin states against machine/constitutive representational resolution.

At minimum it should distinguish:

- continued physically meaningful accepted-state movement despite floor-like residual diagnostics;
- accepted-state movement collapsed to representation-level changes;
- hard unresolved controls above the existing balance/head/ponding authority;
- route and finite-state consistency.

Prefer conserved moisture displacement as the primary state quantity, with pressure-head displacement as a secondary diagnostic.

No production convergence rule is authorized before a discriminator qualifies.

## Downstream sequence

1. NLGLOB07 observational state-stationarity discrimination;
2. only after a positive discriminator, separately preregister test-only endpoint replay;
3. require unchanged physical interval mass closure and route/state admissibility;
4. return to TIMEINT17 same-route dynamic-top qualification;
5. event localization remains downstream;
6. TIMEINT18 variable-step/LTE remains blocked until dynamic-top endpoint robustness is restored.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB06

BASELINE: `2332a59d2ec33245f53593960e0c334525eda148`

BRANCH: `research/f-pe-nlglob06-trajectory-exhaustion`

STATUS: closed negative

FILES / COMPONENTS TOUCHED: docs/tests/workflow only

INTERFACES CHANGED: none

INVARIANTS AFFECTED: 7, 13, 23, 24, 25, 26, 30

IMPLEMENTATION STATUS: observational T0 discriminator persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB06_TRAJECTORY_CERTIFICATE_NONSPECIFIC`

DEPENDENCIES / BLOCKERS: no replay authorized; dynamic-top endpoint path remains blocked

NEXT SAFE STEP: preregister NLGLOB07 accepted-state stationarity attribution

RECOVERY POINT: this closeout plus NLGLOB06 result and run authority

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
