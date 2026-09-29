# F-PE-ELASTIC47 — ELAS × timestep interaction result

Date: 2026-09-29

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch:
`research/f-pe-elastic47-timestep-interaction`

Qualified postimage:
`abb78ff45d9a3aa8bfc5754bbb52f70a26d508ea`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36621521366`

Job:
`109587824107`

Conclusion:
SUCCESS.

## Question

Does physically parameterized ELAS move the largest production Reference/full-half
interval that completes under the difficult saturated perturbations observed in
ELASTIC46?

Compared regimes:
- `OFF`;
- `FIXED_1E6`;
- `GENERATED`.

Frozen matrix:
- heads: `+0.1, +2, +10 cm`;
- perturbations: `+0.05, -0.05, +0.025, -0.025 cm/day`;
- durations: `0.25, 0.125, 0.0625, 0.03125, 0.015625 day`;
- three regimes;
- total `180` cases.

The same real BRO profile, generated prior, 16-node variable grid, hydraulic
fixture and Reference/full-half numerical settings as ELASTIC46 were preserved.

## Primary result

`0 / 180` perturbation cases completed and committed.

No regime completed even the smallest frozen interval:
`dt = 0.015625 day = 22.5 minutes`.

Therefore the completion threshold is not bracketed by the preregistered ladder
for:
- any saturated head;
- either forcing direction;
- either perturbation magnitude;
- any ELAS regime.

Classification:

`NO_COMPLETION_THRESHOLD_WITHIN_FROZEN_LADDER`.

This is a qualified negative result. It means timestep reduction over the tested
factor-16 range is insufficient to turn the ELASTIC46 perturbation failures into
accepted production intervals.

It does **not** establish that no sufficiently small timestep can complete.

## Numerical-work interaction remains real

Although completion did not change, ELAS materially changes work-to-failure.

Across the five-duration ladder, examples include:

### h0 = 10 cm, delta = -0.05 cm/day

OFF totals:
- nonlinear: `720`;
- retries: `45`;
- backtracking: `4230`;
- HeadCalc: `45`.

FIXED_1E6:
- nonlinear: `512`;
- retries: `9`;
- backtracking: `927`;
- HeadCalc: `122`.

GENERATED:
- nonlinear: `474`;
- retries: `9`;
- backtracking: `1064`;
- HeadCalc: `125`.

GENERATED therefore reduces summed nonlinear work by about 34% and summed
backtracking by about 75% relative to OFF, while still failing all five
durations.

### h0 = 10 cm, delta = +0.025 cm/day

OFF:
- nonlinear `1058`;
- retries `26`;
- backtracking `2756`.

FIXED_1E6:
- nonlinear `635`;
- retries `23`;
- backtracking `1392`.

GENERATED:
- nonlinear `477`;
- retries `11`;
- backtracking `1154`.

Again the work reduction is large but does not change the accept/reject outcome.

### h0 = 2 cm, delta = -0.05 cm/day

OFF:
- nonlinear `720`;
- retries `45`;
- backtracking `4230`.

FIXED_1E6:
- nonlinear `502`;
- retries `15`;
- backtracking `820`.

GENERATED:
- nonlinear `590`;
- retries `11`;
- backtracking `1018`.

The generated and fixed-`1e-6` cases remain numerically distinct.

## Smallest-duration evidence

At `dt=0.015625 day`, substantial solver work is still performed.

For `h0=10 cm, delta=-0.05`:

OFF:
- nonlinear `144`;
- retries `9`;
- backtracking `846`;
- HeadCalc `9`.

FIXED_1E6:
- nonlinear `130`;
- retries `2`;
- backtracking `297`;
- HeadCalc `24`.

GENERATED:
- nonlinear `119`;
- retries `3`;
- backtracking `319`;
- HeadCalc `24`.

For `h0=2 cm, delta=-0.05`:

OFF:
- nonlinear `144`;
- retries `9`;
- backtracking `846`.

FIXED_1E6:
- nonlinear `125`;
- retries `5`;
- backtracking `291`.

GENERATED:
- nonlinear `146`;
- retries `4`;
- backtracking `340`.

This rules out a simple claim that the ELASTIC46 failure was caused only by an
overly large requested interval.

## Hypotheses

H1, ELAS shifts the completion threshold in at least part of the frozen matrix:
NOT SUPPORTED within the tested duration range.

H2, threshold shift is state/forcing dependent:
NOT TESTABLE because no threshold was bracketed.

H3, GENERATED and FIXED_1E6 are not interchangeable:
SUPPORTED by materially different work-to-failure patterns.

H4, an ELAS threshold shift translates into matched end-to-end timing benefit:
NOT TESTABLE because no state/forcing pair had a common completed perturbed
duration.

## Timing

The preregistered matched timing rule correctly produced no timing result:

`ELASTIC47_TIMING_PAIR_COUNT=0`.

No failed interval was timed and presented as successful production runtime.

## Gates

- A1 generated prior preserved from ELASTIC46: PASS;
- A2 all 180 cases executed and retained: PASS;
- A3 completed-case hard mass gate: vacuously preserved because no perturbed
  case completed;
- A4 deterministic frozen-ladder threshold extraction: PASS;
- A5 no regime-specific tuning: PASS;
- A6 matched timing rule applied, zero eligible pairs: PASS;
- A7 O0/O2 non-timing classification and counters: PASS;
- A8 zero `src/**` production change: PASS.

## Interpretation

ELASTIC46 identified a large ELAS × solver-work interaction.
ELASTIC47 shows that ordinary requested-interval reduction by a factor 16 does
not convert that interaction into accepted intervals.

The next question is therefore no longer "how small must dt be?" as the first
attribution step.

The failure must first be decomposed to identify whether the dominant blocker is:
- repeated nonlinear solver rejection;
- full-half temporal acceptance/reconciliation;
- a saturated/unsaturated branch transition;
- boundary-mode behavior;
- or another transaction-level acceptance condition.

Opening a still-finer timestep sweep before that attribution would be poorly
targeted and could only move an unbounded threshold search.

## Decision

Classification:
`QUALIFIED_NEGATIVE_TIMESTEP_INTERACTION_RESULT`.

No production change is authorized.

The next bounded workunit should be observational failure attribution on the
smallest-duration difficult cases, preserving the same equations, solver,
tolerances, transaction policy, grid and ELAS regimes.
