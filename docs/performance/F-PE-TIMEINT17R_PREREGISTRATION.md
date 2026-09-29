# F-PE-TIMEINT17R preregistration — same-route dynamic-top requalification after endpoint recovery

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@69f10afaff5781ee4980dee3f1e63c898a0f4b4b`

Parent authority:

- TIMEINT16C: `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`;
- TIMEINT17 original closeout: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB12A1: representation-aware endpoint certificate qualified at research level;
- NLGLOB14A: bracketed saturation-event localization qualified;
- NLGLOB14C: exact event remainder requires head/KLAG temporal formulation;
- NLGLOB14D: persistent saturated KLAG temporal mode qualified;
- NLGLOB14E1: `QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY` on the full frozen 96-case bank.

## Purpose

TIMEINT17R formally reopens the same-route dynamic-top mechanism question after the endpoint/globalization and near-saturation blockers were resolved in the NLGLOB successor chain.

No new numerical mechanism is introduced.

The complete NLGLOB14E1 research temporal policy is frozen and reused unchanged.

## Frozen assembled policy

For TG trajectories:

1. use provider-consistent second-order TG while unsaturated;
2. use unchanged S0/R0 research endpoint certificates;
3. on the first prospective accepted TG saturation crossing, localize the event by the qualified NLGLOB14A bracketed root solve;
4. integrate the exact event remainder with head/KLAG;
5. enter persistent saturated KLAG mode after a successful event interval;
6. reevaluate the dynamic-top provider every interval;
7. do not re-enter saturation-root localization while persistent saturated mode is active.

For KLAG comparison trajectories:

- retain the existing KLAG/head-based endpoint formulation;
- retain unchanged S0/R0 research endpoint certificates.

No saturated-mode release condition is introduced in TIMEINT17R.

## Frozen same-route bank

Reuse the exact 96-case TIMEINT17 A2 / NLGLOB bank:

- materials: B01, B12, O05, O14;
- routes: FLUX, HEAD, RUNOFF;
- modes: TG and KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d;
- unchanged route-margin fixtures;
- unchanged dynamic-top provider;
- unchanged constitutive provider;
- unchanged physical mass accounting;
- MAXIT = 8;
- MaxBackTr = 8.

No case removal is allowed after result exposure.

## Frozen same-route qualification gates

Classify:

`QUALIFIED_TIMEINT17R_SAME_ROUTE_DYNAMIC_TOP`

only if all hold:

1. 96/96 cases execute without process failure;
2. 96/96 cases complete the requested horizon;
3. all 3 intended routes, 4 materials, 4 dt levels and both modes are represented in the completed set;
4. no route-mismatch terminal reason occurs;
5. no predictor-domain failure occurs;
6. no saturation-root bracket/localization failure occurs;
7. no event-remainder or persistent-mode failure occurs;
8. no nonfinite accepted state occurs;
9. max accepted-interval physical ledger <= `5e-8 cm`;
10. max cumulative physical ledger <= `5e-8 cm`;
11. every saturated-mode entry has exactly one successful event switch;
12. all later persistent-mode intervals report successful KLAG execution;
13. zero root-localization attempts occur after persistent saturated-mode entry.

## Smooth temporal-order preservation

Rerun the original TIMEINT16C smooth bank unchanged.

Require:

- 4/4 complete ladders;
- median refined top-head order >=1.6;
- median refined top-theta order >=1.6;
- >=3/4 individual refined head orders >=1.5;
- physical/cumulative ledgers <= `5e-8 cm`;
- theta roundtrip <= `1e-12`;
- native endpoint balance residual <= `5e-8 cm/d`;
- median work ratio versus KLAG BE <=1.15.

## Frozen negative classifications

If numerical coverage fails:

`BLOCKED_TIMEINT17R_COVERAGE`.

If any physical mass, route, finite-state or event-state safety gate fails:

`CLOSED_TIMEINT17R_PHYSICAL_ADMISSIBILITY_FAILED`.

If smooth second order regresses:

`CLOSED_TIMEINT17R_ORDER_REGRESSION`.

If all numerical gates pass but event-state observability fails:

`BLOCKED_TIMEINT17R_EVENT_OBSERVABILITY`.

## Positive consequence

A positive TIMEINT17R result closes the original TIMEINT17 same-route dynamic-top mechanism blocker.

It authorizes a separate saturated-mode release/desaturation workunit.

Only after release semantics are qualified may broader dynamic event localization and TIMEINT18 variable-step/LTE proceed.

No production admission follows automatically.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 24, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-TIMEINT17R

BASELINE: `69f10afaff5781ee4980dee3f1e63c898a0f4b4b`

BRANCH: `work/f-pe-timeint17r-same-route-requalification`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: rerun the frozen complete dynamic-top policy as the formal TIMEINT17 same-route qualification

## Production boundary

Research requalification only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
