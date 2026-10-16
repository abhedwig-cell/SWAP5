# F-PE-TIMEINT02 closeout — BDF2 operator-consistency study

Date: 2026-09-28

Final status:

`BLOCKED_IMPLICIT_OPERATOR_CONTRACT`

Canonical base:

`integration/f-ci-canonical@b13fb7b903044a82687a21814bfaa1f7e7cfa833`

## What is decided

The current first-order semi-implicit operator cannot be upgraded to a second-order method by changing the storage derivative alone.

Evidence:

- BE_KLAG remains approximately first order;
- BDF2_KLAG does not approach second order and one case loses completion.

Thus lagged coefficient/operator treatment is materially order limiting.

## What is not decided

The fully implicit endpoint-operator BDF2 candidate is not falsified.

It was not executed because the explicit Reference solver binding deliberately rejects `conductivity_implicit_mode != 0` before nonlinear work.

TIMEINT02A confirms this is a contract rejection, not insufficient MAXIT.

## Architectural consequence

The next integration study must cross a solver-contract boundary before it can answer the BDF2 question.

That boundary should be crossed test-only first.

## Required successor

`F-PE-TIMEINT03 — explicit fully implicit Richards operator qualification`.

Recommended phase order:

1. create a renamed test-only explicit binding that admits SWKIMPL=1;
2. validate ordinary Backward Euler on smooth fixed-flux cases;
3. verify Jacobian/K/dKdh semantics and convergence;
4. only then rerun BDF2_KIMPL temporal-order characterization;
5. keep dynamic-top out of scope until smooth fixed-flux qualification succeeds.

## Production boundary

No production `src/**` changes in TIMEINT02.

No user-facing timestep behavior changes.

LEGACY_NUMERICS remains default.
