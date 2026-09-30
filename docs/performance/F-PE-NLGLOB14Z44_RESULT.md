# F-PE-NLGLOB14Z44 result — heterogeneous reference-validity fixture selection

Date: 2026-09-30

Status:

`Z44_REFERENCE_FIXTURES_UNAVAILABLE`

Qualification authority:

- workflow run: `36776149865`;
- reference-fixture-selection job: `110094433147`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z44-reference-fixture-selection@dfef209b67c19207aecae40d0f9aa44c632be967`

## Aggregate result

Neither O14 nor B12 has a reference-valid candidate within the frozen eight-candidate matrix.

Frozen classification:

`Z44_REFERENCE_FIXTURES_UNAVAILABLE`.

No adaptive moving-interface manager route is executed in Z44.

## O14

All eight frozen O14 candidates terminate because the full Heritage/reference solve stops converging before 4,000 intervals.

Accepted intervals before failure:

- tail 49, dt 0.00125 d: 285;
- tail 45, dt 0.00125 d: 7;
- tail 41, dt 0.00125 d: 318;
- tail 37, dt 0.00125 d: 422;
- tail 49, dt 0.000625 d: 51;
- tail 45, dt 0.000625 d: 15;
- tail 41, dt 0.000625 d: 18;
- tail 37, dt 0.000625 d: 25.

All failures classify `FULL_SOLVE_FAILED`.

Before failure:

- physical ledger remains near roundoff;
- no accepted-origin mutation is observed.

## B12

All eight frozen B12 candidates also terminate because the full Heritage/reference solve stops converging before 4,000 intervals.

Accepted intervals before failure:

- tail 49, dt 0.00125 d: 2,275;
- tail 45, dt 0.00125 d: 3,299;
- tail 41, dt 0.00125 d: 2,015;
- tail 37, dt 0.00125 d: 2,278;
- tail 49, dt 0.000625 d: 1;
- tail 45, dt 0.000625 d: 12;
- tail 41, dt 0.000625 d: 12;
- tail 37, dt 0.000625 d: 3.

Again:

- all failures classify `FULL_SOLVE_FAILED`;
- physical ledger remains near roundoff before stop;
- no origin leak occurs.

## Interpretation

Z44 does not identify a moving-interface portability failure.

It establishes that the frozen synthetic dry trajectories are unsuitable as heterogeneous admission holdouts because the **full reference path itself is not trajectory-valid** for O14 and B12 under the tested geometry/dt matrix.

This is consistent with Z43:

- O05/N64 remains a clean positive manager trajectory;
- O14 failed before adaptive-manager evaluation;
- Z44 shows that simply moving the initial tail or halving dt within the preregistered matrix does not repair reference validity.

The admission problem has therefore shifted from manager mechanism validation to **valid holdout design / qualified scope**.

## Qualified claim boundary

Qualified:

- all sixteen reference-only candidates were executed according to the frozen priority matrix;
- no valid O14 candidate exists in that matrix;
- no valid B12 candidate exists in that matrix;
- failure is in the full reference solve, not the manager;
- mass remains clean before the solve stop.

Not qualified:

- moving-interface portability to O14/B12 trajectories;
- a heterogeneous production admission candidate;
- canonical admission;
- production default change.

## Consequence

Do not continue searching tail start and dt combinations ad hoc.

The next workunit should make an explicit admission-scope decision before any further campaign:

1. either qualify a **narrow O05-like non-default admission scope** using already valid trajectories and explicit eligibility/fallback boundaries;
2. or construct heterogeneous holdouts from independently reference-qualified real/representative trajectory states rather than these synthetic hydrostatic dry trajectories.

The choice must be preregistered before new results.

## Production boundary

Reference-fixture preparation only.

No production admission is authorized.

`LEGACY_NUMERICS` remains production default.
