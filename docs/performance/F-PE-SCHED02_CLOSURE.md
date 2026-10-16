# F-PE-SCHED02 — post-result closure

Date: 2026-09-30

Status: CLOSED_BLOCKED_BY_SECOND_INTERVAL_SOLVABILITY

Canonical baseline:
`integration/f-ci-canonical@f9133b92cd7d128838029a162ee607bb8ba69689`

Research authority:
- branch: `research/f-pe-sched02-lagged-work-selector`;
- result commit: `c61428abc64c65ced97ffafc89f527972cd5fdc3`;
- primary workflow run: `36759269580`;
- primary job: `110037351860`;
- result: FAIL-CLOSED.

## Closed question

SCHED02 tested whether committed interval-A solver work,

`lagged_work = sum(solver_headcalc_calls)`,

could be used as immutable pre-trial input for selecting 1, 2 or 4 workers for
interval B.

The selector was only admissible if all five frozen profile batches completed
both intervals.

## What succeeded

The first three frozen profile batches completed interval A and interval B under
all worker alternatives with:

- worker-invariant deterministic retry counts;
- complete commits;
- zero mass failures;
- real multiworker concurrency.

Their interval-B timing consistently favored 2 workers on the exercised CI host.

## Blocker

The preregistered profile:

`90210030 / pZg23, N=167`

completed and committed interval A, but at least one column failed to complete
interval B on the ordinary production transaction path.

Therefore the common two-interval calibration domain is not valid.

Classification:

`LAGGED_HEADCALC_WORK_SELECTOR_BLOCKED_BY_PZG23_SECOND_INTERVAL_SOLVABILITY`.

## Governance consequence

No worker selector is admitted from SCHED02.

Do not:

- remove pZg23 after observing the failure;
- fit a selector from only the passing profiles;
- weaken the temporal budget or hard mass;
- change solver tolerances to obtain scheduler evidence;
- interpret the blocker as a parallel-runtime defect.

## Roadmap consequence

The scheduling line now has two separate established facts:

1. SCHED01:
   column count alone is insufficient for worker-count selection.

2. SCHED02:
   lagged committed solver work is a plausible next abstraction, but the current
   five-profile calibration domain is blocked by a second-interval solvability
   defect in pZg23.

Any pZg23 continuation investigation belongs to a separate numerical workunit.
Only after a valid two-interval domain exists should lagged-work selector
qualification be reopened.

## Closure

F-PE-SCHED02 is closed at a real blocker.

No production source change follows from this workunit.
