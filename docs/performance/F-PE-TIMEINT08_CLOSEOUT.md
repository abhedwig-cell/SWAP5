# F-PE-TIMEINT08 closeout — linearized BDF2 truncation-defect response

Date: 2026-09-28

Final status:

`CLOSED_SIMPLIFIED_RESPONSE_NOT_CONSERVATIVE`

## P0

The one-tridiagonal-solve response estimator qualified on B01/O05:

- overall Spearman about 0.961;
- zero false-safe points at 0.01 cm;
- about 95% safe coverage;
- one tridiagonal estimator solve;
- no extra nonlinear solve.

## Blind holdout

On B12/O14:

- all full BDF2 trajectories complete;
- overall Spearman remains about 0.925;
- safe coverage remains about 79%;
- one false-safe persists.

The false-safe is the same B12 / 5 cm/day / R1 / 0.005 d point that defeated the direct E3 estimator.

At that point E8 and E3 are nearly identical.

## Scientific interpretation

The simplified response operator:

`a0*M/h + L`

does not contain enough of the fully implicit Richards Newton response to correct the remaining underprediction.

In particular it omits the conductivity-derivative contributions that are present in the actual fully implicit HeadCalc Jacobian.

Therefore the next valid estimator question is not another scalar correction.

It is whether the already assembled converged Newton Jacobian can be reused as the truncation-defect response operator.

## Required successor

`F-PE-TIMEINT09 — exact final-Newton-Jacobian BDF2 truncation response`.

TIMEINT09 should:

1. expose the final converged tridiagonal Newton Jacobian test-only;
2. preserve the exact TIMEINT05 variable-step BDF2 equations;
3. apply the same third-history truncation residual as TIMEINT08;
4. solve the actual final Newton linear operator for the predicted state error;
5. compare against the same local full-versus-two-half authority;
6. quantify whether the matrix can be reused without an additional assembly in a future production path;
7. preregister all gates before results.

If the exact Jacobian response still produces the same false-safe, stop this estimator family and move to an embedded integrator pair rather than further response approximations.

## Production boundary

No production source change.

Variable-step BDF2 ratio<=2 remains qualified research authority.
