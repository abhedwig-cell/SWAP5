# F-PE-TIMEINT16C preregistration — provider-consistent Thomas-Gladwell coefficient staging

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Current canonical authority:

`integration/f-ci-canonical@d71cdae32abac62bd76e78a1f8897fc9e879c1c6`

Parent research:

- TIMEINT16 P0: moisture TG reconstruction is conservative and cheap but showed approximately first-order head convergence.
- TIMEINT16B: event-startup attribution is separately preregistered and remains logically prior for the forcing-discontinuity hypothesis.

TIMEINT16C is preregistered now to prevent post-hoc coefficient variants. It is executed only after TIMEINT16B closes negative or demonstrates that startup is not the dominant cause.

## Literature mechanism

For first-order nonlinear systems, Kavetski, Binning and Sloan (2004) show that second-order Thomas-Gladwell accuracy requires solution and derivative to be approximated at the same location in the step.

They further show that nonlinear coefficients need not be solved fully implicitly at the exact final state. Evaluating them on a forward predictor

`u_tilde_(n+phi) = u_n + phi*h*u_dot_n`

is O(h^2) accurate for the coefficients and preserves second-order TG accuracy when the stage-location condition is met.

This provides a principled alternative to SWAP's current test-only SWKIMPL=1 path.

## SWAP-specific defect hypothesis

In canonical HeadCalc, the explicit provider supplies the initial conductivity tuple.

During SWKIMPL=1 Newton candidate updates, conductivity is subsequently recomputed through legacy `hconduc(...)`.

Thus an explicit-provider solve can evaluate the accepted-origin and candidate/end operators through different constitutive authorities.

A BDF endpoint equation may still display temporal order because it uses one endpoint equation. A TG method explicitly combines origin and endpoint derivatives and therefore requires stronger operator identity.

TIMEINT16C avoids this composition entirely.

## Frozen candidate: TG_KPRED_STAGE

At accepted state `theta_n,h_n`:

1. evaluate the physical accepted-origin derivative `theta_dot_n` from the provider-consistent semidiscrete balance;
2. form a first-order moisture predictor:
   `theta_tilde = theta_n + h*theta_dot_n`;
3. invert the benchmark retention relation exactly:
   `h_tilde = h(theta_tilde)`;
4. evaluate the explicit constitutive provider once at `h_tilde` to obtain `K_tilde`;
5. bind `K_tilde` through the fixed predicted-K provider, with `dK/dh=0` during the endpoint nonlinear solve;
6. solve the BE-like endpoint storage/gradient equation with:
   - exact candidate theta(h);
   - implicit candidate pressure gradients;
   - fixed `K_tilde`;
7. obtain endpoint derivative:
   `theta_dot_p=(theta_BE-theta_n)/h`;
8. accept:
   `theta_TG=theta_n+0.5*h*(theta_dot_n+theta_dot_p)`;
9. project to constitutively consistent `h_TG` using exact test-bank inverse retention.

No previous-step K extrapolation is used in P0. The coefficient prediction comes only from the current accepted state and accepted derivative.

## Why this differs from TIMEINT13 K extrapolation

TIMEINT13 uses history:

`K_pred = 2 K_n - K_(n-1)`.

TIMEINT16C instead predicts the endpoint physical state first and evaluates K on that state.

This is directly aligned with the O(h^2) coefficient-evaluation argument in the Thomas-Gladwell truncation analysis and requires no multistep K history.

## Fixed-flux bank

Identical to TIMEINT16:

- B01, rain 2 and 4 cm/d;
- O05, rain 2 and 4 cm/d;
- initial h = -100 cm;
- horizon 0.04 d;
- h = 0.010, 0.005, 0.0025, 0.00125 d;
- explicit fixed top flux;
- zero bottom flux;
- no dynamic top;
- no macropores.

## Frozen diagnostics

Record:

- top/mid/bottom head and theta;
- physical per-step ledger;
- cumulative ledger;
- exact theta roundtrip;
- K-prediction positivity/finiteness;
- endpoint solver work;
- endpoint native balance residual;
- refined head and theta orders.

Also record maximum difference between `K_tilde` and accepted-origin K to prove the test is nontrivial.

## Frozen gates

Candidate advances only if:

1. 4/4 ladders complete;
2. median refined top-theta order >=1.6;
3. median refined top-head order >=1.6;
4. at least 3/4 individual refined head orders >=1.5;
5. physical per-step ledger <=5e-8 cm;
6. cumulative ledger <=5e-8 cm;
7. theta roundtrip <=1e-12;
8. zero nonfinite or nonpositive predicted K;
9. endpoint native balance residual <=5e-8 cm/d;
10. median work per step <=1.15 times KLAG Backward Euler.

## Possible outcomes

`QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`

`CLOSED_TG_KPRED_STAGE_SECOND_ORDER_NOT_REPRODUCED`

`BLOCKED_TG_KPRED_STAGE_SOLVER_ROBUSTNESS`

`BLOCKED_TG_KPRED_STAGE_CONSERVATION`

## Stop rules

No additional K predictors in TIMEINT16C.

No historical K extrapolation rescue.

No threshold tuning.

No dynamic top.

No adaptive timestep controller.

If TIMEINT16C remains first order while stage and conservation diagnostics pass, close the TG reconstruction line and move to a fully explicit DAE/MOL temporal formulation as a separate successor.

## Production boundary

Test-only.

No production source change.

No transaction mass-contract change.

`LEGACY_NUMERICS` remains default.
