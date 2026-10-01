# PPA-WU05-A9 preregistration — FMR source-faithful macropore top input

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline: `integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

## Purpose

Extend the canonically admitted bounded A8 serialized single-column Reference-Richards macropore route with source-faithful surface-connected top input.

A9 does not reopen A8. It adds one bounded forcing seam only.

## Source authority

Exact B1.11 source mapping established in PPA-WU05-A5/A6:

- direct vertical macropore input when macropores reach the surface:
  `ArMpTpDm(id) * (NRaiDt + NIrd + Melt) * dt`;
- lateral surface contribution:
  `ArMpTpDm(id)/ArMpTp * QMpLatSs`;
- unused top share is returned to the owning surface/lateral route;
- `QMpLatSs` is a distinct upstream overland/infiltration-excess carrier and must not be reconstructed from generic matrix `top_flux`.

## Admitted-candidate scope

Only:

- standard `swmbf=1` route;
- macropores reaching the soil surface;
- serialized single-column FMR;
- Reference Richards;
- explicit nonnegative net-rain, net-irrigation and melt rates;
- explicit nonnegative lateral-overland-to-macropore amount/rate from its owning surface process;
- partition using current macropore top geometry;
- top-capacity limitation, cross-domain redistribution and returned-surface receipt through already qualified A5/A6 logic.

## Explicit exclusions

A9 does not admit or infer:

- ponding or runon as independent macropore sources;
- reconstruction of rain/irrigation/melt from `top_flux`;
- a synthetic estimate of `QMpLatSs` from matrix infiltration or runoff;
- covering-layer `IcTopMp > 1` physics;
- perched-zone physics;
- rapid drainage;
- dynamic crack-displacement feedback inside one corrector;
- RossFast;
- parallel/concurrent MultiSWAP.

Unsupported combinations remain fail-closed.

## Ownership invariants

1. Top forcing is explicit dynamic forcing, never immutable macropore configuration.
2. Direct vertical forcing and lateral-overland forcing remain distinct receipts.
3. Rejected candidates do not mutate committed matrix/macropore state or publish accepted top receipts.
4. Returned/unaccepted macropore top water remains owned by the outer surface route.
5. The inner Reference-Richards request remains `macropore_active=.false.`; coupling stays outer and transactional.
6. Whole-column external mass books accepted macropore top input exactly once.
7. Existing A8 zero-top-input behaviour must remain preserved.

## Qualification plan

Focused local/static work first. GitHub Actions only for the persisted exact postimage.

Required tests:

- forcing DTO validation and fail-closed negative/ambiguous cases;
- source-equation top partition for one and multiple domains;
- exact top receipt identity;
- zero-forcing A8 preservation;
- real serialized FMR wetting trial;
- candidate-only publication and discard/retry;
- commit;
- restart/replay continuation;
- whole-column mass closure;
- unsupported rapid/perched/covering-layer combinations fail closed.

## Exit criteria

A9 may close only as one of:

- `QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_FMR_MACROPORE_TOP_INPUT`;
- `SOURCE_FORCING_CONTRACT_BLOCKED`;
- `MASS_OWNERSHIP_FALSIFIED`;
- `TRANSACTIONAL_SEMANTICS_FALSIFIED`;
- `ROUTE_EXPLICITLY_FALSIFIED`.

