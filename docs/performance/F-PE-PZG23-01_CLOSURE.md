# F-PE-PZG23-01 — post-attribution closure

Date: 2026-09-30

Status: CLOSED_LOCALIZED_SECOND_INTERVAL_SOLVABILITY_BLOCKER

Canonical baseline:
`integration/f-ci-canonical@ebb7a9da9f2a2f31dae0b049d88d8bee8b2b89a2`

Research authority:
- branch: `research/f-pe-pzg23-01-second-interval-attribution`;
- qualified run: `36760892904`;
- job: `110042844371`;
- conclusion: SUCCESS.

## Closed claim

The SCHED02 pZg23 second-interval blocker is localized to exactly two of the
sixteen frozen origins:

1. h0 = +2 cm, forcing delta = +0.035 cm/day;
2. h0 = +2 cm, forcing delta = +0.05 cm/day.

All sixteen origins complete and commit interval A.

Fourteen of sixteen also complete and commit interval B.

The two failing cases remain at the valid interval-A committed revision/time and
terminate interval B with transaction-failed status after very large nonlinear
and backtracking work.

The stronger failure signatures are:

- +0.035: 20 attempts, 16 retries, 496 nonlinear iterations, 2899 backtracking attempts;
- +0.05: 22 attempts, 19 retries, 663 nonlinear iterations, 3698 backtracking attempts.

The failure is therefore classified as a localized wet/positive-forcing
continuation solvability blocker rather than a demonstrated hard-mass rejection
or parallel-runtime defect.

Classification:

`QUALIFIED_PZG23_WET_POSITIVE_FORCING_SECOND_INTERVAL_SOLVABILITY_BLOCKER`.

## Consequence for scheduling

SCHED02 remains blocked and no adaptive worker-count selector is admitted.

Do not remove pZg23 from the calibration set or fit a selector only to the
passing profiles.

## Closure boundary

No production source is changed.

No change is made to:

- the 0.20 cm application-owned temporal budget;
- hard mass;
- solver balance tolerances;
- GENERATED ELAS;
- mode-7 transaction semantics.

Any repair of the two failing origins belongs to a separate solver/continuation
workunit with its own preregistered causal hypothesis.
