# F-PE-TIMEINT03 closeout — fully implicit BDF2 operator qualification

Date: 2026-09-28

Final status:

`BLOCKED_BDF2_NONLINEAR_ROBUSTNESS`

Canonical base:

`integration/f-ci-canonical@0d131bfc0d7b490b936b4315b17d175342e29ee6`

## What TIMEINT03 established

### Fully implicit Backward Euler is usable

The explicit Reference binding was relaxed test-only to admit SWKIMPL=1.

On four smooth fixed-flux cases:

- 16/16 BE_KIMPL runs complete;
- median refined top-head order is about 0.963;
- median work-per-step ratio BE_KIMPL/BE_KLAG is about 1.012.

Thus endpoint-updated conductivity is usable at essentially no per-step work penalty on this envelope.

### Fully implicit BDF2 is genuinely second order where it completes

BDF2_KIMPL with one BE bootstrap gives:

- refined orders about 2.049, 2.073 and 2.055 in the three complete ladders;
- median about 2.055;
- median work per step about equal to BE_KIMPL.

This confirms the TIMEINT01/02 architectural hypothesis:

the current first-order limitation is not inherent to Richards itself. It is materially tied to the lagged operator and first-order temporal discretization.

### The remaining blocker is nonlinear robustness

One B01 high-infiltration fine-dt trajectory fails at step 25 under MAXIT=8.

TIMEINT03A shows:

- MAXIT 8, 12, 16 and 24 all fail at exactly step 25.

Therefore the blocker is not a modest iteration-cap shortage.

TIMEINT03B shows:

- a constant-step BDF2 linear head predictor h_guess=2h^n-h^{n-1} does not repair the route;
- it instead causes both B01 fine-dt trajectories to fail earlier at step 7.

Therefore a simple predictor rescue is rejected.

## Scientific conclusion

A modern second-order Richards integrator is technically plausible in SWAP5.

The candidate fully implicit BDF2 operator:

- has the expected second-order temporal convergence in smooth completed trajectories;
- does not show a material per-step solver-work penalty relative to fully implicit Backward Euler.

However, the current HeadCalc nonlinear globalization/initialization path is not sufficiently robust for all BDF2 trajectories.

This is now the dominant blocker before variable-step BDF2 or embedded error estimation should be attempted.

## What not to do

Do not:

- production-enable SWKIMPL=1 from this workunit;
- production-enable BDF2;
- simply raise MAXIT;
- use the tested linear extrapolation predictor;
- proceed directly to dynamic-top BDF2;
- fit an adaptive timestep controller around a nonlinear path that is not yet robust.

## Required successor

`F-PE-TIMEINT04 — BDF2 nonlinear-path reconstruction and globalization audit`.

TIMEINT04 should isolate the failing B01 trajectory and record per nonlinear iteration:

- residual norm;
- Newton update norm;
- line-search/backtracking factor;
- head extrema;
- conductivity extrema;
- storage Jacobian contribution;
- flux Jacobian contribution;
- acceptance/rejection of each trial update.

It should compare the last convergent step and first failing step under:

- BE_KIMPL;
- BDF2_KIMPL.

The first objective is attribution, not another solver tweak.

Only after identifying the failure mechanism should candidate globalization methods be preregistered.

## Production boundary

No production source or timestep behavior changed in TIMEINT03.

LEGACY_NUMERICS remains default.

AUTO_REFERENCE remains unavailable for production.
