# F-PE-TIMEINT15A result — Rannacher startup attribution

Date: 2026-09-29

Status: `TRAPEZOIDAL_ORDER_REDUCTION_NOT_RESCUED_BY_RANNACHER_STARTUP`

Canonical base:

`integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`

Actions authority:

- run: `36520524280`;
- job: `109252139017`;
- conclusion: SUCCESS.

## Frozen candidate

The first nominal interval was covered by two fully implicit Backward-Euler half steps. All subsequent nominal intervals used the unchanged conservative trapezoidal formulation.

No tolerance, MAXIT, conductivity law, physical storage term or mass gate was changed.

## Result

All four preregistered smooth ladders complete.

Refined top-head orders:

- B01 / rain 2 cm d-1: about 1.020;
- B01 / rain 4 cm d-1: about 1.042;
- O05 / rain 2 cm d-1: about 1.024;
- O05 / rain 4 cm d-1: about 1.047.

Median refined order:

`1.033`

Cases with refined order >= 1.5:

`0/4`

Physical conservation remains exact to roundoff:

- maximum per-step ledger: about `2.36e-14 cm`;
- maximum cumulative ledger: about `1.08e-14 cm`.

Median work per nominal interval versus fully implicit BE:

`1.0625`

## Interpretation

The P0 order reduction cannot be attributed primarily to the abrupt t=0 forcing transition.

Rannacher damping repairs the one P0 fine-grid completion failure and preserves exact physical interval mass balance, but it does not restore second-order convergence.

The result therefore falsifies the frozen startup-attribution hypothesis.

This is not a mass-conservation failure and not a material work-cost failure. The remaining defect is in the temporal operator composition used by this conservative trapezoidal materialization.

No additional Crank-Nicolson tuning is authorized inside TIMEINT15.

## Decision

Classification:

`TRAPEZOIDAL_ORDER_REDUCTION_NOT_RESCUED_BY_RANNACHER_STARTUP`

Per preregistration, conservative trapezoidal / Crank-Nicolson closes as the primary successor route.

The next route is the separately identified Richards-specific Thomas-Gladwell / local-extrapolation family from Kavetski, Binning and Sloan. That route must be preregistered before numerical exposure.

## Production boundary

No production `src/**` change.

No mass-balance tolerance change.

`LEGACY_NUMERICS` remains production default.
