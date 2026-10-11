# F-PE-TIMEINT16B preregistration — Thomas-Gladwell startup and stage-collocation attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority at preregistration:

`integration/f-ci-canonical@599600918a8ea4a5ad20551478b15e428fbe233d`

Parent:

F-PE-TIMEINT16 P0 moisture-based Thomas-Gladwell reconstruction.

## Motivation

The first TIMEINT16 mechanism run is physically conservative and constitutively consistent, but its refined temporal order is approximately one rather than two.

This does not by itself falsify the Thomas-Gladwell family.

Kavetski, Binning and Sloan (2004) establish for first-order nonlinear systems that second-order Thomas-Gladwell accuracy requires the dependent variable and its time derivative to be approximated at the same location inside the time step. They also note that high-order PDE time integration presupposes sufficiently smooth higher time derivatives, which can fail for nonsmooth forcing.

The existing fixed-flux bank starts from hydrostatic/uniform initial head and applies a nonzero top flux discontinuously at t=0.

## Frozen questions

TIMEINT16B asks only:

1. does damping the single known t=0 forcing discontinuity restore the expected asymptotic order?
2. does the accepted-origin derivative used by TG satisfy the physical semidiscrete operator at the accepted state?
3. does the BE predictor endpoint derivative satisfy the physical semidiscrete operator at the predictor state?
4. does the moisture state itself show the same order reduction as pressure head?

No conductivity approximation or adaptive controller is introduced.

## Candidate

For nominal step h:

1. cover [0,h] with two fully implicit Backward-Euler substeps of h/2;
2. at t=h, recompute the accepted physical moisture derivative from the governing semidiscrete residual at the accepted state;
3. from t=h onward apply the unchanged TIMEINT16 TG mechanism:
   - BE-like implicit predictor;
   - endpoint physical derivative from the predictor balance;
   - accepted moisture update
     `theta_(n+1)=theta_n+0.5*h*(theta_dot_n+theta_dot_(n+1,predictor))`;
   - exact test-bank retention inversion to obtain constitutively consistent accepted head;
4. recompute derivative from each accepted TG state before the next interval.

The startup is event-local. It is not repeated.

## Collocation identities

For each TG interval record:

- accepted-origin derivative `theta_dot_n`;
- independently captured origin non-storage residual `G_n`;
- predictor derivative `theta_dot_p=(theta_BE-theta_n)/h`;
- final BE residual or equivalent predictor operator `G_p`.

Require:

`M theta_dot_n + G_n = 0`

and

`M theta_dot_p + G_p = 0`

within solver/balance authority.

These identities are diagnostics. They do not alter the accepted state.

## Bank

Same four ladders:

- B01 rain 2 cm/d;
- B01 rain 4 cm/d;
- O05 rain 2 cm/d;
- O05 rain 4 cm/d;
- nominal h = 0.010, 0.005, 0.0025, 0.00125 d;
- horizon = 0.04 d;
- explicit fixed top flux;
- zero bottom flux;
- no dynamic top;
- no macropores.

## Additional diagnostics

Record terminal:

- top head;
- top water content;
- middle water content;
- bottom water content.

Compute refined self-convergence order independently for head and water content.

If pressure-head order is low while moisture order is >=1.6, classify a constitutive-output/order-measure issue rather than temporal mechanism failure.

## Frozen gates

Startup attribution is supported only if:

1. 4/4 ladders complete;
2. median refined top-moisture order >=1.6;
3. median refined top-head order >=1.6;
4. at least 3/4 individual refined head orders >=1.5;
5. physical per-step ledger <=5e-8 cm;
6. cumulative ledger <=5e-8 cm;
7. constitutive theta roundtrip <=1e-12;
8. collocation residuals remain within 5e-8 cm/d after volume weighting;
9. median work per nominal interval <=1.25 times fully implicit BE;
10. no nonfinite state or retry pathology.

## Interpretation

If gates pass:

`TG_SECOND_ORDER_RESTORED_BY_EVENT_STARTUP`

This would qualify event-local startup as part of the research mechanism, not yet production admission.

If collocation identities fail:

`TG_STAGE_COLLOCATION_IMPLEMENTATION_DEFECT`

Stop and repair the test mechanism before interpreting temporal order.

If collocation passes but order remains below 1.6:

`TG_ORDER_REDUCTION_PERSISTS_AFTER_STARTUP`

Then the current SWAP/TG composition is not a reproduced second-order mechanism on this bank. Do not add further empirical rescue within TIMEINT16B.

## Production boundary

No production source change.

No mass tolerance change.

No predicted-K arm.

No dynamic-top work.

No adaptive-controller tuning.
