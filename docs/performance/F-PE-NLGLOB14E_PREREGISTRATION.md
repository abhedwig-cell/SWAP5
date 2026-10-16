# F-PE-NLGLOB14E preregistration — complete dynamic-top research policy qualification

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@240a8a92b6403ebc8c749199b16fe44c971ee9d7`

Parent authority:

- TIMEINT16C: provider-consistent unsaturated TG is second order on the smooth bank;
- NLGLOB12A1: representation-aware endpoint certificate qualified at research level;
- NLGLOB14A: saturation-event root localization qualified;
- NLGLOB14C: event remainder must use head/KLAG;
- NLGLOB14D: persistent saturated temporal mode qualified on the five frozen near-saturation targets.

## Purpose

Qualify the complete research temporal policy on the full frozen 96-case dynamic-top bank.

This is the first bank-wide test of the assembled mechanism.

No production integration is performed.

## Frozen research policy

For TG trajectories:

### Unsaturated mode

Use provider-consistent endpoint-stage TG with unchanged accepted-state formula.

Use unchanged S0/R0 research endpoint certificates.

### Saturation entry

If prospective accepted TG moisture exceeds the constitutive saturation boundary:

1. localize the first saturation event with NLGLOB14A bracketed bisection;
2. require the qualified event-distance, mass, finite-state and route guards;
3. accept the event subinterval internally;
4. integrate the exact nominal-interval remainder with existing head/KLAG;
5. enter persistent saturated temporal mode only after that event+remainder interval completes.

### Persistent saturated mode

For every subsequent nominal interval after entry:

- use existing head/KLAG over the complete nominal interval;
- reevaluate the dynamic-top provider normally;
- retain unchanged S0/R0 research endpoint certificates;
- do not re-enter TG event localization.

### KLAG comparison mode

KLAG bank trajectories remain unchanged except for the already qualified S0/R0 research endpoint certificates.

## Frozen bank

Use the exact 96-case TIMEINT17/NLGLOB bank:

- materials: B01, B12, O05, O14;
- routes: FLUX, HEAD, RUNOFF;
- modes: TG and KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d;
- unchanged dynamic-top provider;
- unchanged constitutive provider;
- unchanged physical mass accounting;
- MAXIT = 8;
- MaxBackTr = 8.

No case removal is allowed after result exposure.

## Frozen full-bank qualification gates

Classify:

`QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`

only if all hold:

1. 96/96 cases execute without process failure;
2. 96/96 cases complete the requested horizon;
3. both TG and KLAG complete for all four materials, all three routes and all four dt levels;
4. no `PREDICTED_RETENTION_DOMAIN_FAILED`;
5. no `SATURATION_ROOT_BRACKET_INVALID`;
6. no event-root, event-remainder or persistent-mode state failure;
7. no nonfinite accepted state;
8. no route-mismatch accepted state;
9. max accepted-interval physical ledger <= `5e-8 cm`;
10. max cumulative physical ledger <= `5e-8 cm`;
11. all saturation-mode entries emit explicit diagnostics;
12. no trajectory performs event localization after persistent saturated-mode entry.

## Smooth-order preservation

Run the original smooth TIMEINT16C bank unchanged.

Require:

- 4/4 complete ladders;
- median refined head order >=1.6;
- median refined moisture order >=1.6;
- >=3/4 individual refined head orders >=1.5;
- physical/cumulative ledger <= `5e-8 cm`;
- median work ratio versus KLAG BE <=1.15.

## Work diagnostics

Report, but do not use as a primary qualification gate:

- total deterministic work by case;
- number of event-root localizations;
- number of persistent saturated-mode intervals;
- TG versus KLAG work distributions.

The work policy will be optimized only after correctness qualification.

## Frozen negative classifications

If exactly 1 to 4 cases remain incomplete while all safety and smooth gates pass:

`NLGLOB14E_NEAR_COMPLETE_DYNAMIC_POLICY`.

If >=5 cases remain incomplete:

`CLOSED_NLGLOB14E_DYNAMIC_POLICY_INCOMPLETE`.

If any physical mass, route or finite-state gate fails:

`CLOSED_NLGLOB14E_DYNAMIC_POLICY_PHYSICAL_ADMISSIBILITY_FAILED`.

If smooth second order regresses:

`CLOSED_NLGLOB14E_DYNAMIC_POLICY_ORDER_REGRESSION`.

If coverage fails:

`BLOCKED_NLGLOB14E_DYNAMIC_POLICY_COVERAGE`.

## Positive consequence

A positive result removes the frozen same-route dynamic-top endpoint blocker at research level.

It authorizes reopening TIMEINT17 same-route qualification with the assembled policy and then proceeding to explicit dynamic-top release/event semantics.

It does not authorize production admission by itself.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 24, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14E

BASELINE: `240a8a92b6403ebc8c749199b16fe44c971ee9d7`

BRANCH: `research/f-pe-nlglob14e-full-dynamic-policy`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: assemble the qualified research policy in the 96-case harness and execute the full bank plus smooth-order regression

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
