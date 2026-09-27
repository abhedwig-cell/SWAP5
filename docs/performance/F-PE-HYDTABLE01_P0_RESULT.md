# F-PE-HYDTABLE01 P0 result

Date: 2026-09-27

Status: `P0_FROZEN_HOLDOUT_PASS`

PR:
`#659 — F-PE-HYDTABLE01: bounded conductivity table research`

Calibration workflow:
`36304071659`

Frozen-holdout workflow:
`36304202230`

## Candidate

Frozen before holdout in:
`docs/performance/F-PE-HYDTABLE01_P0_FREEZE.md`

Representation:

- `N=1024`;
- uniform `ln(-h)` coordinate;
- piecewise-linear `ln(K)`;
- derivative from the same interpolant;
- represented domain `-1e6 <= h <= -1 cm`;
- analytical fallback outside the domain.

## Calibration frontier

Across B01, B12, O05 and O14:

- N=64: worst K relative error 2.300e-2, worst dK/dh relative error 2.483e-1;
- N=128: 5.742e-3 and 1.138e-1;
- N=256: 1.429e-3 and 5.446e-2;
- N=512: 3.560e-4 and 2.684e-2;
- N=1024: 8.884e-5 and 1.328e-2.

All calibrated tables were monotone and nonnegative.

For N=1024 the calibration microkernel medians across the four materials were approximately:

- K-only candidate / analytical ratio: 0.172;
- K+dK/dh candidate / analytical-directional ratio: 0.081.

These are localization measurements only, not solver speedup claims.

## Independent holdout

The holdout used a deterministic disjoint logarithmic interior point sequence plus explicit probes on both sides of the wet and dry representation boundaries.

Results:

- B01:
  - max relative K error: 3.577e-5;
  - max relative dK/dh error: 6.320e-3;
  - K runtime ratio: 0.215;
- B12:
  - max relative K error: 7.230e-6;
  - max relative dK/dh error: 2.187e-3;
  - K runtime ratio: 0.215;
- O05:
  - max relative K error: 8.884e-5;
  - max relative dK/dh error: 1.324e-2;
  - K runtime ratio: 0.215;
- O14:
  - max relative K error: 2.741e-5;
  - max relative dK/dh error: 5.491e-3;
  - K runtime ratio: 0.216.

All frozen gates pass:

- K finite and nonnegative;
- monotonicity PASS;
- wet-side analytical fallback PASS;
- dry-side analytical fallback PASS;
- max relative K <= 1e-4;
- max relative dK/dh <= 1.5e-2;
- repeated K evaluation speed-positive.

## Interpretation

The first candidate survives a genuine holdout without retuning.

The result is strong enough to justify solver qualification, but it does not yet show that Richards becomes faster. The table can still fail if interpolation error increases nonlinear iterations, backtracking, retries or accepted-path error.

## Next gate

P1 solver qualification is implemented in:

- `tests/fpe/mod_hydtable01_research_provider.f90`;
- `tests/fpe/run_fpe_hydtable01_p1_solver.sh`.

P1 must compare the frozen table against analytical authority on the B01/B12/O05/O14 wet/mid/dry solver matrix before any combined-stack or production work proceeds.
