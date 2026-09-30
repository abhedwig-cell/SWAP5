# F-PE-ELASTIC66 — residual no-pair oracle attribution result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic66-no-pair-oracle-attribution`

Qualified postimage:
`12a0c94c5c7eab1c2860cf161844de25709e0e6e`

Canonical authority during qualification:
`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Workflow run:
`36723770839`

Job:
`109915260292`

Conclusion:
SUCCESS.

## Parent replay

The ELASTIC61 oracle hierarchy reproduced exactly:

- C-SAFE accepted: 96;
- exhausted: 96;
- three-level-qualified: 60;
- two-level-only recovered: 24;
- no-pair residual: 12.

Thus independent physical-oracle coverage remains 84/96 before this
attribution.

## Exact localization

All 12 no-pair cases are:

- profile 8016;
- h0 = -20 cm;
- accepted C-SAFE dt = 0.0009765625 day;
- four forcing perturbations: -0.05, -0.035, +0.035, +0.05 cm/day;
- repeated identically in OFF, FIXED_1E6 and GENERATED.

Regime counts:
- OFF: 4;
- FIXED_1E6: 4;
- GENERATED: 4.

This exact regime replication confirms that the residual oracle gap is not an
active elastic-storage effect on these unsaturated trajectories.

## Nested-level patterns

Reference levels were N = 2,4,8,16,32,64.

### Negative forcing

For delta = -0.05 and -0.035 cm/day in all three regimes:

`pattern = 100000`.

N=2:
- completes;
- independent mass ledger passes.

N=4,8,16,32,64:
- fail on the first substep;
- solver status = 2;
- maximum nonlinear iterations = 16.

Therefore these six cases have exactly one successful Reference level and cannot
form a consecutive two-level pair.

### Positive forcing

For delta = +0.035 and +0.05 cm/day in all three regimes:

`pattern = 000000`.

Every N=2,4,8,16,32,64 oracle:
- fails on the first substep;
- solver status = 2;
- reaches 16 nonlinear iterations.

No Reference refinement level is available.

## Relation to existing causal authority

The six positive-forcing cases are the same profile/state/regime/forcing and
N=2 substep duration already studied in the independent
ELASTIC60/61 total-balance postmortem/sensitivity line.

That line established causally that the N=2 half-step failure is controlled by
the solver-local total-balance convergence criterion:

- +0.035 cm/day requires a total-balance tolerance above the observed
  approximately 4.1693e-12 cm/day residual floor and first recovers at the
  preregistered 5e-12 arm;
- +0.05 cm/day first half-step recovers at 1.1e-12, while a complete two-half
  pair requires 5e-12;
- compartment residual remains below 1e-12;
- recovery is regime-independent;
- recovered pairs remain inside the unchanged physical head/theta envelope.

ELASTIC66 therefore does not reopen that positive-forcing attribution.

For the six negative-forcing cases, N=2 succeeds and N=4 is the first failing
level. Their N=4 failure mechanism has not yet been causally attributed.

## Hypotheses

H1, all 12 no-pair cases are profile 8016:
SUPPORTED.

H2, no-pair arises from at most one successful nested level:
SUPPORTED.
- six cases: one successful level, pattern 100000;
- six cases: zero successful levels, pattern 000000.

H3, regime independence:
SUPPORTED exactly.

## Decision

Classification:

`QUALIFIED_PROFILE8016_UNSATURATED_NO_PAIR_LOCALIZATION`.

The remaining independent-oracle blocker is now narrower than ELASTIC61:

1. six positive-forcing cases have an already-qualified
   solver-local total-balance convergence attribution at N=2;
2. six negative-forcing cases require attribution of the N=4 first-substep
   failure after a successful N=2 oracle.

No physical-budget failure was observed here.

No tolerance, alpha, controller, hard-mass gate or production source changed.

The next bounded workunit should examine only the six negative-forcing N=4
failures and determine whether their terminal residuals identify the same
solver-local total-balance representation floor or a different convergence
mechanism.
