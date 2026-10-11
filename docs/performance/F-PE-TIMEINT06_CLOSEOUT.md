# F-PE-TIMEINT06 closeout — cheap variable-step BDF2 error estimator

Date: 2026-09-28

Final status:

`CLOSED_SIMPLE_HISTORY_ESTIMATOR_NOT_QUALIFIED`

## P0

Cheap history signal S1:

`0.5*h*max|d_now-d_prev|`

is predictive of local full-versus-two-half BDF2 head error.

On 120 calibration labels:

- overall Spearman about 0.863;
- all step-pattern correlation gates pass.

## P1 / holdout

A frozen conservative multiplier:

`E_hat = 0.20*S1`

was tested on new B12/O14 material/forcing combinations.

The holdout preserved strong ranking and produced zero false-safe classifications at the local 0.01 cm threshold, but failed the frozen absolute-envelope gate:

- max actual/estimated error ratio about 1.187.

A research two-half label also failed to complete on one O14/R2 point.

## Scientific conclusion

A first-derivative-change signal is useful but is not a universally calibrated local truncation-error estimator.

This is consistent with BDF2 theory: local error depends on higher temporal curvature, not only the change between two first-difference slopes.

## Required successor

`F-PE-TIMEINT07 — BDF2 third-divided-difference LTE estimator`.

TIMEINT07 should derive a step-ratio-aware estimator from an additional accepted history level rather than fitting another global multiplier.

The estimator should:

1. use at least four accepted state levels where available;
2. represent the BDF2 local truncation term through a third divided difference;
3. include variable-step geometry explicitly;
4. remain solve-free on the accepted candidate endpoint;
5. use expensive refinement only as research authority;
6. preregister any analytical coefficient before result exposure;
7. test calibration and holdout across the ratio<=2 envelope.

## Production boundary

No production source change.

Variable-step BDF2 ratio<=2 mechanism remains qualified research authority.
