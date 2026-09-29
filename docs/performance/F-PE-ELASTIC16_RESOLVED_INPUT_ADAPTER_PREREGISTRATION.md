# F-PE-ELASTIC16 — resolved soil-input adapter preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@dc12c52ea71e136cd9ea0573980915b8618ca7d6`

Parent authority:
- `F-PE-ELASTIC15_CLOSURE.md`;
- admitted ELASTIC14 mineral-prior materializer;
- admitted ELASTIC15 explicit generated-prior application binding.

## Purpose

Add a stateless outer application adapter that composes the already admitted
ELASTIC14 and ELASTIC15 contracts.

The adapter accepts already resolved per-node soil metadata plus an explicit
generated-prior request and returns a typed
`fmr_b110_physical_parameters_t` postimage.

It performs:

`resolved node metadata`
-> ELASTIC14 prior materialization
-> ELASTIC15 explicit binding
-> typed application parameter postimage.

## Architectural boundary

This adapter belongs outside the kernel and runtime owner.

It may:
- accept dry bulk density per active node;
- accept volumetric water content at the already frozen -100 cm reference state;
- accept explicit regime code per active node;
- call the admitted ELASTIC14 materializer;
- call the admitted ELASTIC15 binding;
- report detailed failure provenance.

It may not:
- fetch BOFEK/BRO;
- inspect coordinates, profile IDs or file paths;
- evaluate Staringreeks retention;
- choose a pressure-head reference;
- parse legacy or new input files;
- infer soil regime from MvG parameters;
- alter solver/timestep policy;
- mutate committed runtime state.

## Input contract

Inputs:
- immutable base `fmr_b110_physical_parameters_t`;
- logical `generated_prior_requested`;
- `rho_dry_g_cm3(:)`;
- `theta_ref_cm3_cm3(:)`;
- `regime(:)`.

When request is true:
- every array length must equal `active_nodes`;
- each node is materialized through ELASTIC14;
- the complete prior array is then bound atomically through ELASTIC15.

No partial column assignment is allowed.

## Default-off rule

When `generated_prior_requested=.false.`:

- adapter returns exact base-parameter identity;
- ELASTIC14 is not called;
- ELASTIC15 binding remains inactive;
- row 24 and `elasticity_active` remain unchanged.

## Existing explicit/user ELAS

The adapter does not implement source precedence itself.

If the base parameters already contain explicit/user ELAS, ELASTIC15 remains
the owner of conflict behavior and the adapter propagates that rejection
unchanged.

## Qualification matrix

A1. request=false -> exact parameter identity, no prior calls, no activation.

A2. valid heterogeneous MINERAL arrays -> node-local ELASTIC14 priors, then
ELASTIC15 binding, with exact equality to direct manual composition of the two
admitted helpers.

A3. existing explicit/user ELAS -> conflict propagated, no overwrite.

A4. one PEAT or otherwise rejected node -> whole-column fail closed and no
partial row-24 write.

A5. invalid array shape, non-finite/invalid soil metadata, or out-of-domain
node -> fail closed with failed-node diagnostics.

A6. successful adapter output passes normal preparation and
`specific_elastic_storage == cofgen(24,:)`.

A7. successful adapter output passes admitted ELASTIC09 application bootstrap
and is identical to equivalent direct typed execution.

A8. PPA-WU01 default-off preservation.

A9. O0/O2 identity.

A10. production source scope is exactly one new adapter module under
`src/adapter/**`; no runtime/kernel/legacy source is modified.

## Admission boundary

A green ELASTIC16 admits only resolved-input composition.

It does not admit:
- any file grammar;
- automatic soil-data lookup;
- BOFEK/BRO profile selection;
- layer-to-node interpolation rules;
- mixed mineral/peat partial assignment;
- automatic generated-prior request;
- default-on elasticity.
