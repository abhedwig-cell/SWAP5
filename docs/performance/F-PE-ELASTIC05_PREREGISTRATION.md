# F-PE-ELASTIC05 — production typed per-layer elastic storage

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_SOURCE_CHANGE

Base authority:
`integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`

Work branch:
`work/f-pe-elastic05-production-elastic-storage`

## Qualified research authority

F-PE-ELASTIC04 qualified, test-only:

- explicit activation;
- per-node/per-layer specific elastic storage in 1/cm;
- exact inactive preservation;
- exact legacy ELAS identity when active;
- heterogeneous-node ownership without leakage;
- dynamic identity on B01, B12, O05 and O14 WET/POND seed fixtures.

The exact corrected legacy semantics are:

- for `h >= 0` and elasticity active:
  `theta = theta_s + h * ELAS`;
- for `h >= 0` and elasticity active:
  `C = ELAS`;
- for `h < 0`: existing MvG behaviour;
- conductivity remains current MvG behaviour;
- when elasticity is inactive, current default saturated capacity fallback remains unchanged.

## Production objective

Extract the smallest typed production capability that makes elastic storage part of the soil-hydraulic material authority.

Preferred ownership:

- `b110_default_mvg_parameters_t` owns:
  - `elastic_storage_active`;
  - `specific_elastic_storage(:)`.
- `initialize_b110_default_mvg_parameters` accepts explicit optional activation and values.
- the default provider reads the prepared material authority only.
- default calls without the new optional inputs remain exact current behaviour.

This workunit does not introduce a user-facing parser keyword or a soil pedotransfer rule.

## Gates

### P0 source boundary

Before source change:
- current default provider and relevant runtime call sites are identified;
- no parallel canonical change overlaps the target files.

### P1 inactive preservation

Across exact Staringreeks-2018 B01..B18 and O01..O18:
- old initialization call and explicit elasticity-off initialization are bit-identical for theta, C, K and dK/dh-reserved output over a frozen head matrix.

### P2 active legacy identity

Across all 36 materials:
- typed production ELAS = 1e-6 matches the qualified legacy ELAS equations on positive heads;
- negative-head behaviour remains current default MvG.

### P3 heterogeneous profile

A node-varying ELAS vector must produce independent saturated theta/C per node with no first-node/global leakage.

### P4 dynamic seed identity

For B01, B12, O05 and O14 WET/POND:
- production typed ELAS and F-PE-ELASTIC04 qualified test provider have identical solver class;
- deterministic work counters identical;
- physical outputs equal within 1e-12.

### P5 default production preservation

Existing default-off production/runtime qualification gates remain green.

## Explicit exclusions

Not authorized here:

- default-on elasticity;
- hard-coded ELAS = 1e-6;
- deriving ELAS from MvG parameters;
- BOFEK/Staringreeks lookup as production policy;
- new input grammar;
- changes to timestep policy, convergence tolerances or mass gates;
- interpreting performance gains as evidence for a physical parameter value.

## Physical-parameter boundary

F-PE-ELASTIC03 established that the official Staringreeks hydraulic package lacks direct compressibility predictors/measurements. F-PE-ELASTIC05 therefore admits only the typed capability, not a physical assignment policy.

A later physical-policy workunit must use independent soil-mechanical/pedological evidence.

## Admission rule

Production admission requires all P1-P5 gates on a current-canonical-derived branch. Default-off preservation is mandatory.
