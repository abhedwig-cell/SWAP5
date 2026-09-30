# F-PE-ELASTIC59 — accepted-but-unpaired oracle attribution result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch:
`research/f-pe-elastic59-unpaired-oracle-attribution`

Qualified postimage:
`666d26da25b273c98845f8981d842f8aa8360791`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36679561287`

Job:
`109771828179`

Conclusion:
SUCCESS.

## Question

Are the six accepted-but-unpaired ELASTIC58 cases merely blocked by an
insufficient nonlinear-iteration budget in the verification half-step solves?

## Frozen cases

All six cases are profile 8016, h0=-20 cm, accepted dt
`0.0009765625 day`.

Perturbations:
- +0.035 cm/day;
- +0.05 cm/day.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

The production-shaped full solve is unchanged from ELASTIC58.

## Oracle-only sensitivity

Half1/half2 verification solve max_iterations values:

- 16;
- 32;
- 64;
- 128.

All other solver, forcing, constitutive, boundary and tolerance settings were
held fixed.

## Primary result

All six cases remain unpaired at every tested oracle iteration budget.

Classification for every physical case:

`PERSISTENT_HALF_SOLVE_FAILURE`.

Aggregate:

- ORACLE_BUDGET_LIMIT: 0;
- PERSISTENT_HALF_SOLVE_FAILURE: 6;
- MIXED: 0;
- recovered paired observations: 0.

Therefore the ELASTIC58 coverage gap is not caused by a simple
max_iterations=16 ceiling.

## Failure localization

The failure is always in half1.

For every case and every oracle max_iterations value:

- full status = converged;
- half1 status = nonconverged;
- half2 is not executed because half1 did not converge.

The full solve remains invariant across all oracle sensitivity arms.

### delta = +0.035 cm/day

All three regimes:

- full nonlinear iterations: 5;
- half1 nonlinear iterations:
  - 16 at maxit=16;
  - 32 at maxit=32;
  - 64 at maxit=64;
  - 128 at maxit=128;
- half1 never converges.

Research Binf remains exactly:

`0.03768306882724545 cm`.

### delta = +0.05 cm/day

All three regimes:

- full nonlinear iterations: 4;
- half1 nonlinear iterations track the configured maximum exactly;
- half1 never converges through maxit=128.

Research Binf remains:

`0.03770126714044745 cm`.

## Regime independence

The failure pattern is identical for:
- OFF;
- FIXED_1E6;
- GENERATED.

At h0=-20 cm the initial state is unsaturated, so active saturated elastic
storage does not control this failure.

The coverage gap is therefore not an ELAS-regime-specific effect.

## Interpretation

ELASTIC58 showed that C-SAFE would accept these six points under the externally
derived Binf budget.

ELASTIC59 shows that their missing paired verification cannot be repaired by
simply allowing more Newton iterations in the half-step oracle.

The first half-step itself enters a persistent nonlinear failure path even as
the allowed iteration count is increased eightfold.

This is materially different from a verification harness that merely stops too
early.

The accepted full step and failed half step therefore inhabit different
nonlinear solvability regimes at the same forcing/state origin.

## Hypothesis outcome

Simple oracle iteration-budget limitation:
FALSIFIED.

Full-solve invariance across oracle sensitivity arms:
SUPPORTED.

Recovered paired oracle under maxit <=128:
NOT OBSERVED.

Physical head/theta envelope of recovered pairs:
NOT TESTABLE because no pair was recovered.

## Decision

Classification:

`QUALIFIED_PERSISTENT_HALF1_ORACLE_SOLVABILITY_GAP`.

No production change is authorized.

The six ELASTIC58 accepted-but-unpaired cases remain outside directly verified
physical-budget coverage.

The next bounded workunit should attribute the half1 failure mechanism itself,
including:
- residual reduction history;
- backtracking behavior;
- balance versus head convergence criteria;
- whether the smaller half-step crosses a retention/conductivity numerical
  regime that the full step avoids.

Until that mechanism is resolved or independently bounded, physical-budget
admission should remain fail-closed for these six cases.
