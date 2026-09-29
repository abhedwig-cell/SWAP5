# F-PE-ELASTIC08 — runtime per-layer ELAS materialization

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_RUNTIME_SOURCE_CHANGE

Prerequisite:
F-PE-ELASTIC05 production typed per-layer constitutive capability must qualify/admit first.

## Newly closed architecture fact

Current canonical already contains both required application-side ingredients in
`fmr_b110_physical_parameters_t`:

- `logical :: elasticity_active = .false.`
- `real(real64), allocatable :: cofgen(:,:)`

The exact corrected legacy provenance binds:

`cofgen(24,:) = ELAS(:)`.

Therefore no new global numerical setting, no new per-layer array and no new
application-config field are required to restore ELAS ownership at the runtime seam.

## Current gap

`prepare_fmr_b110_default_mvg` currently calls:

`initialize_b110_default_mvg_parameters(..., enable_ksatexm_extension=...)`

without forwarding elasticity.

The serialized execution admission also currently requires:

`.not. parameters%elasticity_active`.

Thus current runtime data already carries the value location and activation flag,
but the typed provider route deliberately stops before materializing them.

## Candidate minimal mapping

After ELASTIC05 is admitted, the runtime mapping shall be exactly:

- `enable_elastic_storage = parameters%elasticity_active`
- when active:
  `specific_elastic_storage_input = parameters%cofgen(24,:)`

No value transformation is authorized.

## Validation requirements

When `elasticity_active=.true.`:

- `cofgen` must have at least 24 rows;
- `cofgen(24,:)` must be finite;
- `cofgen(24,:)` must be nonnegative;
- ELAS + KSATEXM must fail closed until separately qualified;
- direct-retention/AHL composition must remain excluded unless separately qualified;
- tabulated hydraulics remain excluded;
- default-off behavior must remain exact.

When `elasticity_active=.false.`:

- row 24 may remain present but is constitutively inactive;
- existing behavior must be bit-identical.

## Gates

### R1 preparation identity

For all 36 exact Staringreeks 2018 materials:

- prepare with elasticity OFF equals current preparation exactly;
- prepare with elasticity ON and `cofgen(24,:)=1e-6` yields a prepared provider
  identical to direct F-PE-ELASTIC05 initialization.

### R2 heterogeneous per-layer ownership

Use a node-varying row 24 and prove that the prepared provider preserves each
node's own ELAS without first-node/global leakage.

### R3 serialized runtime dynamic identity

For B01, B12, O05 and O14 WET/POND:

- runtime materialization through `fmr_b110_physical_parameters_t` must match
  direct F-PE-ELASTIC05 provider execution in solver status, work counters and
  physical outputs.

### R4 fail-closed composition

Explicitly test:

- ELAS + KSATEXM => rejected;
- ELAS + direct retention => rejected;
- ELAS + tabulated hydraulics => rejected;
- NaN/negative row 24 => rejected.

### R5 application bootstrap

The production application bootstrap currently rejects `elasticity_active`.
A bounded successor may lift this rejection only after serialized runtime R1-R4
pass and only for the already-qualified Reference/MvG envelope.

## Scientific boundary

This workunit restores transport of a pre-existing soil parameter.

It does not:
- choose ELAS;
- set `1e-6` as a default;
- derive ELAS from MvG parameters;
- infer activation from nonzero row 24;
- introduce legacy parser syntax;
- fit against runtime speed.

## Intended final ownership

`soil/material input -> cofgen(24,:) + elasticity_active -> typed prepared MvG parameters -> constitutive ELAS`.

This is the shortest architecture consistent with both legacy source provenance
and current SWAP5 runtime structure.
