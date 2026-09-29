# F-PE-TIMEINT17R preregistration — reopened same-route dynamic-top qualification

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@69f10afaff5781ee4980dee3f1e63c898a0f4b4b`

Parent authority:

- TIMEINT16C: `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`;
- TIMEINT17 original closeout: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB12A1: `QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_CERTIFICATE_RESEARCH`;
- NLGLOB14A/C/D/E/E1: complete dynamic-top research policy qualified on the frozen 96-case bank, including explicit proof of zero post-entry saturation-root re-entry.

## Purpose

Reopen the original TIMEINT17 same-route qualification after its endpoint-robustness blocker has been removed by the bounded NLGLOB research chain.

TIMEINT17R does not invent a new temporal method.

It evaluates the complete already-qualified research policy against the original TIMEINT17 same-route scientific gates, using the now-complete dynamic-top dt ladders.

## Frozen assembled policy

For TG trajectories:

1. unsaturated provider-consistent endpoint-stage TG;
2. unchanged S0/R0 endpoint certificates;
3. bracketed first saturation-event localization when required;
4. head/KLAG integration of the exact event remainder;
5. persistent saturated KLAG mode after entry;
6. no saturation-root re-entry while persistent saturated mode is active.

KLAG comparison trajectories use the existing KLAG formulation plus unchanged S0/R0 endpoint certificates.

No production source is changed.

## Frozen qualification bank

Reuse the exact 96-case NLGLOB14E1 bank:

- materials: B01, B12, O05, O14;
- dynamic-top routes: FLUX, HEAD, RUNOFF;
- modes: TG and KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d;
- unchanged forcing and route-margin fixtures.

For TIMEINT17R temporal-order qualification, the primary TG ladders are the 12 material x route combinations, each with four dt levels.

The route identifier must remain unchanged for every accepted trajectory.

Saturation temporal-mode entry is allowed because it is now part of the qualified within-route temporal policy and is not a dynamic-top FLUX/HEAD/RUNOFF route transition.

## Frozen order measure

For each TG material/route ladder, use terminal:

- top pressure head;
- top water content.

Using the three refined levels `dt = 0.000125, 0.0000625, 0.00003125 d`, define:

`p = log2(|y_h-y_h/2| / |y_h/2-y_h/4|)`

when both differences exceed the existing numerical degeneracy floor used by TIMEINT16C.

No ladder is dropped for a poor observed order.

Degenerate ladders are reported separately and do not count as passing individual-order gates.

## Frozen same-route qualification gates

Classify:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE`

only if all hold:

1. 12/12 TG ladders complete at all four dt levels;
2. all 48 KLAG comparison trajectories complete;
3. median refined TG top-head order >= 1.6;
4. median refined TG top-moisture order >= 1.6;
5. at least 9/12 individual refined head orders >= 1.5;
6. max accepted-interval physical ledger <= `5e-8 cm`;
7. max cumulative physical ledger <= `5e-8 cm`;
8. max theta/head constitutive roundtrip <= `1e-12`;
9. predicted-K diagnostics finite and nontrivial on TG trajectories;
10. max endpoint native balance residual <= `5e-8 cm/d` wherever available;
11. no nonfinite completed state;
12. no dynamic-top route mismatch terminal reason;
13. median deterministic TG work per nominal step <= 1.20 times matched KLAG work per nominal step;
14. NLGLOB14E1 semantic guard remains true:
    - zero post-entry root attempts;
    - persistent saturated intervals all successful.

If order gates fail while coverage/mass/state pass:

`CLOSED_TG_DYNAMIC_TOP_SAME_ROUTE_ORDER_FAIL`.

If coverage or solve robustness fails:

`BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_ROBUSTNESS`.

If physical mass fails:

`BLOCKED_TG_DYNAMIC_TOP_SAME_ROUTE_CONSERVATION`.

## Interpretation boundary

A positive TIMEINT17R result closes only the original P0 same-route blocker positively.

Known-time external forcing events and physical desaturation/release semantics remain separate work.

The already qualified first saturation-entry localization is part of the assembled same-route policy; it does not imply that every other endogenous dynamic-top event semantics has been qualified.

## Consequence

A positive result authorizes an updated TIMEINT17 closeout that records:

- original endpoint-globalization blocker resolved;
- same-route dynamic-top mechanism qualified;
- physical saturated-mode release semantics still outstanding;
- TIMEINT18 variable-step/LTE remains downstream until the required event/release semantics are closed.

## Stop rules

Do not:

- tune dt ladders;
- discard low-order ladders;
- relax mass gates;
- alter S0/R0;
- alter saturation-event or persistent-mode rules;
- change MAXIT/backtracking;
- change production `src/**`.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 24, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-TIMEINT17R

BASELINE: `69f10afaff5781ee4980dee3f1e63c898a0f4b4b`

BRANCH: `work/f-pe-timeint17-reopen-dynamic-policy`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: run the assembled NLGLOB14E1 policy and evaluate all 12 dynamic-top TG ladders plus matched KLAG work

## Production boundary

Research/test-only.

No production source change.

`LEGACY_NUMERICS` remains production default.
