# F-PE-TIMEINT04 closeout — BDF2 nonlinear robustness and balance-floor attribution

Date: 2026-09-28

Final status:

`CLOSED_BDF2_SMOOTH_FIXED_FLUX_MECHANISM_QUALIFIED`

Canonical base:

`integration/f-ci-canonical@bd9a3fcc54000b9cdafee77f4a20e739a5abfaf2`

## Starting blocker

TIMEINT03 had established:

- fully implicit Backward Euler is robust and first order;
- fully implicit BDF2 is approximately second order in three complete ladders;
- one fine B01 high-infiltration ladder failed repeatedly;
- increasing MAXIT to 24 did not help;
- a simple linear BDF2 predictor made robustness worse.

The working diagnosis was therefore an unresolved nonlinear-path problem.

## TIMEINT04 P0 — exact nonlinear trace

The failing step was traced against BE_KIMPL.

Finding:

- full Newton steps were accepted on every iteration;
- no line-search reduction occurred;
- residual norm and Newton updates collapsed normally to roundoff;
- local residuals fell below the compartment criterion;
- head changes became O(1e-14 cm);
- only the scalar total-balance residual remained just above 1e-12 cm/day.

The BDF2 total residual then oscillated in sign at approximately 1.5e-12 to 2.9e-12 cm/day.

Classification:

`TOTAL_BALANCE_ROUNDOFF_STALL`.

## TIMEINT04A — numerical distinguishability

The BDF2 storage term combines three stored theta levels:

`1.5 theta_np1 - 2 theta_n + 0.5 theta_nm1`.

A preregistered finite-representation diagnostic found:

- worst-case summed BDF2 storage input floor: about 7.11e-12 cm/day;
- all terminal iteration-4-through-8 total residuals were below that floor;
- final residual summation-order spread was zero for the stored residual vector;
- the dominant scale was theta input representation, consistent with earlier BALTOL/P2E07 evidence.

Thus the total-balance residual was not numerically distinguishable at the configured threshold.

## TIMEINT04B — test-only convergence floor

A BDF2-specific total-balance floor based directly on the three theta-level spacings was tested.

Result:

- all 4/4 ladders complete;
- median refined top-head order: about 2.052;
- all 4 individual orders exceed 2.04;
- median work per step is about 0.988 times BE_KIMPL;
- the 15 pre-existing successful BDF2 endpoints change only at O(1e-13 cm);
- BE is exactly preserved by the materialized source.

## Scientific conclusion

The apparent BDF2 nonlinear blocker was not a failure of Newton globalization.

The current solver was converging physically and algebraically to floating-point resolution, but the scalar total-balance stopping rule was not representation-aware for the new three-level storage operator.

With a representation-aware total-balance floor, fully implicit constant-step BDF2 is a credible second-order Richards integration mechanism on the qualified smooth fixed-flux envelope.

This materially changes the timestep-modernization outlook.

A higher-order integrator can potentially obtain the same temporal accuracy with substantially larger intervals, which is a more principled route to speed than continued tuning of legacy DTMIN/DTMAX heuristics.

## Required successor

`F-PE-TIMEINT05 — variable-step BDF2 mechanism and step-ratio qualification`.

TIMEINT05 should:

1. implement test-only variable-step BDF2 coefficients;
2. generalize the representation-aware total floor using those actual coefficients;
3. test predefined step-ratio patterns under fully implicit conductivity;
4. verify second-order behavior under step-size variation;
5. define a safe step-ratio envelope before any adaptive controller is attempted.

Only after variable-step BDF2 is qualified should an embedded/local temporal error estimator and automatic controller be designed.

## Production boundary

No production `src/**` change in TIMEINT04.

Production defaults remain unchanged.
