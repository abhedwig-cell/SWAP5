# F-PE-TIMEINT05 closeout — variable-step BDF2

Date: 2026-09-28

Final status:

`CLOSED_VARIABLE_BDF2_RATIO2_QUALIFIED`

## Decision

Variable-step fully implicit BDF2 is qualified as a research mechanism for the smooth fixed-flux envelope with adjacent accepted step ratio bounded to:

`0.5 <= h_n/h_{n-1} <= 2.0`.

## What changed in understanding

TIMEINT04 established that constant-step BDF2 can deliver second-order temporal convergence at essentially the same deterministic work per step as fully implicit Backward Euler.

TIMEINT05 now shows that this property survives practical step-size variation up to ratio 2.0.

This is important for timestep modernization because a modern controller no longer needs to operate inside a fixed-step method.

The controller can vary dt while retaining the qualified second-order integration mechanism, provided it respects the ratio envelope.

## Negative boundary

Ratio 3.0 is not qualified.

Two B01 ladders fail under the aggressive alternating 0.5/1.5 pattern.

Do not infer that larger ratios are safe from O05 completion alone.

## Required successor

`F-PE-TIMEINT06 — variable-step BDF2 local temporal error estimator`.

TIMEINT06 should not start with controller heuristics.

It should first evaluate cheap local-error candidates on the qualified ratio<=2 mechanism.

Candidate estimator families should prioritize estimates that do not require two additional nonlinear solves per accepted step.

Examples:

1. BDF2 versus an embedded first-order estimate using the converged BDF2 endpoint;
2. history/predictor-corrector defect based on the BDF2 coefficients;
3. accepted derivative/history extrapolation;
4. selective extra solve only as calibration authority, not as production estimator.

The estimator must be compared against an independent refined trajectory and must be tested across varying step ratios.

Only after an estimator is qualified should automatic dt selection be reopened.

## Production boundary

No production source change.

LEGACY_NUMERICS remains default.
