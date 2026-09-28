# F-PE-TIMEINT03A result — BDF2 nonlinear-robustness attribution

Date: 2026-09-28

Status: `BDF2_NONLINEAR_PATHOLOGY_NOT_MAXIT_LIMITED`

Authority:

- Actions run: `36443120600`;
- nonlinear-attribution job: `108998432476`;
- conclusion: SUCCESS.

## Frozen case

B01, infiltration 4 cm/day, dt=0.00125 d, BDF2_KIMPL.

MAXIT arms:

- 8;
- 12;
- 16;
- 24.

All other controls were unchanged.

## Result

Every arm fails at exactly step 25.

Failure diagnostics scale exactly with the imposed iteration cap:

- MAXIT=8: NL/BACK/JAC/LIN = 8/8/8/8;
- MAXIT=12: 12/12/12/12;
- MAXIT=16: 16/16/16/16;
- MAXIT=24: 24/24/24/24.

No arm completes.

## Interpretation

The P1 miss is not explained by a modest uniform nonlinear iteration budget.

The repeated failure at the same physical step while additional Newton iterations continue without recovery indicates a nonlinear-path / initialization problem rather than simple iteration exhaustion.

This does not falsify BDF2 temporal consistency:

- all three complete ladders have refined order approximately 2.05;
- work per completed step remains comparable to BE_KIMPL.

## Decision

Classification:

`BDF2_NONLINEAR_PATHOLOGY`

Do not increase production MAXIT as a remedy.

A separately preregistered successor may test whether a BDF2-consistent Newton predictor restores the convergence basin without changing the physical origin or temporal operator.
