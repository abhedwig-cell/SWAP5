# F-PE-NLGLOB14Z19 preregistration — bidirectional accepted-state ownership reclassification

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Parent research authority:

- NLGLOB14Z16: `QUALIFIED_EVENT_TERMINATED_SPLIT_RETREAT_12_TO_13`;
- NLGLOB14Z18: `QUALIFIED_Z18_POST_EVENT_UPPER_OWNERSHIP_BOUNDARY_ATTRIBUTION`;
- both fine split fixtures accept exact `12:16 -> 13:16`;
- the immediately following unchanged candidate converges, is finite, mass-clean and contiguous, but has exact paired tail `12:16`;
- the only failed gate is strict unsaturation of current upper-domain node 12;
- the candidate is not accepted in Z18.

## Purpose

Determine whether the exact post-event reverse candidate can be committed transaction-safely by explicit accepted-state ownership reclassification:

`13:16 -> 12:16`

with temporal ownership:

`face 12/13 -> face 11/12`.

Then characterize the immediate no-hysteresis behavior over a fixed short accepted-state window.

This is a research ownership-semantics test, not a production policy.

## Frozen fixtures

Use only the two fine split fixtures:

- HEAD, dt = `6.25e-5 d`;
- RUNOFF, dt = `6.25e-5 d`.

For each fixture:

1. reproduce the Z16 accepted `12:16 -> 13:16` event endpoint;
2. solve exactly one ordinary post-event candidate as in Z18;
3. require that candidate to be otherwise valid and have exact contiguous paired tail `12:16`;
4. explicitly reclassify ownership to face `11/12`;
5. commit that candidate as the next accepted state;
6. continue exactly 64 nominal accepted intervals with ordinary state-derived ownership and no hysteresis.

Execution transport may reuse the exact Z18 140 d checkpoint partition.

## Reverse-event acceptance gate

The reverse candidate may be committed only if all hold:

- solver/coupling converged;
- nonlinear residual <= `1e-10`;
- candidate finite;
- interval physical mass ledger <= `5e-8 cm`;
- rollback authority exact;
- provider-faithful dry top;
- paired saturation tail exactly `12:16`;
- candidate tail contiguous;
- the only previous Z18 rejection cause is ownership/domain exclusion;
- no skipped ownership face.

No threshold relaxation is allowed.

## Ownership semantics

Ownership is derived only from the accepted paired saturated tail.

For the reverse candidate:

- origin accepted tail: `13:16`;
- candidate accepted tail: `12:16`;
- origin ownership face: `12/13`;
- reclassified ownership face: `11/12`.

After committing the reverse event, every subsequent accepted interval independently derives ownership from its own accepted physical tail.

No hysteresis, dwell time, event delay or fitted threshold is allowed in Z19.

## Frozen 64-interval observation

Record every accepted tail and ownership change during exactly 64 nominal intervals after the committed reverse event.

### STABLE_REEXPANSION

Require:

- reverse event committed cleanly;
- no subsequent return to `13:16` in the 64-interval window;
- no additional ownership oscillation;
- state/mass/residual/provider gates remain valid.

### IMMEDIATE_BIDIRECTIONAL_CHATTER

Classify if the accepted tail returns to `13:16` and then re-expands to `12:16`, or otherwise oscillates across face 11/12 <-> 12/13, within the frozen window.

### SINGLE_REBOUND_TO_13

Classify if the reverse candidate is validly committed but accepted state returns once to `13:16` and remains there through the rest of the frozen window.

### OTHER_VALID_BIDIRECTIONAL_SEQUENCE

Any other contiguous one-face accepted-state sequence with all hard gates valid.

## Frozen aggregate classifications

If both fixtures classify `STABLE_REEXPANSION`:

`QUALIFIED_Z19_STABLE_BIDIRECTIONAL_REEXPANSION`.

If both classify `SINGLE_REBOUND_TO_13`:

`NLGLOB14Z19_SINGLE_REBOUND_TO_13`.

If either fixture exhibits repeated ownership oscillation:

`NLGLOB14Z19_BIDIRECTIONAL_CHATTER`.

If fixtures differ while remaining physically/transactionally valid:

`NLGLOB14Z19_MIXED_BIDIRECTIONAL_RESPONSE`.

Any mass/rollback/provider/nonlinear inconsistency:

`NLGLOB14Z19_TRANSACTION_OR_SOLVE_INCONSISTENT`.

Any noncontiguous or skipped-face accepted geometry:

`NLGLOB14Z19_GEOMETRY_INCONSISTENT`.

If the Z18 reverse candidate is not reproduced:

`NLGLOB14Z19_REVERSE_CANDIDATE_NOT_REPRODUCED`.

## Interpretation boundary

A positive stable result qualifies only local bidirectional accepted-state ownership semantics at this exact post-event phase.

A chatter result does not authorize hysteresis tuning. It would authorize a separate preregistered anti-chatter semantics study.

No result in Z19 authorizes production temporal ownership.

## Stop rules

Do not:

- alter dt;
- change forcing;
- tune solver tolerances;
- relax physical saturation definitions;
- fit a pressure/theta threshold;
- add hysteresis or dwell time;
- replay control event times;
- modify production source.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z19

BASELINE: `5a6e1437f55c3e13887e0051579a2caca5a73148`

BRANCH: `research/f-pe-nlglob14z19-bidirectional-reclassification`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: commit the exact Z18 reverse candidate by state-derived ownership reclassification, then observe 64 nominal intervals without hysteresis.

## Production boundary

Research only. No production source/default change.
