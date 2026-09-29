# F-PE-NLGLOB07 closeout — representational accepted-state stationarity

Date: 2026-09-29

Final status:

`NLGLOB07_STATE_STATIONARITY_NONSPECIFIC`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@30e507fc8bdf7f7c37f327ab378e5c4a8ae39b94`

Qualification authority:

- run `36548150742`;
- job `109339441540`;
- conclusion: SUCCESS.

## Closure

NLGLOB07 closes the preregistered S0 discriminator negatively.

The terminal signal is maximally strong:

- 96/96 terminal endpoint trajectories are S0 state-stationary;
- all six route-mode families certify 16/16;
- all hard unresolved controls are rejected.

But S0 is not specific:

- adequate-model false-positive fraction ≈ 22.8%;
- early-trajectory false-positive fraction ≈ 28.6%.

Therefore no endpoint replay is authorized from S0.

## Scientific consequence

This is not merely another failed certificate.

The 96/96 terminal result shows that the endpoint blocker reaches a state where consecutive accepted moisture states differ only within a small representational envelope.

The high early-trigger rate then raises a new, separately testable question:

whether the solver continues taking iterations after physically meaningful accepted-state movement has already ceased.

That question is not answered by labeling early iterations as false positives.

The relevant quantity is the **tail drift** of the accepted physical state after first stationarity.

## Direct successor

Open:

`F-PE-NLGLOB08 — post-stationarity physical tail-drift attribution`.

P0 must remain observational and preregister before evaluating drift.

Use the existing physical water-depth authority rather than a newly tuned iteration threshold.

At minimum evaluate for every S0-certified point:

1. volume-weighted absolute moisture-state difference to every later accepted Newton origin;
2. maximum tail excursion in physical water-depth units;
3. final tail difference to the terminal candidate;
4. route continuity and finite-state guards;
5. existing head/ponding/balance guards.

The primary question is whether subsequent Newton evolution exceeds the unchanged `5e-8 cm` physical interval mass significance/gate scale.

A positive result may justify reclassifying "early" S0 occurrences as physically inert rather than unsafe, but it still does not by itself change production convergence.

## Closed routes

Do not rescue S0 by tuning its ULP envelope or trajectory length.

Do not remove the NLGLOB07 negative result.

Do not perform endpoint acceptance replay before the tail-drift question is preregistered and qualified.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB07

BASELINE: `30e507fc8bdf7f7c37f327ab378e5c4a8ae39b94`

BRANCH: `research/f-pe-nlglob07-state-stationarity`

STATUS: closed negative

FILES / COMPONENTS TOUCHED: docs/tests/workflow only

INTERFACES CHANGED: none

INVARIANTS AFFECTED: 7, 13, 23, 24, 25, 26, 30

IMPLEMENTATION STATUS: S0 observational discriminator persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB07_STATE_STATIONARITY_NONSPECIFIC`

DEPENDENCIES / BLOCKERS: no replay authorized

NEXT SAFE STEP: preregister NLGLOB08 tail-drift attribution

RECOVERY POINT: this closeout plus NLGLOB07 result/run authority

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
