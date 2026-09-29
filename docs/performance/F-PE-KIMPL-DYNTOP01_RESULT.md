# F-PE-KIMPL-DYNTOP01 result — fully implicit dynamic-top nonlinear-path attribution

Date: 2026-09-29

Status: `ITERATION_BUDGET_EXHAUSTION_UNDER_DYNTOP_STIFFNESS`

Authority:

- canonical base: `integration/f-ci-canonical@199566655db5b13483194e16bb81a154f6fc2547`;
- Actions run: `36517766221`;
- trace job: `109243779832`;
- conclusion: SUCCESS.

## B01/WET

First failing KIMPL step:

`step 7`.

Previous step 6 converges normally.

At failing step 7:

- iteration 1 max residual ~24.43;
- iterations 1-4 contract normally;
- near the surface transition, iterations 5 and 6 require line-search reduction to factor 1/3;
- iteration 7:
  - max residual ~5.11e-8;
  - max head update ~5.11e-2 cm;
- iteration 8:
  - max residual ~1.70e-13;
  - total residual ~3.63e-13;
  - max head update ~1.59e-8 cm;
  - nonlinear status still nonconverged only because the final acceptance criteria are not all met before MAXIT=8.

There is no residual blow-up at termination and no balance-floor stall.

The route becomes strongly nonlinear as the top head crosses from negative toward positive values. Two damped Newton updates are needed, after which convergence resumes.

## O14/WET

First KIMPL step fails immediately at:

`step 1`.

The nonlinear path is monotone:

- no line-search reduction;
- every full Newton step makes progress;
- max residual contracts:
  - ~4.58
  - ~1.47
  - ~1.28e-1
  - ~9.05e-3
  - ~6.22e-4
  - ~4.26e-5
  - ~2.92e-6
  - ~2.00e-7
  - final post-update residual ~1.37e-8;
- final max head update at iteration 8 ~4.16e-7 cm.

This is slow but healthy Newton convergence.

## Attribution

The frozen attribution classes rule out:

- `BALANCE_FLOOR_STALL`;
- `NEWTON_DIVERGENCE`;
- persistent `LINE_SEARCH_FAILURE`;
- evidence of gross Jacobian inconsistency.

Classification:

`OTHER_ITERATION_BUDGET_EXHAUSTION_UNDER_DYNTOP_STIFFNESS`.

B01 includes a localized globalization event around the wet surface transition, but both traced failures continue contracting toward convergence when MAXIT is reached.

## Decision

The TIMEINT12A failures are not yet evidence that fully implicit dynamic-top is intrinsically nonconvergent.

A separately preregistered MAXIT-sensitivity study is justified.

No tolerance, timestep or production setting changes are made here.
