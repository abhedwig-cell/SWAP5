# F-PE-ELASTIC15 — explicit generated-prior application binding preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@15cd2388028d0eae2bec8ab5ab96db6aacf10497`

Parent authority:
- `F-PE-ELASTIC14_CLOSURE.md`;
- admitted ELASTIC05/08/09/14 chain.

## Purpose

Add an explicit application-level binding from already materialized MINERAL
ELAS priors to the admitted runtime parameter contract.

This work unit does not discover soil data and does not compute the physical
prior. It only performs the opt-in translation:

`resolved node priors + explicit request`
-> `elasticity_active + cofgen(24,:)`.

## Ownership boundary

The binding belongs to application/config assembly.

It may:
- accept already materialized ELASTIC14 prior objects;
- copy an existing `fmr_b110_physical_parameters_t`;
- on explicit request, populate row 24 for active nodes;
- set `elasticity_active=.true.`;
- invalidate any cached prepared-default-MvG view so normal preparation is
  rebuilt from the new parameter postimage.

It may not:
- fetch BOFEK/BRO;
- evaluate Staringreeks retention;
- classify a soil regime;
- calculate ELASTIC14 M1 priors;
- modify a prepared runtime in place;
- override existing explicit/user ELAS;
- change solver policy or numerical configuration.

## Input contract

Inputs:

- immutable base `fmr_b110_physical_parameters_t`;
- logical `generated_prior_requested`;
- one `fmr_elastic_storage_prior_t` per active node.

The node/layer discretization mapping is deliberately outside this binding.

## Default-off contract

When `generated_prior_requested=.false.`:

- output parameters must equal input parameters;
- no row-24 value changes;
- no activation occurs;
- status is `INACTIVE`.

## Existing-ELAS conflict

If `generated_prior_requested=.true.` while the base parameter set already has
`elasticity_active=.true.`, the binding fails closed with
`EXPLICIT_ELAS_CONFLICT`.

Generated priors must never silently overwrite an explicit/user-supplied ELAS
configuration.

## Prior eligibility

On explicit generated-prior request every active-node prior must:

- be available;
- have regime MINERAL;
- have domain class IN_DOMAIN or EDGE;
- have finite positive `value_cm_inv`.

If any active node fails, the whole binding fails closed and returns no
partially modified parameter postimage.

This means mixed mineral/peat columns are not silently partially assigned in
ELASTIC15. They require a separately resolved mixed-source policy.

## Shape and preparation gates

The binding requires:

- `active_nodes > 0`;
- prior count exactly equals active_nodes;
- allocated `cofgen`;
- `size(cofgen,1) >= 24`;
- `size(cofgen,2) >= active_nodes`.

On successful binding:

- only `cofgen(24,1:active_nodes)` changes;
- `elasticity_active=.true.`;
- `prepared_default_mvg_available=.false.`.

All other physical/numerical parameter fields remain identity copies.

## Qualification matrix

A1. request=false is exact parameter identity and remains default off.

A2. valid heterogeneous MINERAL priors bind node-locally to row 24 and activate
ELAS.

A3. active explicit/user ELAS conflicts and is not overwritten.

A4. unavailable, non-mineral, OUT-domain, non-finite/non-positive prior and
shape/count failures all fail closed atomically.

A5. successful binding invalidates prepared-default-MvG cache availability and
normal preparation reconstructs `specific_elastic_storage == cofgen(24,:)`.

A6. bound parameters pass the admitted ELASTIC09 production application route
and match the equivalent directly configured ELAS application result.

A7. O0/O2 identity.

A8. production source scope is exactly one new application-binding module; no
existing production source is modified.

## Production boundary

A green ELASTIC15 admits explicit opt-in application binding only.

It does not admit:
- automatic soil-data lookup;
- default-on generated priors;
- mixed generated/user source resolution;
- peat/high-organic generated assignment;
- input-file syntax;
- changing the qualified -100 cm physical reference convention.
