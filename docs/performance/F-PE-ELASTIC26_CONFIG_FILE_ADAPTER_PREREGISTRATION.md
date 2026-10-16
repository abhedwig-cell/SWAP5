# F-PE-ELASTIC26 — application request file adapter preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@a6e4579a98b127eb95f271e855aafe9d1e394c80`

Parent authority:
- `F-PE-ELASTIC25_CLOSURE.md`;
- `F-PE-ELASTIC15_CLOSURE.md`.

## Purpose

Add a bounded stateless file adapter that reads one local application-config
assignment and materializes the typed ELASTIC25 application config.

The seam is:

`local config file`
-> typed `fmr_elastic_storage_application_config_t`
-> ELASTIC25 exact request semantics
-> ELASTIC15 explicit generated-prior binding.

No solver/runtime component performs file I/O.

## File grammar

The file must contain exactly one non-empty assignment:

`ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR`

The adapter itself preserves key/value text. ELASTIC25 owns whether the
key/value is supported.

Rules:
- blank lines are ignored;
- one non-empty assignment only;
- exactly one `=` in the assignment;
- key and value must both be non-empty after right/left trimming consistent
  with existing application config adapters;
- maximum file size 4096 bytes;
- no comments, includes, aliases or environment substitution.

## Fail-closed behavior

Fail closed on:
- empty path;
- missing/unreadable file;
- I/O failure;
- empty file;
- malformed assignment;
- multiple non-empty assignments;
- oversized file.

On failure the returned typed config is reset to default `supplied=.false.`.

## Ownership boundary

ELASTIC26 owns file syntax and local file reading only.

It does not own:
- whether a key/value is supported;
- generated-prior eligibility;
- ELAS activation;
- profile/source retrieval;
- spatial selection;
- network I/O;
- automatic request creation.

ELASTIC25 remains the typed semantic gate.

## Qualification matrix

A1. exact one-line file materializes the exact ELASTIC25 key/value.

A2. blank lines around the assignment do not change the typed result.

A3. empty path and missing file fail closed.

A4. empty/malformed assignment fails closed.

A5. multiple assignments fail closed.

A6. oversized file fails closed.

A7. syntactically valid but unsupported key/value reaches ELASTIC25 unchanged
and is rejected there, proving parser/semantic ownership separation.

A8. valid file composes through ELASTIC25 to
`generated_prior_requested=.true.`.

A9. O0/O2 identity.

A10. production source scope is exactly one new adapter module; no runtime,
solver, kernel or legacy source change.

## Admission boundary

A green ELASTIC26 admits only this bounded local application file syntax.

Still outside scope:
- automatic loading by the Richards solver;
- implicit default config path;
- CLI/environment precedence;
- location-to-maparea spatial selection;
- automatic profile choice;
- automatic request from soil identity.
