# F-PE-ELASTIC16 — resolved-descriptor ELAS application assembly preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@c9ffec5cae9a6aa20a0ae7225b921933520907d3`

Parent authority:
- `F-PE-ELASTIC14_CLOSURE.md`;
- `F-PE-ELASTIC15_CLOSURE.md`;
- admitted ELASTIC05/08/09 chain.

## Purpose

Add the smallest typed application-assembly helper that composes the already
admitted physical-prior materializer and explicit application binding:

`resolved per-node soil descriptors + explicit generated-prior request`
-> ELASTIC14 prior materialization
-> ELASTIC15 application binding
-> bound `fmr_b110_physical_parameters_t`.

This work unit adds no new physical relation.

## Ownership boundary

The helper may:
- accept immutable base parameters;
- accept one resolved descriptor tuple per active node;
- invoke ELASTIC14 for each tuple;
- invoke ELASTIC15 once all node priors are valid;
- return a copied bound parameter postimage and diagnostics.

The helper may not:
- fetch BOFEK/BRO;
- resolve profile/layer IDs;
- evaluate Staringreeks retention;
- infer theta from pressure head;
- classify regime from MvG parameters;
- parse files;
- choose whether generated priors should be requested;
- overwrite explicit/user ELAS;
- change numerical policy.

## Input contract

Per active node:

- `rho_dry_g_cm3`;
- `theta_ref_cm3_cm3`;
- explicit ELASTIC14 regime code.

Application input:

- immutable base `fmr_b110_physical_parameters_t`;
- logical `generated_prior_requested`;
- descriptor array with count exactly equal to active_nodes.

The frozen physical reference state remains external and unchanged:
`h_ref=-100 cm`.

The helper does not evaluate that state itself; `theta_ref` is already resolved
by preprocessing/application assembly.

## Default-off contract

When `generated_prior_requested=.false.`:

- output parameters are exact copies;
- no descriptor validation is required;
- no prior is materialized;
- ELAS remains unchanged;
- status is INACTIVE.

## Generated request

When requested:

1. shape must be valid;
2. each descriptor is materialized through ELASTIC14;
3. every prior must return ELASTIC14 OK and available;
4. only after all priors succeed may ELASTIC15 bind them;
5. any node failure rejects the whole assembly atomically.

No partial row-24 assignment is permitted.

## Explicit/user ELAS conflict

Existing explicit/user ELAS ownership remains ELASTIC15 authority.

If base parameters already carry active or dormant explicit row-24 ELAS,
ELASTIC16 must surface the ELASTIC15 conflict and return the unmodified copied
parameter postimage.

No fallback or overwrite is permitted.

## Diagnostics

Return:

- top-level status:
  - OK;
  - INACTIVE;
  - INVALID_SHAPE;
  - PRIOR_REJECTED;
  - BIND_REJECTED;
- failed_node;
- per-failure ELASTIC14 status where applicable;
- ELASTIC15 binding status;
- generated_prior_applied;
- prepared_cache_invalidated.

## Qualification matrix

A1. request=false is exact parameter identity and remains default off.

A2. heterogeneous valid MINERAL descriptors produce the exact same node priors
and bound parameters as explicit manual ELASTIC14 + ELASTIC15 composition.

A3. invalid descriptor, PEAT/high-organic/unknown regime, or out-of-domain
descriptor fails closed atomically with failed-node provenance.

A4. wrong descriptor count / invalid active-node shape fails closed.

A5. existing explicit/user ELAS conflict is preserved exactly through ELASTIC15
and no generated value overwrites it.

A6. successful assembly invalidates prepared-default-MvG cache exactly as
ELASTIC15 requires.

A7. successfully assembled parameters pass the admitted ELASTIC09 application
route and match direct serialized execution from the same bound parameters.

A8. PPA-WU01 default-off preservation.

A9. O0/O2 identity.

A10. production source scope is exactly one new assembly module; no existing
production source is modified.

## Admission boundary

A green ELASTIC16 admits typed composition only.

It does not admit:
- BOFEK/BRO lookup;
- Staringreeks theta calculation inside runtime;
- parser/input-file syntax;
- automatic generated-prior request;
- mixed generated/user source resolution;
- peat/high-organic generated assignment;
- state-dependent ELAS;
- solver-performance tuning.
