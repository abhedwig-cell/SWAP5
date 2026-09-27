# F-PE-SHORTSTEP01 P0 result — single-step duration ladder

Date: 2026-09-26

Status: `NONMONOTONE_DT_CONVERGENCE_BANDS_CONFIRMED`

## Protocol

Thirty-two certificate-free dynamic-origin corrector ladders were evaluated:

- B01 wet, O05 wet, O14 wet, O14 mid;
- both +/-10% physical history directions;
- prescribed-head offsets +/-0.001 and +/-0.01 cm;
- nine single-step durations from 1e-4 down to 3.125e-6 day.

Every duration started from the identical dynamic physical origin in a fresh process. The temporal certificate was absent.

## Result

All failures are Reference-floor solver failures:

`KERNEL_REFERENCE_FLOOR_STATUS_SOLVER_FAILED = 204`

Failed points characteristically exhaust 48 nonlinear iterations with large backtracking counts. Successful neighboring durations typically converge in 3-8 nonlinear iterations with complete mass accounting.

### Ladder structure

The 32 pass/fail signatures include both monotone-looking and non-monotone patterns.

Most common examples:

- `PPPPFFFFF` in 8/32 ladders;
- `PPPPPFFFF` in 6/32;
- `PPPFFFFFF` in 4/32;
- `PPPPPPFFF` in 4/32.

But several ladders contain recovery after a failed duration:

- `PFFFPFFFF`;
- `PPPFPPFFF`;
- `PPFFPFPFF`;
- `PPPFPFFFF`;
- `PPPFPFPFF`;
- `PPPPFPFFF`.

One O14-wet ladder is especially important:

`FPPPFFFFF`

where the 1e-4 day solve fails but 7.5e-5, 5e-5 and 3.75e-5 day solves succeed before failure returns at shorter duration.

## Interpretation

The blocker is not a single monotone short-step threshold.

Reducing dt changes the nonlinear path in a banded/non-monotone way. Neighboring durations from the identical state and forcing can switch between rapid convergence and complete nonlinear exhaustion.

This strongly suggests that P1 must inspect discrete Newton/backtracking trajectories rather than only scalar dt-dependent conditioning.

## P1 targets

Use representative adjacent success/failure pairs including:

- O05 wet, history -0.1, offset +0.001: 1.875e-5 PASS versus 1.25e-5 FAIL;
- O14 wet, history +0.1, offset -0.001: 5e-5 PASS versus 3.75e-5 FAIL, followed by 2.5e-5 PASS;
- B01 wet, history +0.1, offset +0.001: 7.5e-5 PASS versus 5e-5 FAIL and 2.5e-5 PASS.

These pairs distinguish a simple threshold explanation from path-sensitive Newton/line-search behavior.

No production source change is authorized.