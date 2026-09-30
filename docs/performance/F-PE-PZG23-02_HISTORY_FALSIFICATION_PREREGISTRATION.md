# F-PE-PZG23-02 — accepted-history causal falsification

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@021abc51216909de90e992ee917838e3725da1ad`

Parent authority:
F-PE-PZG23-01.

## Purpose

Determine whether the accepted temporal-history carrier itself is causal for the
two localized pZg23 interval-B failures.

This workunit is diagnostic only.

It does not change production solver behavior, hard mass, the 0.20 cm
application budget, retry limits or balance tolerances.

## Frozen failing origins

Profile:
`90210030 / pZg23`.

Only the two PZG23-01 failures are exercised:

- origin 10: h0 = +2 cm, forcing delta = +0.035 cm/day;
- origin 11: h0 = +2 cm, forcing delta = +0.050 cm/day.

Configuration remains:

- exact frozen BRO/BOFEK geometry;
- exact Staringreeks retention;
- GENERATED ELAS;
- bottom_mode = 7;
- swkimpl = 0;
- RICHARDS_TEMPORAL_HISTORY;
- explicit caller-owned head budget = 0.20 cm;
- interval duration = 0.015625 day;
- max retries = 8;
- worker count = 1.

## Interval A

Run interval A exactly as production authority and require:

- complete;
- committed;
- complete mass publication.

Snapshot the accepted committed carrier after A.

The snapshot must be a
`fmr_b110_temporal_indicator_state_t`.

Extract:

- the full physical state;
- the accepted temporal-history right-derivative vector.

No solver scratch or candidate state is carried forward outside the admitted
committed carrier.

## Interval-B arms

For each failing origin execute exactly three B arms from the same accepted A
physical state.

### ARM_ORIGINAL

Use the original interval-A committed state unchanged.

Expected from PZG23-01:
FAIL.

### ARM_RECON_SAME_HISTORY

Reconstruct a fresh committed temporal-indicator state at t=dt using:

- identical physical pressure head;
- identical water content;
- identical ponding;
- identical groundwater level;
- exact accepted history vector from A.

This tests whether hidden solver/warm-start ownership outside the committed
carrier contributes to the failure.

### ARM_RECON_ZERO_HISTORY

Reconstruct the same physical state at t=dt but seed the temporal-history vector
with exact zeros of identical shape.

This changes only numerical continuation history.

It is a research falsification arm and is not an admissible production repair.

## Hypotheses

H1 — committed history is causal:

Supported if both ORIGINAL and RECON_SAME_HISTORY fail while
RECON_ZERO_HISTORY completes.

H2 — hidden solver/warm-start state is causal:

Supported only if ORIGINAL and RECON_SAME_HISTORY differ materially in
completion/solver route.

Because admitted transaction semantics do not persist solver scratch, this is a
falsification check rather than an expected mechanism.

H3 — physical accepted state / local nonlinear regime is causal:

Supported if all three arms fail with comparable failure signatures.

## Diagnostics

For each origin and arm record:

- completion/commit;
- kernel status;
- attempts;
- transaction retries;
- accepted substeps;
- nonlinear iterations;
- internal solver retries;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- final committed revision/time;
- mass completeness and residual.

Also require bitwise/equality checks for physical state and history where
reconstruction is intended to preserve them.

## Stop rule

PZG23-02 closes after causal classification.

Do not in this workunit:

- widen the 0.20 cm budget;
- alter retry count;
- alter nonlinear/backtracking limits;
- relax any tolerance;
- change ELAS parameters;
- implement a production repair.

Any repair must be preregistered separately after the causal arm result is
known.
