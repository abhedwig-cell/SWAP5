# F-PE-ELASTIC25 — explicit generated-prior application request preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@246eca153a7846c07e4981a07c6498528b771ee5`

Parent authority:
- `F-PE-ELASTIC15_CLOSURE.md`;
- `F-PE-ELASTIC24_CLOSURE.md`;
- admitted ELASTIC23 maparea-to-profile association;
- admitted ELASTIC22 explicit in-memory profile source.

## Purpose

Introduce the smallest application-level typed request seam required to connect
user/application configuration to the already admitted ELASTIC15 explicit
generated-prior binding.

The seam is:

`typed application config`
-> explicit generated-prior request
-> ELASTIC15 binding
-> existing ELAS runtime.

ELASTIC25 does not retrieve soil data, derive ELAS, parse files, inspect
coordinates, or activate ELAS directly.

## Configuration contract

Typed configuration fields:
- `supplied` logical;
- `key` character value;
- `value` character value.

Exactly one admitted key/value pair:

`ELASTIC_STORAGE_SOURCE = GENERATED_BOFEK_BRO_PRIOR`.

Trailing character padding is harmless.

No lowercase normalization, aliases, leading-space normalization, fuzzy
matching, implicit defaults or alternate generated sources are admitted.

## Request contract

Output is a typed request containing only:

`generated_prior_requested`.

Rules:
- config absent -> request false, status MISSING;
- exact admitted key/value -> request true, status OK;
- unsupported key -> request false, fail closed;
- unsupported value -> request false, fail closed.

The typed request does not contain a prior value, profile identity, source path,
coordinate or regime.

## Ownership invariants

ELASTIC25 must preserve:
- default OFF;
- explicit/user ELAS has higher ownership;
- ELASTIC15 remains the only seam that writes generated prior values into
  `cofgen(24,:)`;
- no generated prior is applied merely because BOFEK/BRO data exist;
- PEAT, ORGANIC_RICH_NONPEAT and UNKNOWN remain non-auto-assigned;
- no runtime network or source-profile lookup is introduced.

## Qualification matrix

A1. absent configuration returns false request and MISSING.

A2. exact admitted key/value returns true request and OK.

A3. unsupported key fails closed with false request.

A4. unsupported value fails closed with false request.

A5. case variants and leading-space variants fail closed; trailing padding
remains harmless.

A6. false request composes with ELASTIC15 as exact parameter identity/default
OFF.

A7. true request with valid MINERAL priors composes through ELASTIC15 and
applies generated priors.

A8. true request cannot override existing explicit/user ELAS; ELASTIC15 conflict
behavior is preserved.

A9. O0/O2 identity.

A10. production source scope is exactly one new typed application-config module;
no adapter/file-I/O, solver, kernel or legacy changes.

## Admission boundary

A green ELASTIC25 admits only the typed explicit request semantics.

Still outside scope:
- file syntax/parser for this request;
- CLI/environment syntax;
- location-to-maparea spatial selection;
- automatic profile selection;
- automatic request based on soil identity;
- runtime source acquisition.
