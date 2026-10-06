# F-MIG431-LOW03-EXP-P0 preregistration

Status: PREREGISTERED_SOURCE_RECONSTRUCTION. No production admission is claimed.

## Baseline

- canonical: `integration/f-ci-canonical@19d7ce86f71c7fa5fd3ed2c65a91dc705921f714`
- predecessor authority: `F-MIG431-LOW03-P0` and `F-MIG431-LOW03-A`
- closed predecessor: ordinary implicit `SWBOTB=3, SwBotb3Impl=1`
- target: explicit `SWBOTB=3, SwBotb3Impl=0` only

## Trigger

`integration/audits/F-MIG431-LOW03-A_STATUS.json` records:

`OPEN_NOT_ISSUED_REQUIRES_SEPARATE_GWL_AND_SATURATED_PROFILE_RECONCILE`.

This unit exists to reconstruct that missing source-bound contract before any shared Richards mutation is authorized.

## Scope

Determine from exact SWAP 4.3.1/B1.11 authority:

1. how the explicit mode derives groundwater level / pressure-head state;
2. which compartments are forced or reconstructed as saturated;
3. whether the operation occurs at initialization, trial preparation, accepted progress, or more than one boundary;
4. how aquifer head, RIMLAY/Q4 and any explicit/implicit selector branches interact;
5. which mutable state is authoritative and which values are derived;
6. water-mass consequences and sign conventions;
7. retry, rollback and restart requirements;
8. selector/index bounds and failure domain.

## Held fixed

Until source reconstruction proves otherwise, this unit MUST NOT change:

- the admitted implicit LOW03-A provider or its proposal-head/Q4 clocks;
- the admitted LOW03-P0 resistive bottom law;
- common solver residual/Jacobian semantics;
- groundwater/MODFLOW ownership or datum;
- transaction ledger ownership;
- Restart-v1 schema;
- SWBOTB=1, 2, 4, 5, 6, 7 or 8 semantics;
- RossFast, SWKIMPL1, macropore or sensitivity semantics.

If explicit mode requires a shared contract change, persist the finding and issue a separate shared prerequisite before implementation.

## Initial dependency surface

- exact B1.11 lower-boundary and soil-water source authority;
- `src/legacy/b1_10_port/headcalc.f90`;
- `src/solver/mod_soil_water_solver_contract.f90`;
- `src/adapter/mod_reference_richards_legacy_binding.f90`;
- `src/runtime/mod_fmr_legacy_cauchy_bottom_boundary_provider.f90`;
- `src/runtime/mod_fmr_serialized_reference_backend.f90`;
- `src/runtime/mod_fmr_production_application_bootstrap.f90`;
- committed/trial soil-water state and restart authority.

## Required reconstruction result

Before production implementation, persist a source-bound decision containing:

- exact source locations/hashes;
- explicit-mode equations/control flow;
- GWL/index/bounds semantics;
- saturated-profile state transition;
- ownership classification;
- mass/retry/restart contract;
- minimal implementation surface;
- whether a shared prerequisite is required.

## Qualification obligations if implementation is later authorized

At minimum:

- independent source oracle for GWL/profile reconstruction;
- O0/O2;
- dry/partly saturated/fully saturated boundary cases;
- index and bounds edge cases;
- reject/replay and shortened retry;
- hard whole-column mass closure;
- fresh-backend Restart-v1 continuation if committed state changes;
- A/B/A isolation;
- preservation of implicit LOW03-A and admitted lower-boundary selectors;
- no hidden groundwater owner or second mass term.

## Claim ceiling

This work unit can close only ordinary explicit `SWBOTB=3, SwBotb3Impl=0` within the eventually qualified profile. It cannot unpark SWBOTB=1 or broaden groundwater, RossFast, macropore, solver-policy or management scope.
