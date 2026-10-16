# F-PE-TIMEINT17 requalification preregistration — complete same-route dynamic-top policy

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@69f10afaff5781ee4980dee3f1e63c898a0f4b4b`

Parent authority:

- TIMEINT16C: provider-consistent unsaturated TG is second order;
- NLGLOB12A1 / NLGLOB12C: representation-aware endpoint exhaustion is qualified at research level;
- NLGLOB14A: bracketed saturation-event localization qualified;
- NLGLOB14C: exact event remainder uses head/KLAG;
- NLGLOB14D: persistent saturated temporal mode qualified;
- NLGLOB14E1: complete assembled policy qualifies 96/96 frozen dynamic-top cases with explicit root-attempt observability.

## Purpose

The original TIMEINT17 closeout classified dynamic-top extension as blocked by endpoint globalization.

That blocker has since been removed by the NLGLOB01-14 evidence chain.

This workunit reopens TIMEINT17 only to requalify the same-route dynamic-top mechanism against the complete assembled research policy on the current canonical dependency surface.

It does not yet qualify physical saturated-mode release/desaturation semantics.

## Frozen assembled policy

For TG trajectories:

1. unsaturated provider-consistent second-order TG;
2. unchanged S0/R0 endpoint exhaustion certificates;
3. first saturation crossing localized by bracket-preserving event root;
4. exact event remainder integrated with head/KLAG;
5. subsequent nominal intervals use persistent saturated KLAG mode;
6. no saturation-root re-entry after persistent-mode entry.

KLAG comparison trajectories retain their existing formulation plus the same endpoint certificates.

## Frozen qualification bank

Use the complete established 96-case dynamic-top bank:

- materials: B01, B12, O05, O14;
- routes: FLUX, HEAD, RUNOFF;
- modes: TG and KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d.

Also rerun the original smooth TIMEINT16C bank.

## Frozen gates

Classify:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`

only if all hold:

1. 96/96 dynamic-top cases execute without process failure;
2. 96/96 complete the requested horizon;
3. all completed states are finite;
4. no unsafe terminal reason remains;
5. max accepted-interval physical ledger <= `5e-8 cm`;
6. max cumulative physical ledger <= `5e-8 cm`;
7. all saturated-mode entries have matching successful event switches;
8. no saturation-root attempt occurs after persistent saturated-mode entry;
9. both TG and KLAG span all four materials, all three routes and all four dt levels;
10. smooth TIMEINT16C bank remains:
   - 4/4 complete;
   - median refined head order >=1.6;
   - median refined moisture order >=1.6;
   - >=3/4 head ladders >=1.5;
   - physical/cumulative ledgers <= `5e-8 cm`;
   - median work ratio versus KLAG BE <=1.15.

If dynamic completeness fails:

`BLOCKED_TG_DYNAMIC_TOP_REQUALIFICATION_ROBUSTNESS`.

If mass/state/route gates fail:

`BLOCKED_TG_DYNAMIC_TOP_REQUALIFICATION_ADMISSIBILITY`.

If smooth order regresses:

`CLOSED_TG_DYNAMIC_TOP_REQUALIFICATION_ORDER_REGRESSION`.

## Interpretation boundary

A positive result supersedes the old TIMEINT17 endpoint-globalization blocker for same-route dynamic-top mechanism qualification.

It does not qualify:

- physical saturated-mode release/desaturation;
- HEAD -> FLUX release localization;
- runoff deactivation localization;
- general variable-step TG/LTE control;
- production source admission.

Those remain downstream.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 24, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-TIMEINT17-REQUAL

BASELINE: `69f10afaff5781ee4980dee3f1e63c898a0f4b4b`

BRANCH: `work/f-pe-timeint17-requalification`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: rerun the complete NLGLOB14E1 assembled policy as TIMEINT17 requalification authority

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
