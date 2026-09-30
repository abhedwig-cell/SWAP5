# F-PE-SCHED02 — lagged solver-work worker-count selector

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@f9133b92cd7d128838029a162ee607bb8ba69689`

Parent authority:
- F-PE-SCHED01: size-only worker-count policy falsified;
- F-PE-MULTI06: GENERATED mode-7 in-process worker pool admitted;
- F-PE-MULTI07: worker semantics preserved but small cheap batches prefer one worker.

## Purpose

Test whether an immutable lagged solver-work metric can select worker count for
the next accepted interval better than column count alone.

## Predictor

For interval A:

- execute with worker_count=1;
- commit the interval normally;
- sum `solver_headcalc_calls` over all accepted columns.

Define:

`lagged_work = sum(interval_A.solver_headcalc_calls)`.

The worker choice for interval B may use only this already committed value.

No interval-B trial result, retry count, wall time or solver state may
participate in the choice.

## Frozen batches

Evaluate five geometry-homogeneous GENERATED ELAS mode-7 batches:

1. profile 9024010 / Hn21, N=363;
2. profile 8060 / zEZ21, N=292;
3. profile 9024090 / cHn21, N=202;
4. profile 90210030 / pZg23, N=167;
5. profile 8016 / EZg21, N=256.

The first four are exactly the MULTI07 source-weighted profile batches.
Profile 8016 is the pre-existing difficult MULTI06/SCHED01 discriminator.

For every batch:

- exact profile geometry;
- exact Staringreeks retention;
- GENERATED ELAS;
- bottom_mode=7;
- swkimpl=0;
- RICHARDS_TEMPORAL_HISTORY;
- explicit caller-owned head budget=0.20 cm;
- interval duration=0.015625 day;
- max retries=8;
- same deterministic sixteen h0/forcing combinations.

Interval B uses the committed state produced by interval A and the same forcing
ownership.

## Worker alternatives for interval B

Evaluate exactly:

- 1 worker;
- 2 workers;
- 4 workers.

Each worker alternative runs in a fresh process, so interval A is reconstructed
identically before interval B.

Run five repetitions for every batch/worker alternative.

Use median interval-B wall time.

Measured winner:
the smallest worker count within 5% of the minimum median interval-B time.

## Correctness gates

For each batch and worker alternative:

1. interval A completes and commits all columns;
2. interval B completes and commits all columns;
3. interval-A lagged_work is identical across repetitions and B-worker alternatives;
4. interval-B deterministic retry count is identical across worker alternatives;
5. mass failures = 0;
6. rejected columns = 0;
7. aggregate mass publication complete;
8. multiworker B runs demonstrate real physical concurrency;
9. production source delta = empty.

## Selector test

Sort the five batches by ascending `lagged_work`.

If measured winning worker count is nondecreasing in that order, construct the
simplest step selector:

- choose 1 below the first 1->2 transition;
- choose 2 until a 2->4 transition if present;
- choose 4 above it.

Each threshold is the geometric mean of the adjacent observed lagged_work
values around the transition.

If winner order is non-monotone with lagged_work, reject scalar lagged
HeadCalc work as a worker-count selector.

## Scope

Any successful selector is bounded to the qualified GENERATED ELAS mode-7
profile class and current 1/2/4-worker runtime.

It is not a physics parameter and is not persistent committed SWAP state.
