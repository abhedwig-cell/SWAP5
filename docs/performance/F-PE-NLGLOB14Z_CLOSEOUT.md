# F-PE-NLGLOB14Z closeout — late retreat/disappearance control exposure

Date: 2026-09-29

Final status:

`BLOCKED_NLGLOB14Z_CONTROL_EXPOSURE`

with preserved partial authority:

`NLGLOB14Z_FINE_GRID_LATE_RETREAT_SIGNAL`.

## Closure

NLGLOB14Z does not qualify complete disappearance.

The frozen 8-fixture control bank cannot complete at dt=2.5e-4 d because both route families terminate with `ENDPOINT_SOLVE_FAILURE` around 1.14-1.15 d while remaining finite and mass-clean.

The three finer dt levels in both route families complete through 6.40 d and expose the same additional accepted physical retreat:

`7:16 -> 8:16`

near 2.44 d.

No complete saturated-block disappearance is observed.

## Mechanistic blocker

The current blocker is late-horizon fixed-dt endpoint solvability at the coarsest dt.

It is not:

- a mass-conservation failure;
- a noncontiguous saturation state;
- a dry-forcing failure;
- a release-threshold problem;
- evidence against the 7:16 -> 8:16 retreat.

Do not repair this by changing MAXIT, BALTOL, forcing or saturation thresholds.

## Direct successor

Open a preregistered timestep-refinement workunit for the late retreat.

The successor should retain:

- HEAD and RUNOFF route families;
- unchanged dry forcing;
- persistent-KLAG physical control;
- dt levels 1.25e-4, 6.25e-5 and 3.125e-5 d as existing complete evidence;
- add finer dt levels only to test event-time refinement.

A positive refinement result may then authorize a split-ownership successor through the 7:16 -> 8:16 event.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z

BRANCH: `research/f-pe-nlglob14z-disappearance-exposure`

PRIMARY RUN: `36608794784`

ATTRIBUTION RUN: `36609648621`

STATUS: closed with explicit coarse-dt control blocker

QUALIFICATION STATUS: aggregate blocked; fine-grid late-retreat signal preserved

NEXT SAFE STEP: preregister late-retreat timestep refinement without tolerance tuning.

## Production boundary

No production source or default policy change.

`LEGACY_NUMERICS` remains production default.
