# F-AHL48 — direct-retention resolution and ownership qualification

Date: 2026-09-25

Status: `PREREGISTERED_RESOLUTION_SCREEN`

Parent: F-AHL47.

## Question

How much direct-retention resolution is actually needed to preserve the current Reference solver path and fidelity across the qualified 12-case matrix?

## Resolution candidates

- 64 intervals per decade;
- 128 intervals per decade;
- 256 intervals per decade.

The interpolation architecture remains unchanged:

- direct decade selection;
- direct index arithmetic;
- cubic Hermite theta interpolation;
- C from the exact derivative of the same interpolant;
- analytical full/K routes.

## Matrix

B01, B12, O05, O14 × wet, mid, dry.

For every resolution require:

- same convergence status;
- identical nonlinear iteration count;
- identical backtracking count;
- max |dh| <= 0.05 cm;
- max |dtheta| <= 1e-4;
- mass residual <= 1e-12.

Timing is secondary because direct indexing has O(1) lookup cost independent of table length.

## Ownership implication

Raw theta+C table payload per hydraulic authority is approximately:

- 64 intervals/decade: 6.24 kB;
- 128 intervals/decade: 12.38 kB;
- 256 intervals/decade: 24.67 kB.

These numbers exclude object/container overhead.

No production cache design is authorized until the lowest fidelity-qualified resolution is known.
