# F-DOC23 WOFOST and Snow authority matrix

Date: 2026-09-17

F-DOC23 adds reviewer-facing scientific reference pages for the bounded WOFOST81 runtime and restricted one-call-daily Snow capability. This matrix controls claim scope. It creates no new scientific authority and does not change the frozen Status-A denominator.

## Frozen denominator

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- F-DOC23 start canonical: `95d24660b51257119d5ee5fd25f2011e20b1dfa6`

## WOFOST81 authority

### Crop-owned scientific equivalence

F-WOF-PP01 independently qualified the verified SWAP 4.3.1 WOFOST81 donor against ten PCSE 6.0.13 Spring Barley potential-production cases. The admitted crop-owned output surface is:

- `DVS`
- `LAI`
- `NamountLV`
- `NamountRT`
- `NamountSO`
- `NamountST`
- `NuptakeTotal`
- `TAGP`
- `TWLV`
- `TWRT`
- `TWSO`
- `TWST`

`RD` and `TRA` are explicit non-equivalent SWAP interface quantities and remain outside that crop-state conformance surface.

F-WOF-PP02 then qualified the migrated SWAP5 WOFOST81 process kernels and owner composition against the same immutable PP01 reference surface over 10 cases, 1045 states and 1035 accepted transitions, with no first divergence and only floating-point roundoff within the unchanged PP01 precision contract.

### Runtime activation

F-CI89 qualifies runtime activation over one accepted daily crop event. Its admitted scope includes atomic crop-owner plus consumed-event receipt publication, rollback/failed-evolution zero leakage, duplicate-event fail-closed protection, committed-receipt-gated source-event retirement and the PP02 donor-equivalent N-unlimited request-equals-supply route.

F-CI89 explicitly excludes new crop physics, RD migration, TRA migration and Soil-N coupling policy.

### SWAP coupling interfaces

The frozen baseline exposes explicit crop-to-hydrology contracts:

- `src/crop/mod_crop_root_uptake_input_contract.f90`, blob `cc5594f6...`, carries emerged-state, nonnegative potential transpiration, rooted-node count and canonical cumulative root fractions to the root-water-uptake process;
- `src/crop/mod_crop_et_canopy_view_provider.f90`, blob `1234bcb8...`, reconstructs a canopy view from crop state and parameter tables.

The canopy provider has owner-candidate qualification in F-WOF43A, but that status explicitly required independent scientific verification before using the provider as standalone scientific admission. F-DOC23 may therefore describe the interface and exact frozen implementation expression, but must not promote F-WOF43A itself to independent scientific authority.

## Snow authority

The frozen process is `src/process/mod_snow_process.f90`, blob `54702d71b4c84dce2842813549bd14c57301a383`.

F-VQ16 independently qualifies exact B1.10 one-call-daily Snow scientific behaviour by bitwise identity with no new scientific tolerance. It qualifies component Snow mass terms and classifies melt as an internal transfer to the receiving surface/soil component.

F-PM02 reuses the immutable F-VQ16/F-VQ17 evidence because the exact Snow process blob and relevant runtime blobs remained unchanged. Current-canonical preservation passes one-call-daily, checkpoint/trial/retry/commit, mass, fail-closed subdaily/multiday, O0/O2 identity and serialized real-physics MultiSWAP checks.

## Claim ceilings

| Topic | Permitted claim | Explicit nonclaim |
| --- | --- | --- |
| WOFOST81 crop state | Explain the 12 PP01/PP02-qualified WOFOST-owned trajectories and their daily owner-state preservation | No claim that every WOFOST81 output or crop option is qualified |
| WOFOST81 daily runtime | Explain accepted daily event delivery, atomic owner/receipt publication, rollback and duplicate-event protection | No arbitrary subdaily crop stepping or retry policy beyond the admitted runtime contract |
| WOFOST-SWAP water interface | Explain that accepted-window actual root uptake and potential transpiration cross the runtime seam; explain canonical root-uptake input structure | `TRA` donor equivalence remains outside PP01/PP02; no broad hydrology equivalence claim |
| WOFOST canopy/ET interface | Describe frozen canopy-view formula and table dependencies as an implementation contract | Do not cite F-WOF43A owner qualification as independent scientific admission; no claim of full ET physics from this provider |
| WOFOST nitrogen | State that organ-N amounts, cumulative N uptake and the N-unlimited request-equals-supply route are within the bounded qualified surface | No Soil-N coupling policy or general nutrient-limited production claim |
| Snow temporal scope | Exactly one characterized legacy day per process call | No subdaily, multiday or arbitrary-duration Snow law |
| Snow storage and phase transfers | Explain Snow water storage, retained liquid storage, snowfall/rain inputs, sublimation, melt and liquid drainage according to the frozen source | Melt is not an external water loss; retained liquid water must not be double counted |
| Snow transaction/runtime | Explain candidate vs committed state, rollback, restart and serialized MultiSWAP preservation | No parallel real-physics admission, alternate Snow backend or new EB semantics |

## Publication rules

1. WOFOST scientific equivalence is bounded to the PP01/PP02 output surface. Runtime admission does not enlarge that scientific surface.
2. SWAP-owned `RD` and `TRA` remain explicit interfaces, not donor-equivalent WOFOST state.
3. A crop-to-ET or crop-to-root contract can be documented as an implementation boundary without claiming every upstream/downstream physical equation is independently requalified by that contract.
4. Snow is documented only as one-call-daily B1.10-compatible physics.
5. Snow melt is internal transfer; snowfall/rain and sublimation are component external mass terms in the F-VQ16 accounting scope.
6. Rejected trial state is not committed physical state for either crop or Snow.
7. No page created by F-DOC23 changes production source, reference source, scientific tolerances or admission scope.
