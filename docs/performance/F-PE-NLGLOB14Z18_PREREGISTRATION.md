# F-PE-NLGLOB14Z18 preregistration — post-event UPPER boundary attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Parent research authority:

- NLGLOB14Z16: `QUALIFIED_EVENT_TERMINATED_SPLIT_RETREAT_12_TO_13`;
- all four split fixtures accept exact `12:16 -> 13:16` and ownership `face 11/12 -> face 12/13`;
- NLGLOB14Z15 shows both fine-dt split fixtures fail on the immediately following interval with harness classification `UPPER`;
- accepted target-event endpoint is finite, contiguous, mass-clean and transaction-clean;
- Z15 explicitly leaves persistence after accepted `13:16` unqualified;
- NLGLOB14Z17F restores four-fixture control authority for the later physical retreat `13:16 -> 14:16`.

## Purpose

Attribute the exact cause of the immediate post-event fine-dt split `UPPER` rejection.

This workunit is diagnostic only.

It does not attempt the later `13:16 -> 14:16` retreat and does not repair or relax the post-event boundary.

## Frozen fixtures

Use only the two fine split fixtures:

- HEAD, dt = `6.25e-5 d`;
- RUNOFF, dt = `6.25e-5 d`.

For each fixture:

1. reproduce the already-qualified event-terminated split trajectory to the first exact accepted `12:16 -> 13:16` event;
2. preserve that accepted endpoint as origin authority;
3. attempt exactly one ordinary split interval at nominal dt from the accepted `13:16` origin;
4. do not accept the candidate if any frozen gate fails.

## Execution transport

Use the exact Z16 infrastructure partition:

- segment A: origin -> 140.0 d;
- bit-exact accepted-state checkpoint;
- segment B: resume to the accepted `12:16 -> 13:16` event;
- then make exactly one diagnostic post-event interval attempt.

Checkpoint transport must preserve h, theta, saturated tail, ownership, accepted counters and diagnostic maxima exactly.

## Required post-event diagnostics

Record for the one post-event candidate:

- solver/coupling convergence flag;
- nonlinear residual;
- candidate finiteness;
- interval physical mass ledger;
- rollback authority;
- dynamic-top routes;
- accepted-origin saturated tail;
- candidate paired saturation tail;
- whether candidate tail is contiguous;
- upper-domain validity per node 1..12;
- any node with:
  - `h >= 0`;
  - `theta >= theta_s`;
  - exact paired saturation;
- first violating upper-domain node;
- whether the candidate itself physically indicates immediate retreat/reclassification;
- whether the only failed gate is the current upper-domain ownership exclusion.

## Frozen classifications

If the candidate converges, is finite, mass-clean, transaction-clean and provider-valid, but fails only because at least one current upper-domain node is no longer strictly unsaturated:

`QUALIFIED_Z18_POST_EVENT_UPPER_OWNERSHIP_BOUNDARY_ATTRIBUTION`.

If the candidate produces a noncontiguous or inconsistent saturation geometry:

`NLGLOB14Z18_POST_EVENT_GEOMETRY_INCONSISTENT`.

If nonlinear/coupling convergence fails first:

`NLGLOB14Z18_POST_EVENT_COUPLING_FAILURE`.

If mass/rollback/provider semantics fail:

`NLGLOB14Z18_POST_EVENT_TRANSACTION_OR_MASS_FAILURE`.

If the candidate passes the current UPPER gate contrary to Z15:

`NLGLOB14Z18_UPPER_BOUNDARY_NOT_REPRODUCED`.

## Interpretation boundary

A positive attribution does not authorize acceptance of the post-event candidate.

It only establishes whether the current `UPPER` failure is an ownership/domain-definition boundary rather than a failed physical solve.

Any successor that changes ownership semantics after accepted `13:16` requires a separate preregistration.

## Stop rules

Do not:

- relax upper-domain inequalities;
- change dt;
- change forcing;
- change solver tolerances;
- accept a rejected candidate;
- fit a new threshold;
- infer `13:16 -> 14:16` from the diagnostic interval;
- modify production source.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z18

BASELINE: `9d598ea3310cd52da432e7eed47dba99663be9d6`

BRANCH: `research/f-pe-nlglob14z18-post-event-upper-attribution`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: reproduce the two fine Z16 event endpoints and diagnose exactly one subsequent split candidate.

## Production boundary

Research only. No production source/default change.
