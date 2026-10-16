# F-PE-ELASTIC16 — resolved-descriptor ELAS application assembly result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic16-current-clean-admission`

Qualified clean postimage:
`3b31d53ba735a50f2ddb51c56d24c9d77852e6f1`

Current-canonical extraction base:
`integration/f-ci-canonical@dc12c52ea71e136cd9ea0573980915b8618ca7d6`

Workflow run:
`36558584722`

Job:
`109373651165`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/runtime/mod_fmr_elastic_storage_descriptor_assembly.f90`.

No existing production source is modified.

The helper only composes already admitted capabilities:

`resolved descriptors`
-> ELASTIC14 materialization
-> ELASTIC15 explicit binding
-> copied typed parameter postimage.

It does not fetch data, parse input, evaluate Staringreeks retention or alter
solver policy.

## Qualification

### A1 default-off identity

With generated-prior request false:
- output parameters remain exact identity copies;
- descriptor values are not consulted;
- ELAS remains unchanged.

PASS.

### A2 manual-composition identity

For heterogeneous valid MINERAL descriptors, output is identical to explicit
manual composition of ELASTIC14 followed by ELASTIC15.

PASS.

### A3 descriptor fail closed

Invalid descriptor input and PEAT regime reject the complete assembly with
failed-node provenance and no partial binding.

PASS.

### A4 shape fail closed

Wrong descriptor count is rejected before materialization and preserves the
base postimage.

PASS.

### A5 explicit/user ELAS conflict

Existing explicit/user ELAS is surfaced through the admitted ELASTIC15 conflict
and is not overwritten.

PASS.

### A6 cache invalidation

Successful composition preserves ELASTIC15 prepared-default-MvG cache
invalidation semantics.

PASS.

### A7 admitted application identity

A generated ELASTIC09 application oracle exercised:

`resolved descriptors -> ELASTIC16 -> production bootstrap`

and compared the application result against direct serialized execution from
the same assembled typed parameters.

Application bootstrap, heterogeneous ELAS preparation, committed state, mass
closure, application/direct identity and ELASTIC09 fail-closed gates all pass
at O0 and O2.

PASS.

### A8 default-off preservation

PPA-WU01 passes unchanged.

PASS.

### A9 O0/O2 identity

Both focused assembly and full application integration are identical at O0 and
O2.

PASS.

### A10 source scope

Production delta is exactly:

`src/runtime/mod_fmr_elastic_storage_descriptor_assembly.f90`.

No other `src/**` file changes.

PASS.

## Admission meaning

This candidate admits typed composition of already resolved per-node soil
descriptors through the already admitted ELASTIC14 and ELASTIC15 contracts.

It does not admit:
- BOFEK/BRO lookup;
- pressure-head-to-theta calculation;
- Staringreeks retention evaluation inside runtime;
- parser/input-file syntax;
- automatic generated-prior request;
- mixed generated/user resolution;
- peat/high-organic generated assignment;
- state-dependent ELAS;
- performance-driven physical parameter selection.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
