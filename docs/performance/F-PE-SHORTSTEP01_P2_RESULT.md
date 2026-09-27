# F-PE-SHORTSTEP01 P2 result — convergence-gate attribution

Date: 2026-09-26

Status: `BALANCE_TOLERANCE_FLOOR_LOCALIZED`

## Result

The failed neighboring-dt Reference-floor solves are not blocked by the pressure-head change criterion.

All three representative failed targets end with:

- `FINAL_HEAD_FAIL=0`;
- normalized head-change metric below 1;
- residuals already at approximately the configured 1e-12 balance tolerances.

Representative terminal failed iterations:

- B01 wet, +0.1 history, +0.001 cm, dt=5e-5:
  - one compartment still above tolerance;
  - total residual sum = -1.6218138e-12;
  - total-balance gate fails;
  - Fmax ≈ 1.0498269e-12.

- O05 wet, -0.1 history, +0.001 cm, dt=1.25e-5:
  - one compartment still above tolerance;
  - total residual sum = 1.0036416e-12;
  - total-balance gate fails;
  - Fmax ≈ 1.6431301e-12.

- O14 wet, +0.1 history, -0.001 cm, dt=3.75e-5:
  - no compartment fails the 1e-12 balance criterion;
  - no head-change criterion fails;
  - total residual sum = 1.0007550e-12;
  - only the total-balance gate remains active.

Successful neighboring durations have the same head-change gate satisfied and terminal residuals just below the same absolute tolerance floor.

## Interpretation

The short-duration pathology is localized to near-tolerance residual stagnation against absolute balance criteria at approximately 1e-12.

The solver can spend dozens of Newton iterations and hundreds of backtracking trials attempting to reduce residuals that are already at floating-point/tolerance scale.

The O14 case is especially strong evidence because every local compartment and head-change gate passes; only a total residual of 1.000755e-12 versus a 1e-12 threshold prevents convergence.

This explains the non-monotone dt bands: small changes in dt alter the final floating-point residual trajectory enough to land just above or below an absolute convergence threshold.

## Decision

Advance to P3 tolerance-floor qualification.

P3 must vary only the balance tolerances around 1e-12 on the same fixed physical targets and quantify whether the pass/fail bands disappear without materially changing the accepted physical state or flux.

No production repair is authorized by P2 alone.