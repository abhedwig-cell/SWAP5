# F-PE-NLGLOB14Z1 preregistration — late-retreat timestep refinement

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b6c9079c209eb6d1fe2db2fd61ff330941770166`

Parent research authority:

- NLGLOB14Z aggregate control exposure is blocked by dt=2.5e-4 endpoint solve failure around 1.14-1.15 d;
- that failure remains finite and mass-clean and occurs before the later physical retreat;
- six complete finer-grid fixtures expose accepted `7:16 -> 8:16` retreat near 2.44 d;
- no MAXIT/BALTOL/forcing/threshold change is authorized.

## Purpose

Determine whether the late accepted physical retreat:

`7:16 -> 8:16`

is timestep-refined and reproducible on a complete late-horizon control ladder.

This workunit does not attempt disappearance and does not repair the failed coarse dt.

## Frozen fixtures

Use O05 persistent saturated-KLAG control:

- HEAD and RUNOFF entry families;
- dt:
  - 1.25e-4 d;
  - 6.25e-5 d;
  - 3.125e-5 d;
  - 1.5625e-5 d;
- horizon = 2.80 d;
- unchanged NLGLOB14N3 root-controller policy;
- unchanged NLGLOB14G/L dry forcing;
- unchanged zero bottom flux;
- physical mass as hard authority.

The first three dt levels are retained from the successful NLGLOB14Z evidence surface. The finest level is added only for refinement.

## Event definition

The late retreat exists only when accepted physical saturation geometry changes exactly:

`nodes 7:16 -> nodes 8:16`.

Both sides must be contiguous accepted saturated tails defined by:

- `h >= 0`;
- `theta == theta_s`.

No predictor-only crossing, fitted h/theta threshold or hysteresis is allowed.

## Required diagnostics

Per fixture:

- complete/finite/mass-clean status;
- last accepted 7:16 time;
- first accepted 8:16 time;
- exact pre/post saturated sets;
- any reverse 8:16 -> 7:16 move;
- any skipped/noncontiguous geometry;
- max interval and cumulative physical mass ledger.

## Frozen convergence gate

For each route family, compare the two finest accepted event times:

- dt = 3.125e-5 d;
- dt = 1.5625e-5 d.

Require:

`abs(t_event(dt3) - t_event(dt4)) <= 2 * dt_finest = 3.125e-5 d`.

Also require the finest event estimate to lie within the preceding coarser accepted event bracket.

Do not relax this threshold after exposure.

## Frozen classifications

If all 8 fixtures complete safely, expose the exact accepted retreat, and both route families pass the frozen refinement gate:

`QUALIFIED_LATE_RETREAT_EVENT_TIME_REFINEMENT`.

If all events are exposed but either route misses the convergence threshold:

`NLGLOB14Z1_LATE_RETREAT_TIME_NOT_REFINED`.

Any reverse, skipped or noncontiguous geometry:

`NLGLOB14Z1_LATE_RETREAT_STATE_INCONSISTENT`.

Any process or physical-mass failure:

`BLOCKED_NLGLOB14Z1_REFINEMENT`.

## Interpretation boundary

A positive result qualifies the late physical retreat on a complete refined control ladder and supports the interpretation that dt=2.5e-4 lies outside the stable late-horizon resolution range.

It does not qualify complete saturated-block disappearance.

A positive result authorizes a separately preregistered split-ownership test through `7:16 -> 8:16`.

## Stop rules

Do not:

- tune MAXIT/BALTOL;
- change forcing;
- alter physical thresholds;
- retry the failed coarse dt as a rescue route;
- modify production source.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z1

BASELINE: `8301ddb5db5e36b33831302f4b09668568944427`

BRANCH: `research/f-pe-nlglob14z1-late-retreat-refinement`

IMPLEMENTATION STATUS: preregistration only

NEXT SAFE STEP: run the four-level 2.80 d late-retreat refinement bank.

## Production boundary

Research only. No production source or default policy changes.
