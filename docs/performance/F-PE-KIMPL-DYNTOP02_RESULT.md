# F-PE-KIMPL-DYNTOP02 result — dynamic-top iteration-budget sensitivity

Date: 2026-09-29

Status: `RECOVERABLE_BUT_TOO_DEEP_FOR_DEFAULT`

Authority:

- canonical base: `integration/f-ci-canonical@199566655db5b13483194e16bb81a154f6fc2547`;
- Actions run: `36517959708`;
- job: `109244369622`;
- conclusion: SUCCESS.

## Result

Six TIMEINT12A failing KIMPL cases were rerun at MAXIT 8, 12, 16 and 24 with all other settings unchanged.

First completing MAXIT:

- B01/WET: 12;
- B01/POND: 12;
- B12/POND: 12;
- O05/POND: 12;
- O14/WET: 16;
- O14/MOIST: 24.

No case still fails at MAXIT24.

Water-ledger residuals of completed trajectories remain roundoff-scale and no alternative-solver pathology appears.

## Interpretation

The TIMEINT12A failures are not intrinsic nonconvergence of the fully implicit dynamic-top operator.

They are recoverable with more nonlinear iterations.

However, the required depth is not uniform and is too large for a straightforward production default increase.

The strongest counterexample is O14/MOIST:

- MAXIT8 fails at step 2;
- MAXIT12 fails at step 7;
- MAXIT16 fails at step 15;
- MAXIT24 completes;
- completed work index at MAXIT24: 1012 over 24 steps.

This is materially more work than the lagged-K Reference route and demonstrates a persistent stiffness/cost problem rather than a one-off cap miss.

## Decision

Classification:

`RECOVERABLE_BUT_TOO_DEEP_FOR_DEFAULT`.

Do not production-raise MAXIT globally to enable fully implicit dynamic-top.

Do not reopen dynamic-top BDF2 on the assumption that higher MAXIT is free.

The modern integration line should seek a temporally consistent coefficient treatment that avoids fully implicit conductivity coupling where possible.
