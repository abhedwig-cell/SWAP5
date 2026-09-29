# F-PE-ELASTIC15 — ELAS source-selection result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic15-source-selection`

Qualified postimage:
`2fcc8b613b1a06933adf21e508247faefe28269a`

Workflow run:
`36556809067`

Job:
`109367816374`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/runtime/mod_fmr_elastic_storage_source_selection.f90`.

No existing production source is modified.

The resolver only chooses source ownership between:
- OFF;
- explicit user ELAS;
- explicitly requested generated MINERAL prior.

It does not:
- write `cofgen(24,:)`;
- set `elasticity_active`;
- parse files;
- load BOFEK/BRO data;
- call the solver;
- change physical or numerical policy.

## Frozen precedence result

### A1 default OFF

With no user source and no generated request:
- selection source = OFF;
- activation decision = false;
- selected value = 0;
- no uncertainty metadata.

PASS.

### A2 explicit user

A valid finite nonnegative explicit user value is selected exactly.

PASS.

### A3 user override

When both:
- explicit user value is supplied;
- generated prior is requested;

the explicit user value wins exactly.

PASS.

### A4 invalid user never falls back

With:
- user source declared;
- invalid user value;
- valid generated prior also available;

the result is:
`INVALID_USER_VALUE`.

Activation remains false and generated fallback is prohibited.

PASS.

### A5 generated source

Generated-only selection preserves exact ELASTIC14 metadata:
- scalar prior;
- lower/upper uncertainty;
- reference head;
- predictor-domain class.

Representative generated value:

`2.7124308428813305e-6 cm^-1`.

PASS.

### A6 generated fail closed

Generated-only request fails closed when:
- prior unavailable;
- regime is non-mineral;
- uncertainty metadata is invalid.

No activation decision survives these cases.

PASS.

## Default-off preservation

PPA-WU01 application-bootstrap authority was replayed unchanged.

Marker:
`F_PE_ELASTIC15_A7_DEFAULT_OFF=PASS`.

Therefore linking the resolver alone changes no production ELAS state.

## Application bridge identity

A CI-only generated version of the admitted ELASTIC09 oracle exercised:

`ELASTIC14 materializer`
-> `ELASTIC15 generated-source selection`
-> explicit test-caller copy to row 24
-> explicit `elasticity_active=.true.`
-> admitted ELASTIC09 application route.

Application/direct-runtime identity passed at O0 and O2, including the existing
ELASTIC09 fail-closed checks.

Marker:
`F_PE_ELASTIC15_A8_BRIDGE_IDENTITY=PASS`.

## Optimization identity

Both:
- policy oracle;
- application bridge oracle

passed O0/O2 identity.

Markers:
- `F_PE_ELASTIC15_A9_POLICY_O0_O2=PASS`;
- `F_PE_ELASTIC15_A9_APPLICATION_O0_O2=PASS`.

## Source scope

Production delta:

`src/runtime/mod_fmr_elastic_storage_source_selection.f90`

only.

Marker:
`F_PE_ELASTIC15_A10_SOURCE_SCOPE=PASS`.

## Admission meaning

A green ELASTIC15 admits deterministic source precedence only.

It does not admit:
- parser syntax;
- automatic generated-prior request;
- automatic BOFEK/BRO lookup;
- automatic activation from soil identity;
- generated peat/high-organic ELAS;
- replacement of explicit user ELAS.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
