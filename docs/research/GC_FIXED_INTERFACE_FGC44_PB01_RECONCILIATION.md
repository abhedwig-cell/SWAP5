# F-GC44 convergence versus PB01 instability

Date: 2026-09-21
Status: LIVE EVIDENCE RECONCILED

## Live observations

F-GC44 run 35604358427 succeeded after the module-order repair.

Outer trace:
- iteration 1: H=-0.71499996773311758 m, q_swap=-1.2708557527755854e-13 m/s,
  q_gw=-1.004471284312938e-13 m/s, residual=-2.6638446846264738e-14 m/s,
  MODFLOW not yet converged;
- iteration 2: H=-0.71499996773317653 m, q_swap=-1.2708557527755854e-13 m/s,
  q_gw=-1.2708580747683645e-13 m/s, residual=2.3219927791065243e-19 m/s,
  MODFLOW converged.

Predictor:
- qbot=1e-6 cm/day;
- q_u=-9.6588521204796776e-7 cm/day;
- u=3.402936037279093e-5.

The head moved only 5.9e-14 m between the two reported outer iterates and q_swap was unchanged at printed precision.

## Why this does not contradict PB01

PB01 deliberately isolates the feedback mode:
- one groundwater storage cell;
- no lateral CHD conductance;
- one-day window;
- analytical SWAP response with nonzero local physical derivative;
- perturbation away from the root.

Its reanchored +u/dt iteration reproduces |rho|=4 live.

F-GC44 is a different dynamical regime:
- three groundwater cells;
- fixed-head end cells with lateral conductance;
- 1e-4 day coupling window;
- predictor/corrector state already extremely close to a coupled solution;
- observed SWAP flux is locally flat at the resolution exposed by the two live iterates.

Therefore F-GC44 currently demonstrates near-root operational closure, not stability of the positive-slope coupling algorithm against finite interface-head perturbations.

## Qualification consequence

The statement 'F-GC44 converges, therefore +u/dt is a stable coupling tangent' is rejected.

The remaining discriminator is a perturbation/stability scan using the real SWAP corrector and live MODFLOW route:
1. move the coupling state prospectively away from its natural near-root start;
2. measure local dq_swap/dH from immutable-origin corrector trials;
3. compare that derivative with +u/dt;
4. run reanchored outer iterations over bounded perturbations;
5. classify contraction, neutral response or divergence.

No production sign change is made before this real-SWAP perturbation evidence.
