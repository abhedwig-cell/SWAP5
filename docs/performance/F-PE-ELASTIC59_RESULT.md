# F-PE-ELASTIC59 — refined-oracle solvability attribution result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic59-oracle-solvability`

Qualified postimage:
`9cb27522088b313f8acf705cbc5925dc8b9a8818`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36694351300`

Job:
`109818635698`

Conclusion:
SUCCESS.

## Question

Why did the fixed N=32 Reference oracle fail for 54 ELASTIC58 accepted points,
all in unsaturated states?

## Frozen replay

ELASTIC59 reproduced the ELASTIC58 controller decisions exactly:

- accepted C-SAFE sequences: `96`;
- exhausted sequences: `96`.

The same four profiles, materialization, states, forcing, regimes, Binf
threshold, solver and tolerances were retained.

## Oracle substep-count sweep

Every accepted point was evaluated with fixed-substep Reference oracles at
N = 4, 8, 16, 32 and 64.

Aggregate completion:

| N | complete | failed |
|---:|---:|---:|
| 4 | 84 | 12 |
| 8 | 60 | 36 |
| 16 | 54 | 42 |
| 32 | 42 | 54 |
| 64 | 6 | 90 |

The ELASTIC58 N=32 count reproduced exactly:
- complete: `42`;
- unavailable: `54`.

The highest coverage is therefore at N=4, not at the finest oracle.

## Main attribution

Refinement-driven oracle failure is caused by small-substep solver solvability.

The completion rate decreases monotonically as N increases.

At N=32:
- 48 of the 54 failed oracles fail already at substep 1;
- 3 fail at substep 20;
- 3 fail at substep 32.

At N=64:
- 60 of 90 failures occur at substep 1.

This is direct evidence that the principal blocker is not accumulated trajectory
drift after many successful substeps. In most failed fine-oracle cases, the
first very small Reference substep itself does not converge.

## Regime independence

For every accepted unsaturated physical state/forcing combination for which all
three regimes enter the oracle sweep, the complete/fail pattern over
N=4/8/16/32/64 is identical for:

- OFF;
- FIXED_1E6;
- GENERATED.

Observed regime-pattern comparisons:
- same: `32 / 32`;
- different: `0 / 32`.

Examples include:
- `TTTTT`;
- `TTTTF`;
- `TTTFF`;
- `TTFFF`;
- `TFFFF`;
- `FFFFF`.

This falsifies an ELAS-specific explanation for the refined-oracle coverage
problem.

## Profile dependence

### profile 11060

- N=4: 24/24;
- N=8: 24/24;
- N=16: 24/24;
- N=32: 21/24;
- N=64: 3/24.

### profile 10260

- N=4: 24/24;
- N=8: 12/24;
- N=16: 12/24;
- N=32: 9/24;
- N=64: 0/24.

### profile 8016

- N=4: 12/24;
- N=8: 9/24;
- N=16: 6/24;
- N=32: 0/24;
- N=64: 0/24.

### profile 3030

- N=4: 24/24;
- N=8: 15/24;
- N=16: 12/24;
- N=32: 12/24;
- N=64: 3/24.

The effect is therefore strongly material/profile dependent.

## Successful-oracle refinement

Where successive oracle levels both complete, their terminal differences are
small and generally halve with N.

Representative examples:

profile 11060, h0=-75, delta=-0.05:
- N4->N8: max |dh| = `4.69e-6 cm`;
- N8->N16: `2.35e-6 cm`;
- N16->N32: `1.17e-6 cm`;
- N32->N64: `5.87e-7 cm`.

profile 11060, h0=-20, delta=-0.05:
- N4->N8: `6.40e-5 cm`;
- N8->N16: `3.29e-5 cm`;
- N16->N32: `1.67e-5 cm`.

Thus where refinement is solvable, the fixed-substep oracle shows regular
convergence behavior.

The problem is not lack of refinement convergence. It is loss of nonlinear
solvability once substeps become too small for parts of the current Reference
solver/configuration envelope.

## Hypothesis outcome

H1, oracle unavailability is controlled by small-substep solver solvability:
SUPPORTED.

H2, failure locations are similar across ELAS regimes:
SUPPORTED strongly; all 32 comparable unsaturated pattern groups are identical.

H3, a coarser oracle level provides better coverage than N=32:
SUPPORTED.
N=4 provides 84/96 coverage versus 42/96 for N=32.

H4, successful successive oracle levels show decreasing refinement differences:
SUPPORTED in the observed nested successful sequences.

## Interpretation

ELASTIC58's oracle-coverage blocker is a property of the present refined-oracle
construction, not evidence that the C-SAFE physical budget is invalid.

A fixed finer N is not automatically a better Reference oracle in this domain.
Beyond a material/state-dependent point, further subdivision reduces solver
solvability.

Therefore a usable independent oracle for this line should be adaptive in
refinement level and require demonstrated nested convergence rather than a
hard-coded N=32 or N=64.

## Decision

Classification:

`QUALIFIED_SMALL_SUBSTEP_ORACLE_SOLVABILITY_LIMIT`.

No solver tolerance or production policy change is authorized.

The next bounded workunit should construct an adaptive nested oracle using the
highest pair of successful refinement levels and an explicit refinement-error
criterion tied to the existing 0.01-cm physical budget.

That oracle must fail closed when no sufficiently converged nested pair exists.
