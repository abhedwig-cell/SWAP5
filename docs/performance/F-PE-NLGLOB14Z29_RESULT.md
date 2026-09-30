# F-PE-NLGLOB14Z29 result — reduced physical moving-interface binding

Date: 2026-09-30

Status:

`QUALIFIED_Z29_REDUCED_PHYSICAL_BINDING`

Qualification authority:

- workflow run: `36731447222`;
- HEAD segment-B job: `109948831768`;
- RUNOFF segment-B job: `109948831533`;
- workflow conclusion: SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@a3af828f442da7665615b222a0d3a7e5e614ac53`

The canonical delta since the Z29 baseline is confined to ELASTIC69 workflow/documentation and does not touch the Z29 solver/research dependency surface.

Research postimage before result persistence:

`research/f-pe-nlglob14z29-reduced-physical-binding@da64f2778f1a1eb818234dff44f14332d43c741a`

## Aggregate result

Both fine O05 fixtures classify:

`QUALIFIED_Z29_REDUCED_PHYSICAL_BINDING`.

All observer-only reduced candidates satisfy the frozen physical equivalence gates.

Coverage:

- HEAD: 41 compared intervals;
- RUNOFF: 29 compared intervals;
- total: 70 intervals;
- equivalent: 70/70.

## Physical equivalence

Across all compared event/control intervals:

- reduced candidate converges;
- resulting saturated-tail identity matches full reference;
- ownership direction matches full reference;
- dynamic-top route matches full reference;
- theta differences remain at roundoff;
- physical ledger differences remain at roundoff;
- top-flux differences are zero in the frozen fixtures.

Maximum observed differences:

### HEAD

- max |h_reduced - h_full|: about `7.30e-12 cm`;
- max theta difference: about `1.11e-16`;
- max ledger difference: about `1.11e-15 cm`.

### RUNOFF

- max |h_reduced - h_full|: about `2.07e-11 cm`;
- max theta difference: about `5.55e-17`;
- max ledger difference: about `5.55e-16 cm`.

These are far inside the frozen Z29 comparison gates.

## Reduced dimensions

The reduced physical solver uses active dimensions:

`n = 12, 13, 14`

instead of full `n = 16`.

The guard-node formulation successfully reproduces both:

- retreat events;
- reverse events.

This is important because the reduced representation does not freeze the moving interface or require hysteresis.

## Deterministic work result

The frozen normalized numerical-Jacobian probe work is:

`reduced_iterations * n_active / (full_iterations * 16)`.

### HEAD

- minimum observed ratio: 0.75;
- maximum observed ratio: 0.875;
- mean observed ratio: about 0.8293.

### RUNOFF

- minimum observed ratio: 0.75;
- maximum observed ratio: 0.875;
- mean observed ratio: about 0.8233.

Thus the observer-only reduced solve lowers this deterministic algebra-work proxy by roughly:

- 12.5% to 25% interval-by-interval;
- about 17% to 18% on average across the frozen event/control windows.

No extra Newton iterations are required by the reduced solve in the qualified windows.

## Scientific interpretation

Z29 is the first direct evidence that the moving-interface idea can preserve the qualified physical trajectory while actually reducing nonlinear algebra dimension.

The result combines previously separate evidence:

- Z20-Z22: moving-interface physical semantics;
- Z25-Z26: chatter is not a retry or nonlinear-work pathology;
- Z28: production solver primitives support genuine variable dimension;
- Z29: the reduced physical solve reproduces the full-reference candidate on the moving-interface event windows.

This is materially stronger than the earlier fixed-dimension research harness.

## Qualified claim boundary

Qualified:

- reduced physical candidate equivalence on all frozen HEAD/RUNOFF event/control intervals;
- retreat and reverse ownership transitions reproduced;
- n=12–14 active solves replace n=16 full solves on the tested windows;
- deterministic algebra-work proxy reduced by roughly 12.5–25%;
- no new hysteresis, dwell, clipping, mass redistribution or event suppression.

Not yet qualified:

- using the reduced candidate to drive the accepted trajectory;
- long-horizon error accumulation under reduced-state driving;
- production Fortran manager integration;
- end-to-end wall-clock speedup;
- broader soil/profile portability;
- production admission.

## Consequence

The next workunit should let the reduced manager drive the trajectory, while running the full-column solve as an observer/reference.

That is the decisive bridge to a practical SWAP Heritage timestep manager.

Required next evidence:

1. adaptive trajectory remains physically equivalent over the long horizon;
2. moving-interface event sequence remains valid;
3. cumulative mass/rollback gates remain clean;
4. reduced solve remains variable-dimension;
5. work/runtime reduction is measured over the full trajectory, not just selected windows.

## Production boundary

Research only.

No production default change.

`LEGACY_NUMERICS` remains production default.
