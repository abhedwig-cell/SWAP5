# F-PE-NLGLOB13B closeout — bounded second-level near-saturation subdivision

Date: 2026-09-29

Final status:

`CLOSED_TG_NEARSAT_SUBDIV4_INSUFFICIENT`

Qualification authority:

- run `36555644418`;
- job `109364015914`;
- SUCCESS.

## Closure

Bounded temporal subdivision through `h/4` is closed as insufficient.

All seven frozen O05/TG near-saturation target trajectories reach the second subdivision level and still fail accepted-state retention admissibility.

Positive evidence remains:

- smooth temporal order about 2.048;
- mass closure at roundoff;
- no process failure;
- explicit maximum-depth bound respected.

The failure is therefore not caused by smooth-order regression, mass leakage or unbounded retry behavior.

## Scientific consequence

The near-saturation line has now falsified:

1. changing the coefficient-stage fraction to one half;
2. changing coefficient prediction from moisture to head space as a complete remedy;
3. one-level `h/2` subdivision;
4. bounded second-level `h/4` subdivision.

The next step is not another subdivision depth.

Open:

`F-PE-NLGLOB13C — saturation-bound accepted-state scaling attribution`.

NLGLOB13C must remain observational and determine whether the prospective TG accepted-state moisture overshoot tends toward zero with decreasing substep duration or represents a real need for saturated/elastic storage beyond the current `theta_s` state representation.

The existing ELASTIC physical-storage authority may be consulted as prior architecture/scientific context, but NLGLOB13C may not silently combine the two mechanisms.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB13B

BASELINE: `5c498c9df933f900fd00869b72106584f10f6622`

BRANCH: `research/f-pe-nlglob13b-quarterstep-subdivision`

STATUS: closed negative

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `CLOSED_TG_NEARSAT_SUBDIV4_INSUFFICIENT`

NEXT SAFE STEP: preregister NLGLOB13C saturation-bound scaling attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
