# F-PE-SCHED02 — lagged solver-work worker-count selector result

Date: 2026-09-30

Status: BLOCKED_BY_SECOND_INTERVAL_SOLVABILITY

Branch:
`research/f-pe-sched02-lagged-work-selector`

Canonical baseline:
`integration/f-ci-canonical@f9133b92cd7d128838029a162ee607bb8ba69689`

Primary workflow run:
`36759269580`

Primary job:
`110037351860`

Primary conclusion:
FAIL.

## Question

Can already committed solver work from interval A be used as an immutable
pre-trial scalar predictor for choosing 1, 2 or 4 workers for interval B?

The preregistered predictor was:

`lagged_work = sum(interval_A.solver_headcalc_calls)`.

The selector was only eligible for qualification if all five frozen profile
batches completed both interval A and interval B under every worker alternative.

## Frozen batches

The five preregistered batches were:

- 9024010 / Hn21, N=363;
- 8060 / zEZ21, N=292;
- 9024090 / cHn21, N=202;
- 90210030 / pZg23, N=167;
- 8016 / EZg21, N=256.

All use the already admitted:

- GENERATED ELAS;
- bottom_mode=7;
- swkimpl=0;
- RICHARDS_TEMPORAL_HISTORY;
- explicit caller-owned 0.20 cm head budget.

## Results before the blocker

The first three frozen batches completed both intervals for 1/2/4 workers with
worker-invariant deterministic retry counts and zero mass failures.

Observed interval-A lagged HeadCalc work:

- Hn21: 1165;
- zEZ21: 904;
- cHn21: 617.

For interval B, all three of these batches showed a clear 2-worker timing
advantage over both 1 and 4 workers on the exercised CI host.

Examples from the completed runs:

### Hn21, N=363

Interval B median behavior was approximately:

- 1 worker: 0.064 s;
- 2 workers: 0.039 s;
- 4 workers: 0.053 s.

### zEZ21, N=292

Approximately:

- 1 worker: 0.051 s;
- 2 workers: 0.029 s;
- 4 workers: 0.040 s.

### cHn21, N=202

Approximately:

- 1 worker: 0.042 s;
- 2 workers: 0.024 s;
- 4 workers: 0.033 s.

The exact timings are descriptive only. The important result is that these
completed profile batches preserved worker-invariant physics/transaction
semantics.

## Blocking result

The preregistered pZg23 batch:

`profile 90210030, N=167`

successfully completed and committed interval A, but interval B failed to
complete for at least one column before the worker-selector comparison could be
qualified.

The failure occurred on the ordinary production transaction path after a valid
committed interval A.

This is not a worker-count-specific or OpenMP failure because the blocker was
already encountered before a complete 1/2/4 comparison could be established.

A follow-up diagnostic census was added on branch postimage
`cc94d6796918525597e1a0cdb51f0934a3cd141e` to expose all failing interval-B
columns without relaxing the fail-closed rule. At the time of closure that run
was queued and is not required to classify the scheduler result.

## Decision

The preregistered SCHED02 selector is not qualified.

Classification:

`LAGGED_HEADCALC_WORK_SELECTOR_BLOCKED_BY_PZG23_SECOND_INTERVAL_SOLVABILITY`.

This is not evidence that lagged HeadCalc work is a bad predictor.

It is evidence that the chosen five-profile two-interval calibration domain is
not yet a valid common domain for worker-selector qualification.

## Important separation

Do not:

- weaken the 0.20 cm application budget to make pZg23 pass;
- change solver tolerances;
- remove pZg23 after observing the failure;
- fit a selector from only the three passing profiles;
- interpret the failure as a worker-count problem;
- use post-trial interval-B work to choose interval-B workers.

## Successor boundary

Any investigation of the pZg23 second-interval failure is a separate numerical
continuation/solvability workunit.

Only after that profile has a valid accepted two-interval production path would
it be legitimate to reopen lagged-work selector qualification.

No production scheduler change follows from SCHED02.
