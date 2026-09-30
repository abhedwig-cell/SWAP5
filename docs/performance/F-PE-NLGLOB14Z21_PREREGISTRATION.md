# F-PE-NLGLOB14Z21 preregistration — fine-fixture bidirectional persistence to 13:16 -> 14:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Parent research authority:

- NLGLOB14Z20: `QUALIFIED_Z20_FINITE_TRANSIENT_BIDIRECTIONAL_CHATTER`;
- both fine fixtures show exactly five alternating ownership changes after the first reverse event;
- no ownership change recurs after offset 5 through offset 4096;
- final accepted tail is `13:16`;
- NLGLOB14Z17F restores four-fixture control authority for exact physical retreat `13:16 -> 14:16` near 514.662-514.665 d.

## Purpose

Determine whether unchanged exact accepted-state bidirectional split ownership remains stable over the long interval from the self-settled post-chatter phase to the independently established next physical retreat:

`13:16 -> 14:16`.

This workunit tests only the two fine fixtures in which bidirectional ownership is required.

## Frozen fixtures

Use O05:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 6.25e-5 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged split-domain solve;
- provider-faithful dry top;
- no fitted event timing.

## Execution transport

Use exact accepted-state checkpoint transport.

1. segment A: origin -> 140.0 d using the already-qualified retreat-only split trajectory;
2. exact checkpoint at 140.0 d, tail `12:16`;
3. segment B: 140.0 d -> 330.0 d using exact state-derived bidirectional ownership;
4. exact checkpoint at 330.0 d;
5. segment C: 330.0 d -> first accepted `13:16 -> 14:16`, with an execution cap of 520.0 d.

The 330 and 520 d times are infrastructure bounds only and do not define physical event timing.

## Bidirectional ownership semantics

For every accepted interval after 140 d:

- derive candidate paired saturated tail exactly from `h >= 0` and `theta == theta_s`;
- require contiguous tail;
- permit one-face retreat or one-face re-expansion;
- candidate ownership is the face implied by that candidate accepted tail;
- accept only when solve, mass, residual, provider and transaction gates pass.

No hysteresis, dwell time, direction lock, event suppression, fitted threshold or control-time trigger.

## Checkpoint gates

At both checkpoints require:

- h bit-exact roundtrip;
- theta bit-exact roundtrip;
- saturated tail preserved exactly;
- ownership preserved exactly;
- event history/counters preserved;
- mass/residual/rollback maxima preserved;
- no synthetic interface event on restore.

## Required diagnostics

Per fixture record:

- all ownership changes after 140 d;
- recurrence count after the initial finite chatter burst;
- any reverse/re-retreat episodes;
- exact target event time if reached;
- pre/post target tails;
- final/checkpoint tails;
- max interval mass ledger;
- max residual;
- rollback;
- provider routes;
- skipped/noncontiguous geometry;
- accepted interval counts.

## Frozen classifications

If the trajectory reaches exact accepted:

`13:16 -> 14:16`

before 520 d, with no late ownership recurrence after the known offset-5 transient and all hard gates valid:

`QUALIFIED_Z21_FINE_BIDIRECTIONAL_PERSISTENCE_TO_14`.

If later ownership changes recur after the Z20 transient but remain valid:

`NLGLOB14Z21_LATE_BIDIRECTIONAL_RECURRENCE`.

If the target event is not reached by 520 d despite a valid trajectory:

`NLGLOB14Z21_TARGET_NOT_REACHED`.

If a noncontiguous or skipped-face state occurs:

`NLGLOB14Z21_GEOMETRY_INCONSISTENT`.

If solve/mass/rollback/provider gates fail:

`NLGLOB14Z21_TRANSACTION_OR_SOLVE_INCONSISTENT`.

## Aggregate interpretation

If both fine fixtures qualify:

`QUALIFIED_Z21_FINE_BIDIRECTIONAL_LONG_HORIZON`.

If either has late recurrence:

`NLGLOB14Z21_FINE_LONG_HORIZON_RECURRENCE`.

If fixtures otherwise differ while valid:

`NLGLOB14Z21_MIXED_FINE_LONG_HORIZON`.

## Consequence

A positive result establishes that the exact no-hysteresis bidirectional semantics self-settle and persist to the next physical retreat in the fine fixtures.

It would authorize a separate four-fixture event-terminated split qualification for `13:16 -> 14:16`, combining the fine bidirectional path with coarse fixtures.

It does not authorize production ownership, disappearance or TG re-entry.

## Production boundary

Research only. No production source/default change.
