# F-PE-TIMEINT17A preregistration — same-route dynamic-top TG bank

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent:

`F-PE-TIMEINT17_PREREGISTRATION.md`

Canonical base at preregistration:

`integration/f-ci-canonical@4a45a599093c6ed6da458dc35fbb71f462439ef4`

## Purpose

Freeze the exact same-route mechanism bank before exposing TIMEINT17 dynamic-top Thomas-Gladwell results.

This phase does not localize events.

Any interval whose physical top route changes is ineligible for the smooth-order ladder and is reported as a transition observation for P2.

## Temporal mechanism

Use the qualified TIMEINT16C current-step staging.

The temporal state is:

`Y=[theta,P]`

with `P` the physical ponding storage.

For each accepted origin:

1. evaluate the instantaneous same-route soil derivative and ponding derivative;
2. predict both moisture and ponding with forward Euler over the current step;
3. project predicted moisture to head;
4. evaluate provider-consistent `K_tilde`;
5. use fixed `K_tilde` in the Backward-Euler endpoint predictor;
6. derive endpoint predictor rates from the BE state;
7. accept the trapezoidal/Thomas-Gladwell average of the origin and endpoint rates for both `theta` and `P`;
8. project accepted moisture back to pressure head.

The existing interval dynamic-top provider is used only as the BE endpoint predictor authority. It is not used as the accepted-origin instantaneous derivative.

## Instantaneous rain-only surface operator

No evaporation, irrigation, snowmelt or runon in TIMEINT17A.

Let downward soil infiltration be negative `q_top`.

### FLUX route

At `P=0`, if the zero-head infiltration capacity can accept the supplied rain:

`q_top=-rain`

`P_dot=0`.

### HEAD route

For `P>0` below active runoff:

`q_top=-K_face*((P-h_top)/d_top+1)`

`P_dot=rain+q_top`.

### RUNOFF route

For `P>Pmax`:

`q_runoff=(P-Pmax)/rsro`

`P_dot=rain+q_top-q_runoff`.

Arithmetic surface-face K is used because the frozen bank uses conductivity mean method 1.

The same predicted top-node K supplied to the soil endpoint solve is supplied to the dynamic-top endpoint provider.

## Exact bank

Materials:

- B01
- B12
- O05
- O14

Route fixtures:

### FLUX

- initial head: -50 cm
- initial ponding: 0 cm
- rain: 2 cm/d

### HEAD

- initial head: -5 cm
- initial ponding: 0.020 cm
- rain: 12 cm/d

### RUNOFF

- initial head: -5 cm
- initial ponding: 0.080 cm
- rain: 25 cm/d

Surface parameters:

- Pmax = 0.050 cm
- rsro = 0.050 d
- runoff exponent = 1

Bottom:

- prescribed zero flux.

No internal source/sink.

No macropores.

## Time ladders

Horizon:

`0.010 d`

dt ladder:

- 0.0025 d
- 0.00125 d
- 0.000625 d
- 0.0003125 d

This gives 4, 8, 16 and 32 accepted intervals on a same-route complete trajectory.

## Route admission rule

For every trial and accepted step, record:

- origin route;
- BE predictor route;
- accepted TG route.

A ladder is same-route-qualified only if all three agree with the frozen route fixture on every interval.

A route mismatch does not trigger tuning or a retry in TIMEINT17A.

It marks that ladder:

`TRANSITION_OBSERVED_NOT_P0_ELIGIBLE`.

The trajectory and first transition time are retained for P2.

## Physical ledger

For the TG accepted interval use physical runoff quadrature:

`R_int = 0.5*h*(Rdot_n + Rdot_p)`.

Then evaluate:

`L = Delta(S_soil+P) - rain*h + R_int - qbottom*h`.

For TIMEINT17A, `qbottom=0`.

The runoff integral may not be reconstructed from storage residual.

## Frozen gates

Parent TIMEINT17 P0 gates apply, with these exact operational details.

Require:

1. >=8 eligible complete ladders;
2. >=3 of the 4 hydraulic materials represented by at least one eligible ladder;
3. all three route families represented by at least one eligible ladder;
4. median refined top-head order >=1.6;
5. median refined top-theta order >=1.6;
6. >=75% resolvable individual head orders >=1.5;
7. for HEAD/RUNOFF ladders with resolvable ponding differences, median refined ponding order >=1.6;
8. max physical per-step ledger <=5e-8 cm;
9. max cumulative ledger <=5e-8 cm;
10. theta/head roundtrip <=1e-12;
11. predicted K finite and positive;
12. max BE predictor surface-rate collocation residual <=5e-8 cm/d;
13. max BE predictor soil native balance residual <=5e-8 cm/d;
14. median deterministic work per step <=1.20 times KLAG BE on the identical fixture.

Positive:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE`.

If fewer than 8 ladders remain because the frozen fixtures contain transitions:

`BLOCKED_TIMEINT17A_BANK_NOT_SAME_ROUTE`.

This is a bank-design blocker, not a negative result against TG.

## Production boundary

Test-only.

No production source change.

No tolerance change.

No event localization in this phase.
