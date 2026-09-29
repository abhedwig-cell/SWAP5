# F-PE-ELASTIC15 — ELAS source-selection policy preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@ef08f11b5576bec92d66c445e0c577e680215487`

Parent authority:
- `F-PE-ELASTIC14_CLOSURE.md`;
- admitted ELASTIC05/08/09/14 production chain.

## Purpose

Add a small production policy resolver that chooses between:

1. no ELAS source (default OFF);
2. explicit user-supplied ELAS;
3. explicitly requested generated MINERAL prior.

This work unit does not:
- parse files;
- load BOFEK/BRO data;
- activate the runtime directly;
- write `cofgen(24,:)`;
- change constitutive physics;
- change solver policy.

It resolves source ownership only.

## Frozen precedence

Inputs:
- `user_supplied` logical;
- `user_value_cm_inv`;
- `generated_requested` logical;
- already materialized ELASTIC14 prior.

Precedence is frozen before implementation:

### P1 — explicit user override

If `user_supplied=.true.`, the user value is the only eligible source.

A valid user value:
- is finite;
- is nonnegative.

Then selection is:
`USER_EXPLICIT`.

This wins even when `generated_requested=.true.`.

### P2 — invalid user value never falls back

If `user_supplied=.true.` but the user value is invalid:

- return `INVALID_USER_VALUE`;
- activation decision is false;
- do not use a generated prior even if one is available.

### P3 — generated source

Only when `user_supplied=.false.` and `generated_requested=.true.`:

- generated prior must be available;
- generated prior must have positive finite prior value;
- uncertainty bounds must be finite and ordered;
- generated prior regime must be MINERAL.

Then selection is:
`GENERATED_MINERAL`.

Otherwise return:
`GENERATED_NOT_AVAILABLE`
and activation false.

### P4 — default OFF

When:
- no user value is supplied; and
- generated prior is not requested;

selection is:
`OFF`.

Activation false.

No nonzero row-24 value may implicitly activate this policy.

## Output contract

Return a typed decision containing:

- `activate`;
- selected scalar `value_cm_inv`;
- source enum:
  - OFF;
  - USER_EXPLICIT;
  - GENERATED_MINERAL;
- uncertainty availability;
- lower/upper uncertainty values;
- reference head when generated;
- generated domain class when generated.

For USER_EXPLICIT:
- uncertainty is unavailable;
- generated uncertainty metadata must not be fabricated.

For OFF or failure:
- `activate=.false.`;
- selected value = 0;
- uncertainty unavailable.

## Caller boundary

The resolver itself must never:
- set `elasticity_active`;
- write `cofgen(24,:)`.

A caller may explicitly apply a successful decision to the already admitted
ELASTIC08/09 application route.

## Qualification gates

A1. neither source requested -> OFF exactly;

A2. valid explicit user value -> USER_EXPLICIT exact scalar identity;

A3. user + generated simultaneously -> USER_EXPLICIT wins exactly;

A4. invalid user + valid generated -> INVALID_USER_VALUE, no fallback;

A5. generated-only valid mineral prior -> GENERATED_MINERAL with exact prior,
uncertainty and reference-head identity;

A6. generated-only unavailable / non-mineral / invalid metadata -> fail closed,
no activation;

A7. resolver construction/linking preserves PPA-WU01 default-off authority;

A8. explicit successful resolver decision copied by the test caller into
`cofgen(24,:)` with `elasticity_active=.true.` preserves ELASTIC09
application/direct-runtime identity;

A9. O0/O2 identity;

A10. production source scope is exactly one new source-selection module and no
existing production source is modified.

## Admission boundary

A green ELASTIC15 admits source-selection semantics only.

It does not admit:
- a parser keyword;
- automatic BOFEK lookup;
- automatic generated-prior request;
- automatic activation from soil identity;
- generated PEAT/high-organic ELAS;
- replacement of explicit user ELAS.
