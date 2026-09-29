# F-PE-ELASTIC16 — resolved-descriptor ELAS application assembly result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic16-descriptor-assembly`

Qualified postimage:
`595e5dff22f6453c19785de1de4cb13b9b0210e6`

Workflow run:
`36558154215`

Job:
`109372228501`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/runtime/mod_fmr_elastic_storage_descriptor_assembly.f90`.

No existing production source is modified.

The helper only composes already admitted capabilities:

`resolved descriptors`
-> ELASTIC14 materializer
-> ELASTIC15 explicit binding
-> copied typed parameter postimage.

## A1 default-off identity

With generated-prior request false:
- output parameters are exact identity copies;
- descriptor values are not consulted;
- ELAS remains unchanged and inactive.

Marker:
`F_PE_ELASTIC16_A1_DEFAULT_OFF=PASS`.

PPA-WU01 also passes unchanged:

`F_PE_ELASTIC16_A8_DEFAULT_OFF=PASS`.

## A2 exact manual-composition identity

For heterogeneous valid MINERAL descriptors, ELASTIC16 output is compared
against explicit manual composition of:
- ELASTIC14 prior materialization per node;
- ELASTIC15 application binding.

The resulting:
- `cofgen`;
- `elasticity_active`;
- prepared-cache availability

are identical.

Marker:
`F_PE_ELASTIC16_A2_MANUAL_COMPOSITION_IDENTITY=PASS`.

## A3 descriptor fail closed

A PEAT descriptor or invalid physical descriptor causes:
- whole-assembly rejection;
- failed-node provenance;
- no partial row-24 change;
- no activation drift.

Marker:
`F_PE_ELASTIC16_A3_DESCRIPTOR_FAIL_CLOSED=PASS`.

## A4 shape fail closed

Wrong descriptor count is rejected before composition and preserves the base
parameter postimage.

Marker:
`F_PE_ELASTIC16_A4_SHAPE_FAIL_CLOSED=PASS`.

## A5 explicit/user ELAS conflict preservation

When base parameters already carry explicit/user ELAS, ELASTIC16 surfaces the
admitted ELASTIC15 conflict.

Existing row-24 values and activation remain preserved.

Marker:
`F_PE_ELASTIC16_A5_EXPLICIT_CONFLICT=PASS`.

## A6 prepared-cache invalidation

Successful assembly inherits the ELASTIC15 cache-invalidating contract.

Marker:
`F_PE_ELASTIC16_A6_CACHE_INVALIDATION=PASS`.

## A7 admitted application identity

A CI-only generated ELASTIC09 application oracle:

1. starts with default-off parameters;
2. supplies heterogeneous resolved MINERAL descriptors;
3. assembles through ELASTIC16;
4. runs normal production bootstrap;
5. compares against direct serialized execution from the same assembled typed
   parameters.

The following pass:
- application bootstrap;
- heterogeneous ELAS preparation;
- committed state;
- mass closure;
- application/direct serialized identity;
- existing ELASTIC09 fail-closed option checks.

Marker:
`F_PE_ELASTIC16_A7_APPLICATION_IDENTITY=PASS`.

## A8 default-off preservation

PPA-WU01 is preserved unchanged.

Marker:
`F_PE_ELASTIC16_A8_DEFAULT_OFF=PASS`.

## A9 O0/O2 identity

Both focused assembly and full application integration pass O0/O2 identity.

Markers:
- `F_PE_ELASTIC16_A9_ASSEMBLY_O0_O2=PASS`;
- `F_PE_ELASTIC16_A9_APPLICATION_O0_O2=PASS`.

## A10 source scope

Production delta is exactly:

`src/runtime/mod_fmr_elastic_storage_descriptor_assembly.f90`.

No other `src/**` file changes.

Marker:
`F_PE_ELASTIC16_A10_SOURCE_SCOPE=PASS`.

## Admission meaning

A green ELASTIC16 admits typed descriptor-to-parameter composition only.

It does not admit:
- BOFEK/BRO lookup;
- Staringreeks retention evaluation in runtime;
- pressure-head-to-theta calculation;
- parser/input-file syntax;
- automatic generated-prior request;
- mixed generated/user resolution;
- peat/high-organic generated assignment;
- state-dependent ELAS;
- numerical/performance tuning.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
