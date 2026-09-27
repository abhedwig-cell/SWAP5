# F-PE-REPRO01 D1/D2 result — first-corrector nondeterminism isolated

Date: 2026-09-26

Status: `EXACT_FIRST_CORRECTOR_NONDETERMINISM_CONFIRMED`

## D1

A fixed exact/default bridge was executed in 40 fresh processes using only:

`initialize -> trial(href)`

Result:

- PASS: 40/40;
- FAIL: 0/40.

All successful records were identical in the reported state and diagnostics.

## D2

The same fixed exact/default bridge was tested with four pre-trial read patterns:

- N: no extra read;
- E: `e1_diagnostics()`;
- S: `state()`;
- ES: both reads.

Each pattern used 40 fresh processes.

Results:

- N: 39/40 PASS, 1/40 FAIL;
- E: 40/40 PASS;
- S: 40/40 PASS;
- ES: 40/40 PASS.

The observed difference between N and the other arms is not interpreted as a protective effect of the read calls. With a rare event and only 40 trials per arm, the evidence only establishes that neither read is required to trigger the failure.

## Failing exact first-corrector signature

The D2 N failure occurred with the same initialized predictor values as passing runs:

- HCOF: `3.40293603727909288e-01`;
- RHS: `-2.43309907006609538e-01`;
- HREF: `-7.14999970613630742e-01`;
- top flux: `1e-6 cm/day`;
- bottom flux carrier: `1e-6 cm/day`;
- A2C inactive.

Passing first corrector:

- participant trial status: 0;
- soil-water solver status: 1 = `SW_SOLVE_CONVERGED`;
- nonlinear iterations: 2;
- Jacobian builds: 2;
- linear solves: 2;
- backtracking attempts: 2;
- internal retries: 0;
- constitutive evaluations: 3;
- temporal indicator available.

Failing first corrector:

- participant trial status: 6 = `TRIAL_FAILED`;
- soil-water solver status: 2 = `SW_SOLVE_RETRY_ADVISED`;
- nonlinear iterations: 16;
- Jacobian builds: 16;
- linear solves: 16;
- backtracking attempts: 108;
- internal retries: 1;
- constitutive evaluations: 109;
- temporal indicator not run/available.

## Isolation conclusion

The nondeterminism exists upstream of MODFLOW/XMI.

It can occur in the exact/default route with:

- one fixed compiled SWAP bridge;
- a fresh process;
- no MODFLOW model initialization;
- no coupled solve;
- no A1;
- no A2C;
- no required diagnostic-read trigger.

The failure is therefore localized to the exact SWAP first-corrector transaction/solver path or state feeding that path.

## Next step

D3 tests whether the process sensitivity is consistent with uninitialized local/runtime state by rebuilding the same exact diagnostic probe under controlled compiler initialization/checking modes.

No production fix is implied by this result.
