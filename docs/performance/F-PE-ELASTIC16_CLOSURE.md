# F-PE-ELASTIC16 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@a4f2873030d448d426757f46711c35083bde7c08`

Merged PR:
`#795`

Admitted production file:
`src/runtime/mod_fmr_elastic_storage_descriptor_assembly.f90`

Admitted production blob:
`d483ade2b80017b4e6e6826b5e3a3f984ed12f62`

## Admission summary

F-PE-ELASTIC16 admits typed application assembly from already resolved per-node
soil descriptors into the existing ELAS parameter route:

`rho_dry + theta_ref + regime`
-> ELASTIC14 prior materialization
-> ELASTIC15 explicit application binding
-> `elasticity_active + cofgen(24,:)`
-> ELASTIC08/05/09 runtime and constitutive path.

No external soil-data lookup, retention evaluation or parser behavior is added.

## Clean qualification authority

Clean extraction:

`work/f-pe-elastic16-current-clean-admission@3b31d53ba735a50f2ddb51c56d24c9d77852e6f1`

Result-document head:

`ab0c11c779797300fc4c4f1c99843575de4ef3b6`

Extraction base:

`integration/f-ci-canonical@dc12c52ea71e136cd9ea0573980915b8618ca7d6`

Qualification:
- workflow run `36558584722`;
- job `109373651165`;
- conclusion SUCCESS.

Named gates:
- A1 default-off identity: PASS;
- A2 manual ELASTIC14+ELASTIC15 composition identity: PASS;
- A3 descriptor fail closed: PASS;
- A4 shape fail closed: PASS;
- A5 explicit/user ELAS conflict preservation: PASS;
- A6 prepared-cache invalidation: PASS;
- A7 ELASTIC09 application/direct-runtime identity: PASS;
- A8 PPA-WU01 default-off preservation: PASS;
- A9 O0/O2 identity: PASS;
- A10 production source scope: PASS.

## Blob identity

The admitted canonical production blob is exactly the same as the qualified
clean-branch production blob:

`d483ade2b80017b4e6e6826b5e3a3f984ed12f62`.

No production source changed between clean qualification and canonical
admission.

## Admitted ownership semantics

### Resolved descriptor ownership

ELASTIC16 accepts only already resolved per-node descriptors:
- dry bulk density;
- volumetric water content at the frozen reference state;
- explicit regime.

It does not own how those descriptors are obtained.

### Explicit request

Generated-prior assembly remains opt-in.

When the request is false:
- descriptors are not consulted;
- parameters remain exact identity copies;
- ELAS remains default off.

### Atomic generation and binding

When requested:
1. every node descriptor is materialized through admitted ELASTIC14;
2. all priors must succeed before any binding occurs;
3. ELASTIC15 binds the complete prior vector atomically.

One invalid, non-mineral or out-of-domain node rejects the whole generated
assembly.

### Explicit/user ELAS

Existing explicit/user ELAS remains higher ownership.

Any such conflict is surfaced through ELASTIC15 and the generated assembly does
not overwrite it.

## Reference-state boundary

The admitted descriptor contract receives `theta_ref` already resolved.

The qualified physical convention remains:
`h_ref=-100 cm`.

ELASTIC16 itself does not calculate theta from pressure head and therefore does
not make Staringreeks or any retention implementation a hidden runtime
dependency.

## Production boundary

Still not admitted:
- automatic BOFEK/BRO lookup;
- profile/layer-ID resolution;
- Staringreeks retention evaluation inside runtime;
- parser/input-file syntax;
- automatic generated-prior request;
- mixed generated/user resolution inside one column;
- peat/high-organic generated assignment;
- state-dependent ELAS;
- performance-driven physical parameter selection.

## Preserved authority

Unchanged:
- ELASTIC05 constitutive semantics;
- ELASTIC08 runtime materialization;
- ELASTIC09 production bootstrap;
- ELASTIC14 physical prior materializer;
- ELASTIC15 explicit prior binding;
- user-owned explicit ELAS;
- default-off behavior;
- mass and transaction semantics;
- Full Richards reference path.

## Closure

F-PE-ELASTIC16 is canonically admitted and closed.

The remaining integration question is now outside the SWAP runtime core:
how application preprocessing obtains and persists the resolved descriptor
tuples that ELASTIC16 consumes.
