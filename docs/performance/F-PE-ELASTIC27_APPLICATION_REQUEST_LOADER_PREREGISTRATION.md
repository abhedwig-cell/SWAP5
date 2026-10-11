# F-PE-ELASTIC27 — explicit application request loader preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@c1713c35e0aeb1addec3bf7396ea8fe922761e85`

Parent authority:
- `F-PE-ELASTIC26_CLOSURE.md`;
- `F-PE-ELASTIC25_CLOSURE.md`;
- `F-PE-ELASTIC15_CLOSURE.md`.

## Purpose

Add one stateless application adapter that accepts an explicitly supplied local
config path, delegates file reading to ELASTIC26, delegates key/value semantics
to ELASTIC25, and returns only the typed generated-prior request.

The seam is:

`explicit config path`
-> ELASTIC26 file adapter
-> ELASTIC25 typed request semantics
-> `generated_prior_requested`.

## Ownership boundary

ELASTIC27 may:
- accept one caller-owned path;
- call ELASTIC26;
- call ELASTIC25;
- return nested status/provenance diagnostics.

ELASTIC27 may not:
- discover a default path;
- read environment variables;
- inspect CLI arguments;
- retrieve BOFEK/BRO data;
- perform spatial selection;
- derive or apply ELAS;
- change production application bootstrap state.

Empty path means no request and returns INACTIVE, not an implicit file lookup.

## Qualification matrix

A1. empty path returns inactive request, with no file access required.

A2. exact valid file yields `generated_prior_requested=.true.`.

A3. missing/unreadable file fails closed with false request.

A4. syntactically invalid file fails closed with ELASTIC26 provenance.

A5. syntactically valid unsupported key/value fails closed with ELASTIC25 provenance.

A6. no request path composes with ELASTIC15 as exact default-off identity.

A7. valid request composes with ELASTIC15 for valid MINERAL priors.

A8. explicit/user ELAS conflict remains rejected by ELASTIC15.

A9. O0/O2 identity.

A10. source scope is exactly one new application adapter plus tests/docs; no
solver/kernel/legacy changes.

## Admission boundary

A green ELASTIC27 admits explicit application-host path composition only.

Still outside:
- default file discovery;
- CLI/environment precedence;
- location-to-maparea spatial selection;
- automatic soil/profile choice;
- automatic request from soil identity.
