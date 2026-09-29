# F-PE-ELASTIC48 — smallest-duration failure attribution result

Date: 2026-09-29

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic48-failure-attribution`

Qualified postimage:
`c03eee8895443bb6f9a62e3fb6aa3932ab45206f`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36622101272`

Job:
`109589785440`

Conclusion:
SUCCESS.

## Question

Why do the ELASTIC47 difficult saturated perturbations still fail at
`dt = 0.015625 day` even though active ELAS often reduces nonlinear work
substantially?

## Attribution bank

Twelve frozen cases:
- `h0 = 2 cm` and `10 cm`;
- delta `+0.05` and `-0.05 cm/day`;
- OFF, FIXED_1E6 and GENERATED;
- fixed `dt = 0.015625 day`.

The admitted serialized Reference backend was called directly from a captured
checkpoint. Existing kernel/backend diagnostics only were observed.

No production source or numerical policy changed.

## Primary result

The failure mechanism is not one uniform rejection class.

ELAS changes the rejection composition.

Across all cases:
- no admission rejection;
- no checkpoint rejection;
- no mass rejection;
- no temporal-certificate-unavailable rejection;
- solver executed in every case;
- candidate never became ready;
- final kernel status remained transaction failure.

The two relevant rejection classes are:
- nonlinear solver rejection;
- full-half temporal rejection.

## OFF behavior

For negative perturbations, OFF is completely solver-dominated.

### h0 = 2 cm, delta = -0.05

- attempts: 9;
- solver rejections: 9;
- temporal rejections: 0;
- nonlinear iterations: 144;
- internal retries: 9;
- backtracking: 846;
- route: `legacy-reference-retry`.

### h0 = 10 cm, delta = -0.05

Identical rejection composition:
- solver rejections: 9;
- temporal rejections: 0;
- nonlinear iterations: 144;
- internal retries: 9;
- backtracking: 846.

Thus the default-off route never gets far enough for temporal acceptance to
become the active limiter in these negative-perturbation cases.

## ELAS behavior

With active ELAS, many attempts that previously failed in the nonlinear solve
reach the temporal acceptance layer.

### h0 = 2 cm, delta = -0.05

FIXED_1E6:
- solver rejections: 5;
- temporal rejections: 4;
- nonlinear iterations: 125;
- internal retries: 5;
- backtracking: 291.

GENERATED:
- solver rejections: 4;
- temporal rejections: 5;
- nonlinear iterations: 146;
- internal retries: 4;
- backtracking: 340.

GENERATED therefore crosses the attribution boundary: temporal rejection is
already the plurality rejection class.

### h0 = 10 cm, delta = -0.05

FIXED_1E6:
- solver rejections: 2;
- temporal rejections: 7;
- nonlinear iterations: 130;
- internal retries: 2;
- backtracking: 297;
- final observed route: `legacy-reference-bound`.

GENERATED:
- solver rejections: 3;
- temporal rejections: 6;
- nonlinear iterations: 119;
- internal retries: 3;
- backtracking: 319;
- final observed route: `legacy-reference-bound`.

This is the strongest attribution result.

At the strongly saturated negative-perturbation state, ELAS removes most
nonlinear solver failures. The transaction still fails because the dominant
remaining blocker becomes temporal acceptance.

## Positive perturbations

The same transition is present but less clean.

### h0 = 2 cm, delta = +0.05

All regimes:
- attempts: 9;
- 8 solver rejections;
- 1 temporal rejection.

ELAS changes work but not rejection composition materially.

### h0 = 10 cm, delta = +0.05

OFF:
- solver rejections: 6;
- temporal rejections: 3;
- nonlinear iterations: 221;
- backtracking: 620.

FIXED_1E6:
- solver rejections: 4;
- temporal rejections: 5;
- nonlinear iterations: 113;
- backtracking: 223.

GENERATED:
- solver rejections: 4;
- temporal rejections: 5;
- nonlinear iterations: 128;
- backtracking: 436.

Again, once strongly saturated, active ELAS moves the limiting mechanism away
from purely nonlinear failure toward the temporal gate.

## Excluded mechanisms

The observed failures are not caused by:
- source/profile admission;
- checkpoint lineage;
- missing temporal certificate;
- mass rejection;
- missing solver execution.

All corresponding diagnostic counters are zero in all 12 cases.

## Hypotheses

H1, failure is dominated by solver rejection before mass acceptance:
PARTLY SUPPORTED for OFF and the weaker positive cases, but not for strongly
saturated active-ELAS cases.

H2, failure is not primarily a full-half temporal rejection:
FALSIFIED for active ELAS at the strongest saturated cases.

H3, ELAS changes work but not dominant rejection classification:
FALSIFIED.

ELAS changes both work and the active limiting layer.

## Interpretation

ELASTIC46 showed that ELAS can strongly reduce nonlinear work.
ELASTIC47 showed that a factor-16 timestep reduction still did not yield an
accepted perturbed interval.
ELASTIC48 explains why these statements coexist.

The chain is:

`OFF`
-> many nonlinear solver failures
-> transaction fails before temporal acceptance can dominate.

`ELAS active`
-> fewer nonlinear solver failures
-> more attempts reach full-half comparison
-> temporal rejection becomes the dominant remaining blocker in strongly
   saturated cases.

Therefore a further blind timestep sweep or another generic nonlinear-solver
optimization is not the best next step for the active-ELAS route.

The next bounded work should attribute the full-half temporal rejection itself:
- actual temporal indicator/error magnitude;
- full-versus-half state discrepancy;
- which state components dominate;
- whether the discrepancy is primarily physical elastic-storage response or a
  transaction acceptance-policy mismatch.

No temporal tolerance or timestep policy should be changed before that
observation.

## Decision

Classification:
`QUALIFIED_ELAS_SOLVER_TO_TEMPORAL_LIMITER_TRANSITION`.

No production change is authorized.

The next safe workunit is observational temporal-rejection attribution on the
active-ELAS strongly saturated cases.
