# F-PE-TIMEINT17 preregistration — provider-consistent Thomas-Gladwell dynamic-top and event semantics

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@f73372ec97e431e10d03b1cf6eb9db4368dfb97f`

Parent authority:

- F-PE-TIMEINT16: `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`.
- F-PE-TIMEINT14: BDF2 remains incompatible with the unchanged exact consecutive-state physical interval mass contract.
- F-PE-TIMEINT15: the tested conservative trapezoidal composition preserves mass but does not reproduce second-order convergence.
- F-PE-TIMEINT12/KIMPL-DYNTOP: the fully implicit dynamic-top operator is mathematically recoverable but too costly as the preferred performance route.
- F-PE-TIMEINT13: predicted-conductivity dynamic top is cheap enough on completed paths but BDF2 introduced a separate mass-contract blocker and incomplete POND robustness.

## Purpose

TIMEINT17 asks whether the qualified TIMEINT16C one-step mechanism can be extended to SWAP's dynamic top boundary without weakening:

- exact accepted-interval physical mass accounting;
- transaction ownership;
- second-order smooth temporal behavior;
- constitutive consistency;
- current-step provider-consistent coefficient staging.

This work unit owns event and dynamic-boundary semantics only.

It does not own adaptive timestep control, variable-step TG coefficients, production source admission, or user-facing timestep settings.

## Literature basis

The relevant Richards boundary is piecewise defined:

- flux-controlled while supplied water can infiltrate without ponding;
- head-controlled when ponding constrains infiltration;
- runoff removes excess surface water.

Established Richards implementations therefore select or repeat the top-boundary solution according to available water and ponding state.

For discontinuous dynamical systems, event-driven one-step integration localizes the discontinuity surface and changes the vector field at that event rather than integrating blindly across it.

TIMEINT17 treats a FLUX/HEAD boundary-mode change as an event in this sense.

References:

- Kavetski, Binning and Sloan (2004), International Journal for Numerical Methods in Engineering 60, 2031-2043, DOI 10.1002/nme.1035.
- Kavetski, Binning and Sloan (2002), Water Resources Research 38(10), 1211, DOI 10.1029/2001WR000720.
- Ross (2017), 1D Richards equation discontinuity/event-driven treatment, Filippov approach.
- openRE (2023), Geoscientific Model Development 16, 659-687, conservative method-of-lines Richards formulation.

## Architecture invariants

TIMEINT17 holds fixed:

1. rejected trials do not mutate accepted physical state;
2. predicted K belongs to the current trial only;
3. accepted-origin derivative is recomputed from the accepted physical state;
4. physical interval accounting uses physical soil storage + surface storage versus current-interval physical in/out;
5. boundary route changes are numerical/physical events, not hidden solver history;
6. event localization attempts are disposable trials until a subinterval is accepted;
7. `LEGACY_NUMERICS` remains production default.

No history mass, event debt, or storage-derived external flux may be introduced.

## Candidate temporal mechanism

The smooth within-regime mechanism remains exactly TIMEINT16C.

At accepted state `n`:

1. evaluate the accepted-origin physical moisture derivative;
2. form
   `theta_tilde = theta_n + h theta_dot_n`;
3. project `theta_tilde -> h_tilde` through the exact test-bank retention inverse;
4. evaluate provider-consistent `K_tilde`;
5. hold `K_tilde` fixed during the endpoint nonlinear storage/gradient solve;
6. obtain endpoint predictor derivative
   `theta_dot_p = (theta_BE-theta_n)/h`;
7. accept
   `theta_TG = theta_n + 0.5 h (theta_dot_n + theta_dot_p)`;
8. project accepted moisture to constitutively consistent accepted head.

The dynamic top provider must use the same current-trial predicted top conductivity authority as the endpoint solve.

## P0 — same-route dynamic-top qualification

### Question

Does TIMEINT16C remain second order, conservative and cheap when the top boundary is dynamic but the accepted interval remains on one smooth boundary route?

### Bank

Reuse the established B01, B12, O05 and O14 dynamic-top archetypes and MOIST/WET/POND-style initial states, but P0 labels a trajectory segment admissible only when:

- the top-boundary route at accepted origin and accepted endpoint is the same;
- no rainfall/forcing discontinuity occurs inside the interval;
- no surface-storage sign change occurs inside the interval;
- no runoff activation/deactivation occurs inside the interval.

P0 is not allowed to silently discard difficult states. The number and identity of excluded transition intervals must be reported.

### Physical interval ledger

For an accepted subinterval:

`Delta(soil storage + ponding) = rain*h - runoff_depth + bottom_flux*h - sinks*h`

using the actual sign convention of the existing dynamic-top authority.

Runoff depth is the physical interval-integrated runoff published by the top provider.

No endpoint-derived synthetic runoff is allowed.

### P0 gates

Advance to event work only if:

1. at least 8 complete same-route ladders spanning >=3 hydraulic archetypes;
2. median refined top-head order >=1.6;
3. median refined top-moisture order >=1.6;
4. >=75% individual refined head orders >=1.5;
5. max physical interval ledger <=5e-8 cm;
6. max cumulative physical ledger <=5e-8 cm;
7. theta/head roundtrip <=1e-12;
8. predicted K finite and positive;
9. max endpoint native balance residual <=5e-8 cm/d;
10. median work per step <=1.20 times same-route KLAG Backward Euler.

Positive classification:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE`

Negative classifications:

- `CLOSED_TG_DYNAMIC_TOP_SAME_ROUTE_ORDER_FAIL`;
- `BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_ROBUSTNESS`;
- `BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_CONSERVATION`.

If P0 fails, do not open event localization.

## P1 — known-time hard forcing events

P1 executes only if P0 qualifies.

### Question

When rainfall or another external top forcing changes at a known time inside a nominal interval, can second-order semantics be preserved by exact event splitting and restart?

### Frozen event rule

If a known forcing event occurs at `t_e` with
`t_n < t_e < t_n+h`:

1. the nominal trial is not accepted as one interval;
2. solve `[t_n,t_e]` using the pre-event forcing;
3. commit that physical subinterval only if it passes normal solve/mass gates;
4. at `t_e`, discard any pre-event derivative/predicted-K stage state;
5. recompute the accepted-origin derivative under post-event forcing;
6. solve `[t_e,t_n+h]` as a fresh one-step TG interval;
7. publish two physical accepted intervals, never one synthetic interval spanning the discontinuity.

There is no Rannacher half-step by default.

A first-order restart is introduced only by a separately preregistered successor if exact split/recompute fails.

### P1 bank

For B01 and O05, place a rainfall-rate step at non-grid fractions of the nominal interval:

- 0.25 h;
- 0.50 h;
- 0.75 h.

Use event-aligned high-resolution references and dt ladders where the nominal unsplit grid would cross the event.

### P1 gates

1. all event fractions complete;
2. exact split ledger <=5e-8 cm per accepted subinterval;
3. cumulative ledger <=5e-8 cm;
4. post-event accepted derivative is recomputed, not inherited;
5. no rejected pre-event trial state survives;
6. terminal head and moisture converge with median order >=1.6 away from the event;
7. no material work penalty beyond the unavoidable extra event subinterval.

Positive:

`QUALIFIED_TG_KNOWN_EVENT_SPLIT_RESTART`

## P2 — endogenous dynamic-top regime events

P2 executes only if P0 and P1 qualify.

### Event definition

An endogenous event exists when a nominal trial indicates a top-boundary route transition such as:

- FLUX -> HEAD / ponding onset;
- HEAD -> FLUX / ponding exhaustion;
- runoff inactive -> active;
- runoff active -> inactive.

The event is owned by the top-boundary/event layer, not by the temporal error controller.

### Frozen localization principle

Use bracketed disposable trials to localize the earliest route transition inside the proposed interval.

Requirements:

1. left bracket is an accepted-state continuation on the origin route;
2. right bracket demonstrates the changed route;
3. localization never commits intermediate probes;
4. the final pre-event accepted subinterval ends on the origin-route side of the event;
5. event-time uncertainty must be <= max(1e-10 d, 1e-6*h) for P2 mechanism qualification;
6. after the event, recompute boundary route, physical derivative and predicted K from the event state;
7. no temporal history or predicted K crosses the event;
8. all physical mass is published on the actually accepted subintervals.

Bisection is the default localization algorithm for P2 because monotone robustness and transaction clarity are more important than event-finder speed in mechanism qualification.

No secant/Newton event finder is introduced in P2.

### P2 initial bank

Use transition-containing cases from the existing dynamic-top bank with emphasis on:

- B01/WET;
- B01/POND;
- B12/WET/POND;
- O05/WET;
- O14/WET/POND.

At least one FLUX -> HEAD and one HEAD -> FLUX or runoff-state transition must be represented before positive closure.

### P2 gates

1. >=8 complete transition trajectories;
2. >=1 onset and >=1 release transition;
3. no event probe mutates committed state;
4. event bracket tolerance passes;
5. max accepted-subinterval physical ledger <=5e-8 cm;
6. cumulative ledger <=5e-8 cm;
7. no nonfinite state;
8. transition trajectory agrees with event-aligned fine reference within the preregistered second-order smooth-segment envelope;
9. work attribution separately reports:
   - physical TG solves;
   - event probes;
   - rejected nonlinear attempts.

Positive:

`QUALIFIED_TG_DYNAMIC_TOP_EVENT_SEMANTICS`

## Stop rules

TIMEINT17 does not:

- introduce variable-step TG formulas;
- tune AUTO timestep criteria;
- alter DTMIN/DTMAX;
- loosen mass gates;
- change production `src/**`;
- add historical K extrapolation;
- add a different nonlinear solver;
- approximate event mass by storage residual;
- hide event probe cost inside accepted-step work.

If P2 event localization is prohibitively expensive but scientifically correct, classify cost separately. Do not weaken event semantics.

## Successor boundary

After positive TIMEINT17 closure:

`F-PE-TIMEINT18 — variable-step Thomas-Gladwell and LTE control`

Only after TIMEINT18 may the research line reconnect to automatic timestep selection.

## Production boundary

Research/test-only.

No production source change.

No user-facing temporal mode.

No default change.

`LEGACY_NUMERICS` remains production default.
