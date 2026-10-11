# F-PE-ELASTIC05 — production typed per-layer elastic storage result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Canonical base:
`integration/f-ci-canonical@71169681f1ba18d7aa999a5ff8a7666964072929`

Qualified head:
`work/f-pe-elastic05-production-elastic-storage@3d89652f7fbfb22e43d51015132ef6646a5f7810`

PR:
`#749`

Dedicated workflow:
`F-PE-ELASTIC05 production typed elastic storage`
run `36521596845`
conclusion: PASS

## Production source scope

Exactly two production source files are changed:

- `src/solver/mod_b110_default_mvg_provider.f90`
- `src/solver/mod_b110_default_mvg_directional_provider.f90`

No runtime/application parser, timestep policy, tolerance or transaction source is changed in this workunit.

## Qualified capability

`b110_default_mvg_parameters_t` now owns:

- `elastic_storage_active`, default `.false.`;
- `specific_elastic_storage(:)`, one value per active node/layer, in `cm^-1`.

When explicitly active and `h >= 0`:

- `theta = theta_s + h * ELAS`;
- `C = ELAS`.

For `h < 0`, the existing MvG route is unchanged.

When inactive, the existing saturated numerical capacity fallback remains unchanged.

The accepted-state directional provider is consistent with the active constitutive relation:

- for smooth `h > 0`, `dtheta/dh = ELAS`;
- saturated default-MvG conductivity direction remains zero in the qualified no-KSATEXM route;
- `h = 0` remains a constitutive branch boundary and is unavailable to the fixed-smooth directional service.

## Qualification evidence

Dedicated head qualification passes:

- exact 36-material Staringreeks 2018 provider matrix;
- explicit default-off identity;
- active legacy-ELAS constitutive identity;
- all demand-mask routes;
- heterogeneous per-node ELAS ownership;
- fail-closed missing, negative, NaN and shape-invalid values;
- fail-closed ELAS + KSATEXM composition;
- active saturated directional closure;
- `h=0` directional switch preservation;
- B01/B12/O05/O14 WET/POND dynamic identity against an independent corrected-legacy ELAS oracle;
- O0/O2 identity;
- exact bounded source scope;
- FKT22 default-off production compile preservation;
- FKT22 default-off serialized runtime preservation.

Dynamic seed results match the independent legacy oracle on solver status, accepted/rejected work counters and reported physical outputs.

## Generic preservation-workflow reconciliation

Several historical workflows are red on this PR. Their failure modes were inspected.

Examples:

- F-SI39 reports `F_SI39_FAIL unexpected production delta`;
- F-SI37 moving/admission workflows stop at their pinned authority/scope locks before numerical replay.

These checks are historical source/postimage preservation guards whose contracts reject later bounded production deltas by construction. They do not report an ELAS numerical, KSATEXM semantic, mass, solver or default-off regression.

The dedicated ELASTIC05 gate explicitly replays the relevant current default-off FKT22 compile/runtime preservation and passes.

Therefore these historical red checks are classified as expected preservation-scope conflicts, not substantive blockers for this bounded admission candidate.

## Scientific boundary

This workunit restores a capability, not a parameter policy.

It does not admit:

- default-on elastic storage;
- a universal `1e-6 cm^-1`;
- a Staringreeks/BOFEK ELAS table;
- an MvG-to-ELAS pedotransfer relation;
- legacy-file parser syntax;
- ELAS + KSATEXM;
- ELAS + direct retention/AHL;
- any solver-speed-based physical parameter selection.

## Decision

F-PE-ELASTIC05 is qualified as a bounded, opt-in production admission candidate.

The next runtime workunit is F-PE-ELASTIC08, which materializes the already existing application-side `elasticity_active` flag together with legacy `cofgen(24,:)` into this typed provider.

No physical ELAS assignment policy is implied by admission of F-PE-ELASTIC05.
