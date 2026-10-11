# F-PE-ELASTIC09 — production application bootstrap admission

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_APPLICATION_SOURCE_CHANGE

Base authority:
`integration/f-ci-canonical@7d4aa0cb6790f293ff486f716c6c4eadd7d18eb8`

Prerequisites:
- F-PE-ELASTIC05 admitted;
- F-PE-ELASTIC08 admitted.

## Current application boundary

`fmr_production_application_tile_config_t%parameters` already is
`fmr_b110_physical_parameters_t` and therefore already carries:

- `elasticity_active`;
- `cofgen(:,:)`, including exact legacy `cofgen(24,:)=ELAS(:)`.

Current application bootstrap rejects `elasticity_active` explicitly. This is
an admission restriction, not a missing data model.

## Objective

Lift only that bootstrap rejection for the already-qualified serialized
Reference/MvG ELAS envelope.

No new parameter field, parser syntax or default value is introduced.

## Required envelope

Application ELAS may be admitted only when:

- serialized Reference backend is selected;
- default MvG route is active;
- `elasticity_active=.true.`;
- `cofgen(24,:)` is finite and nonnegative;
- ELAS + KSATEXM is false;
- ELAS + direct retention/AHL is false;
- tabulated hydraulics is false;
- hysteresis is false;
- existing unsupported process combinations remain fail closed.

## Gates

### A1 bootstrap acceptance

A valid application tile with ELAS active and valid row 24 must initialize
successfully and retain prepared ELAS exactly.

### A2 default-off identity

Existing PPA-WU01 bootstrap qualification must remain preserved when elasticity
is off.

### A3 heterogeneous ownership

A node-varying row 24 must survive application bootstrap and runtime preparation
without homogenization or first-node leakage.

### A4 fail-closed composition

Bootstrap must reject:
- ELAS + KSATEXM;
- ELAS + direct retention/AHL;
- ELAS + tabulated hydraulics;
- ELAS + hysteresis;
- negative/non-finite row 24.

### A5 dynamic identity

A production-application trial with ELAS must match the already-qualified
ELASTIC08 serialized runtime for equivalent configuration.

## Exclusions

No:
- ELAS value selection;
- default-on elasticity;
- legacy parser keyword;
- global numerical ELAS;
- ELAS + KSATEXM/AHL admission;
- timestep/convergence/transaction-policy change.

## Final ownership path

`application tile soil parameters`
-> `fmr_b110_physical_parameters_t{elasticity_active, cofgen(24,:)}`
-> `prepare_fmr_b110_default_mvg`
-> `b110_default_mvg_parameters_t{elastic_storage_active, specific_elastic_storage(:)}`
-> constitutive saturated storage.
