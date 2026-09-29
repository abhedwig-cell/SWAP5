# F-PE-TIMEINT17A2 preregistration — route-margin same-route bank

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17A: `BLOCKED_TIMEINT17A_BANK_NOT_SAME_ROUTE`.

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Purpose

Repair only the P0 bank.

TIMEINT17A showed that the original fixed rain/ponding fixtures lie too close to dynamic-top route boundaries. No temporal or mass gate is changed.

TIMEINT17A2 constructs each route fixture from the instantaneous dynamic-top algebra using the same formulas for every material.

No case-by-case tuning after results is allowed.

## Geometry authority

The frozen test geometry remains:

- 16 nodes;
- 10 cm compartments;
- surface-to-top-node distance 5 cm;
- conductivity mean method 1.

Surface parameters remain:

- Pmax = 0.050 cm;
- rsro = 0.050 d;
- runoff exponent = 1.

## Material hydraulic evaluation

For each material, evaluate the accepted-origin top-node conductivity `Ktop(h0)` from the exact benchmark constitutive provider.

Define saturated surface-face conductivity:

`Kface = 0.5*(Ksat + Ktop)`.

Define the head-route Darcy flux:

`qhead(P,h0) = -Kface*((P-h0)/dtop + 1)`.

All rain values below are derived from this formula before trajectory integration.

## FLUX fixture

Freeze:

- h0 = -50 cm;
- P0 = 0.

Compute zero-head infiltration capacity:

`Icap = -qhead(0,h0)`.

Set:

`rain = 0.25 * Icap`.

This gives a fixed 75% capacity margin at the accepted origin.

Require `Icap>0`.

## HEAD fixture

Freeze:

- h0 = -5 cm;
- P0 = 0.025 cm = 0.5 Pmax.

Set rain from the instantaneous surface-storage equilibrium:

`rain = -qhead(P0,h0)`.

Thus:

`Pdot(0)=0`

at the accepted origin.

The initial surface storage is 0.025 cm from both hard thresholds:

- distance to P=0: 0.025 cm;
- distance to P=Pmax: 0.025 cm.

## RUNOFF fixture

Freeze:

- h0 = -5 cm;
- P0 = 0.100 cm = 2 Pmax.

Initial runoff rate:

`R0=(P0-Pmax)/rsro`.

Set:

`rain = -qhead(P0,h0) + R0`.

Thus:

`Pdot(0)=0`

at the accepted origin with active runoff.

The initial storage is 0.050 cm above the runoff threshold.

## Horizon and dt ladder

Use a shorter smooth-mechanism horizon:

`H = 0.001 d`.

Freeze dt ladder:

- 0.00025 d;
- 0.000125 d;
- 0.0000625 d;
- 0.00003125 d.

This still gives 4, 8, 16 and 32 accepted intervals.

No result-driven horizon shortening is allowed after exposure.

## Route-margin diagnostic

For every accepted origin record:

- route;
- distance to P=0;
- distance to P=Pmax;
- for FLUX, capacity slack `Icap-rain`.

For HEAD/RUNOFF also record the maximum first-order surface-storage excursion estimate:

`M = h * abs(Pdot_origin)`.

A ladder is same-route eligible only if the actual origin, predicted, BE predictor and accepted TG routes remain the frozen route on all four dt levels.

## Bank

Materials:

- B01;
- B12;
- O05;
- O14.

Routes:

- FLUX;
- HEAD;
- RUNOFF.

Total potential ladders:

`12`.

## Gates

All parent TIMEINT17A gates remain unchanged.

The bank-design gate is:

1. >=8 eligible complete ladders;
2. >=3 hydraulic materials represented;
3. all three route families represented.

Scientific gates remain:

- median top-head order >=1.6;
- median top-theta order >=1.6;
- >=75% resolvable head orders >=1.5;
- median resolvable ponding order >=1.6 for HEAD/RUNOFF;
- max per-step physical ledger <=5e-8 cm;
- max cumulative ledger <=5e-8 cm;
- theta/head roundtrip <=1e-12;
- predicted K finite and positive;
- native endpoint balance residual <=5e-8 cm/d;
- surface-rate collocation residual <=5e-8 cm/d;
- median work ratio <=1.20 versus identical-route KLAG BE.

## Outcomes

Positive:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE`.

If the formula-derived fixtures still fail the bank denominator:

`BLOCKED_TIMEINT17A2_ROUTE_MARGIN_INSUFFICIENT`.

If bank coverage is valid but order fails:

`CLOSED_TG_DYNAMIC_TOP_SAME_ROUTE_ORDER_FAIL`.

If bank coverage/order pass but physical ledger fails:

`BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_CONSERVATION`.

## Stop rule

No third manual bank redesign inside TIMEINT17A.

If A2 remains route-unstable, proceed to explicit event semantics rather than attempting to manufacture a smooth dynamic-top bank.

## Production boundary

Test-only.

No production source change.

No mass-gate change.

No event localization in A2.
