# F-PE-TIMEINT04A result — BDF2 total-balance numerical-resolution diagnostic

Date: 2026-09-28

Status: `BDF2_TOTAL_BALANCE_FLOOR_SUPPORTED`

Authority:

- canonical base: `integration/f-ci-canonical@bd9a3fcc54000b9cdafee77f4a20e739a5abfaf2`;
- Actions run: `36445408301`;
- balance-floor job: `109006312692`;
- conclusion: SUCCESS.

## Frozen diagnostic

Exact TIMEINT04 B01 / 4 cm/day / dt=0.00125 d / BDF2_KIMPL trajectory.

Iterations retained:

4, 5, 6, 7 and 8 of failing step 25.

Per-node BDF2 storage input floor:

`0.5 * dz/dt * (1.5 spacing(theta_np1) + 2 spacing(theta_n) + 0.5 spacing(theta_nm1))`.

Frozen total distinguishability criterion:

`abs(total_residual) <= max(sum_node_storage_floor, real64_summation_spread)`.

## Result

All five terminal residuals are classified:

`NOT_NUMERICALLY_DISTINGUISHABLE`.

Observed absolute total residuals:

- iteration 4: 2.8830e-12 cm/day;
- iteration 5: 2.0015e-12;
- iteration 6: 1.5508e-12;
- iteration 7: 2.0017e-12;
- iteration 8: 2.4389e-12.

Diagnostic scales:

- configured total tolerance: 1.0e-12 cm/day;
- existing BALTOL02 rate floor at dt=0.00125 d: 2.24e-13 cm/day;
- maximum node BDF2 storage-input floor: 4.4409e-13 cm/day;
- root-sum-square node floor: 1.7764e-12 cm/day;
- worst-case sum of node floors: 7.1054e-12 cm/day.

The real64 residual summation-order spread is zero for these stored residual values. The dominant diagnostic floor is therefore the representation of the three-level theta storage combination, not final summation order.

## Interpretation

BALTOL02 remains correct for the admitted current Reference operator.

BDF2 introduces a different finite-representation problem because its storage rate combines three independently stored theta levels with coefficients 1.5, -2 and 0.5.

The TIMEINT04 step-25 failure occurs below the frozen BDF2 storage distinguishability limit.

This supports a BDF2-specific total-balance numerical floor. It does not justify a broad tolerance relaxation.

## Decision

Advance one test-only candidate in TIMEINT04B.

No production tolerance or solver policy changes are made here.
