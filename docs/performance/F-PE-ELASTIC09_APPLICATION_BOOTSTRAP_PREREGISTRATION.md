# F-PE-ELASTIC09 — production application bootstrap admission

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_APPLICATION_SOURCE_CHANGE

Prerequisites:
- F-PE-ELASTIC05 admitted to canonical;
- F-PE-ELASTIC08 serialized runtime materialization qualified/admitted.

## Current application boundary

Current production application configuration already owns:

`fmr_production_application_tile_config_t%parameters`

of type:

`fmr_b110_physical_parameters_t`.

That parameter type already contains:

- `elasticity_active`;
- `cofgen(:,:)`, including exact legacy ELAS row 24.

Current application bootstrap rejects elasticity explicitly in tile validation:

`.not. tile%parameters%elasticity_active`.

This is therefore an admission restriction, not a missing data model.

## Objective

Lift only the application-bootstrap rejection for the already qualified
serialized Reference/MvG ELAS envelope.

No new parameter field, parser syntax or default value is introduced.

## Required envelope

Application ELAS may be admitted only when:

- Reference serialized backend is selected;
- parameterized default MvG route is active;
- `elasticity_active=.true.`;
- `cofgen(24,:)` is finite and nonnegative;
- ELAS + KSATEXM is false;
- ELAS + direct retention/AHL is false;
- tabulated hydraulics is false;
- hysteresis is false;
- existing unsupported process combinations remain fail closed.

## Gates

### A1 bootstrap acceptance

A minimal valid application tile with ELAS active and valid row 24 must initialize
successfully and prepare exactly the same ELAS values as the direct serialized
runtime route.

### A2 default-off identity

The existing application bootstrap qualification must remain bit/semantic
preserved when `elasticity_active=.false.`.

### A3 heterogeneous node ownership

A node-varying `cofgen(24,:)` must survive application bootstrap and runtime
materialization without homogenization or first-node leakage.

### A4 fail-closed composition

Application bootstrap must reject:

- ELAS + KSATEXM;
- ELAS + direct retention/AHL;
- ELAS + tabulated hydraulics;
- ELAS + hysteresis;
- negative/non-finite row 24.

### A5 application dynamic identity

A production application trial using ELAS must match the already-qualified
ELASTIC08 serialized runtime on state, mass and solver diagnostics for the same
configuration.

## Explicit exclusions

F-PE-ELASTIC09 does not:

- choose or generate ELAS;
- activate elasticity by default;
- expose a legacy-file keyword;
- introduce a global numerical parameter;
- admit ELAS + KSATEXM/AHL;
- change timestep, convergence or transaction policy.

## Final intended path after admission

`application tile soil parameters`
-> `fmr_b110_physical_parameters_t{elasticity_active, cofgen(24,:)}`
-> `prepare_fmr_b110_default_mvg`
-> `b110_default_mvg_parameters_t{elastic_storage_active, specific_elastic_storage(:)}`
-> constitutive saturated storage.

This keeps ELAS owned entirely by the soil/material configuration.
