# F-PE-ELASTIC04 — typed per-layer ELAS architecture result

Date: 2026-09-29

Status: TYPED_OWNERSHIP_QUALIFIED_TEST_ONLY

Workflow: `36520242302`
Job: `109251288337`
Conclusion: PASS

## Qualified ownership

The test-only production-shaped contract uses:

- `elastic_storage_active` as explicit activation;
- `specific_elastic_storage(:)` in 1/cm;
- one value per active node/material layer.

ELAS is owned by soil-hydraulic material configuration. It is not owned by `soil_water_numerical_config_t`.

## Provider matrix

All 36 exact official Staringreeks 2018 materials pass.

Inactive typed route:
- theta bit-identical to current B1.10 default provider;
- C bit-identical;
- K bit-identical;
- reserved dK/dh output bit-identical.

Active typed route with ELAS=1e-6:
- theta identical to the already source-qualified legacy-ELAS test provider;
- C identical;
- K identical;
- dK/dh output identical.

## Heterogeneous-layer ownership

A synthetic node-varying ELAS profile passes direct identity checks:

- saturated theta uses each node's own ELAS;
- saturated C uses each node's own ELAS;
- no first-node or global-value leakage is observed.

## Dynamic identity

Typed-active versus legacy-ELAS execution passes for all eight seed fixtures:

- B01/WET;
- B01/POND;
- B12/WET;
- B12/POND;
- O05/WET;
- O05/POND;
- O14/WET;
- O14/POND.

For each completed comparison:
- solver success/failure class is identical;
- attempts/accepted/rejected counts are identical;
- nonlinear/backtracking/Jacobian/linear-solve counters are identical;
- runoff, ponding, terminal heads, storage and water ledger agree within 1e-12.

Current run result: all 8 seed fixtures completed and matched.

## Decision

The intended SWAP5 software architecture is qualified:

`soil/material authority -> per-layer specific_elastic_storage -> constitutive provider`

not

`global numerical config -> ELAS`.

## Production boundary

This qualification does not choose an ELAS value and does not derive one from soil properties.

It authorizes only the next engineering step: a bounded production extraction of the typed per-layer ELAS capability with default OFF, followed by production qualification.

No global default, Staringreeks lookup table or automatic pedotransfer rule is admitted here.
