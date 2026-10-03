# F-PE-NLGLOB14O preregistration — first-retreat full-column TG handoff admissibility

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

current `integration/f-ci-canonical` at preregistration.

Research parent authority:

- NLGLOB14N3: `QUALIFIED_SATURATION_ROOT_RETRY_BRACKET_CONTRACTION_RESEARCH`;
- restored NLGLOB14N gate: `QUALIFIED_REFINED_FIRST_RETREAT_EVENT_TIME_CONVERGENCE`;
- NLGLOB14K: mixed-profile upper-region TG admissibility is nonpersistent while a lower saturated block remains.

## Purpose

The first retreat of the saturated lower block is now physically established and temporally localizable.

NLGLOB14O tests whether that retreat event is a valid **whole-column handoff origin** for the currently qualified provider-consistent head-space TG mechanism.

This is observational.

No temporal-mode switch is performed.

## Frozen fixtures

Use the same 12 O05 dry trajectories from the NLGLOB14N3 six-level replay:

- HEAD and RUNOFF wet-entry families;
- dt = 2.5e-4 through 7.8125e-6 d;
- horizon = 0.05 d;
- NLGLOB14N3 saturation-root retry-bracket policy;
- unchanged dry forcing and physical mass authority.

## Frozen handoff origin

For each trajectory define `RETREAT_HANDOFF_ORIGIN` as the first accepted state in the 14 -> 13 retreat bracket at which:

- node 3 is unsaturated under both existing indicators;
- nodes 4:16 remain saturated;
- the saturated set is contiguous;
- state is finite.

This is the accepted post-event endpoint B from the qualified first-retreat bracket.

## Frozen TG-origin probe

At RETREAT_HANDOFF_ORIGIN evaluate the same default-mVG constitutive provider on the accepted pressure-head state.

For every active node record capacity `C=dtheta/dh`.

The currently qualified head-space TG mechanism requires a finite positive origin capacity for every node in the full-column TG domain.

A full-column TG handoff origin is admissible only if:

- all 16 capacities are finite;
- all 16 capacities are strictly positive;
- accepted theta/head pairs remain constitutively consistent.

No capacity floor, clipping or alternate state representation is permitted.

## Control authority

The actual trajectory remains on persistent saturated KLAG.

It must continue to:

- complete;
- remain finite;
- remain mass-clean;
- preserve the accepted first-retreat bracket.

The TG-origin probe does not mutate accepted state or accounting.

## Frozen classifications

If all 12 retreat origins contain zero-capacity saturated lower nodes while the upper unsaturated nodes have finite positive capacity:

`NLGLOB14O_FULL_COLUMN_TG_HANDOFF_FALSIFIED_BY_SATURATED_DOMAIN`.

If all 12 retreat origins have finite positive capacity on all active nodes:

`NLGLOB14O_FULL_COLUMN_TG_HANDOFF_ORIGIN_ADMISSIBLE`.

If constitutive/state consistency fails:

`NLGLOB14O_HANDOFF_STATE_INCONSISTENT`.

Otherwise:

`NLGLOB14O_MIXED_HANDOFF_ADMISSIBILITY`.

## Consequence

A falsified whole-column TG handoff means the first retreat event is a real release-direction event but not a valid release of the **entire column** to ordinary TG while a lower saturated block remains.

That would move the ownership question toward a moving-interface or split-domain temporal formulation, or toward retaining saturated treatment until complete lower-block desaturation.

A positive whole-column result would justify a separate transactional shadow-solve handoff experiment.

## Stop rules

Do not:

- switch temporal mode;
- add a capacity floor;
- clip capacity, head or theta;
- alter forcing, dt or horizon;
- change the retreat event;
- relax mass gates;
- modify production source.

## Architecture invariants

Affected invariants: 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: diagnostics only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14O

BRANCH: `research/f-pe-nlglob14o-first-retreat-shadow-handoff`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: expose provider capacity on accepted persistent-mode states and classify the first post-retreat origin.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
