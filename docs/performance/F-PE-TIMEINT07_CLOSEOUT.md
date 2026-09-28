# F-PE-TIMEINT07 closeout — analytical third-difference BDF2 LTE estimator

Date: 2026-09-28

Final status:

`CLOSED_DIRECT_ANALYTICAL_LTE_NOT_CONSERVATIVE`

## P0

The third-divided-difference estimator:

`E3 = h^2*(h+k)/a0 * max|D3|`

is strongly predictive on the B01/O05 calibration bank:

- overall Spearman about 0.961;
- per-pattern correlations about 0.949-0.960;
- median actual/estimated ratio about 0.671.

The mechanism therefore captures the correct temporal-error structure far better than simple accepted-state heuristics.

## Blind holdout

On B12/O14:

- overall Spearman remains about 0.938;
- all per-pattern correlations remain above 0.92;
- full-step BDF2 trajectories all complete.

However:

- one direct 0.01 cm false-safe occurs;
- E3 underestimates that local error by about 20%;
- one two-half research label is unavailable on O14/R2.

Therefore E3 cannot receive direct temporal-acceptance authority as-is.

## Architectural significance

This does not invalidate the TIMEINT modernization path.

The evidence now supports:

1. variable-step BDF2 with ratio<=2 as a robust second-order mechanism;
2. third-difference history as a high-quality local temporal-error predictor;
3. the remaining gap is conservative mapping from the BDF2 truncation signal to the coupled nonlinear Richards endpoint error.

That gap is narrower than the original legacy TimeControl problem.

## Next valid research direction

Do not fit another scalar multiplier post hoc.

A stronger successor should use the same analytical BDF2 truncation defect but pass it through a cheap linearized Richards response operator.

Conceptually:

`state_error ≈ J_time^{-1} * truncation_defect`.

This can potentially reuse the already assembled tridiagonal structure and require only one additional linear solve, not another nonlinear solve.

That would be a new estimator mechanism rather than a calibration rescue.

Suggested successor:

`F-PE-TIMEINT08 — linearized BDF2 truncation-defect response estimator`.

TIMEINT08 should:

- retain the TIMEINT05 ratio<=2 mechanism;
- construct the BDF2 truncation residual from third-history information;
- propagate it through the local linearized operator;
- compare predicted head error against full-versus-two-half authority;
- quantify one-tridiagonal-solve overhead;
- preregister direct conservative gates before exposure.

## Production boundary

No production source change.

LEGACY_NUMERICS remains production default.
