# F-PE-ELASTIC31 — application request discovery composition preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@e31992877058a8f08975689721d5d3e3f1fb940e`

Parent authority:
- `F-PE-ELASTIC30_CLOSURE.md`;
- `F-PE-ELASTIC29_CLOSURE.md`;
- `F-PE-ELASTIC28_CLOSURE.md`;
- `F-PE-ELASTIC27_CLOSURE.md`.

## Purpose

Add one bounded application adapter that composes the three currently admitted
configuration-path source mechanisms:

- caller-supplied explicit application path;
- ELASTIC30 CLI-derived path;
- ELASTIC29 environment-derived path;

then delegates source arbitration to ELASTIC28 and selected-path loading to
ELASTIC27.

The seam is:

`explicit path + CLI source + environment source`
-> ELASTIC28 arbitration
-> selected path or inactive/conflict
-> ELASTIC27 request loader
-> typed generated-prior request.

## Explicit path contract

The caller supplies the explicit application path directly to the subroutine.

Rules:
- empty path -> explicit candidate absent;
- non-empty path -> explicit candidate supplied exactly;
- no trimming, normalization or file probing occurs before ELASTIC28/27.

## Composition policy

ELASTIC31 does not assign precedence.

- zero sources -> INACTIVE;
- exactly one source -> selected and loaded;
- multiple sources -> SOURCE_CONFLICT, fail closed;
- invalid environment/CLI source -> SOURCE_READ_REJECTED, fail closed;
- selected path rejected by ELASTIC27 -> REQUEST_REJECTED, fail closed.

No selected path is loaded when source arbitration fails.

## Ownership boundary

ELASTIC31 owns only application-level composition.

It does not:
- define CLI syntax;
- define environment-variable name;
- define source precedence;
- define file grammar;
- define request key/value semantics;
- retrieve BOFEK/BRO source profiles;
- perform spatial selection;
- derive or bind ELAS values.

Those remain owned by ELASTIC30, ELASTIC29, ELASTIC28, ELASTIC26/27,
ELASTIC25 and ELASTIC15 respectively.

## Qualification matrix

A1. no explicit path, no CLI option and no environment variable -> INACTIVE and
request false.

A2. explicit path only -> valid request.

A3. CLI path only -> valid request.

A4. environment path only -> valid request.

A5. every pairwise multi-source combination fails closed before file loading.

A6. three-source combination fails closed before file loading.

A7. malformed CLI source fails closed with CLI provenance.

A8. invalid environment source fails closed with environment provenance.

A9. selected-path file/semantic rejection preserves ELASTIC27 provenance.

A10. O0/O2 identity and exact source scope: exactly one new application adapter;
no runtime, solver, kernel or legacy source changes.

## Admission boundary

A green ELASTIC31 admits bounded application-level discovery composition only.

Still outside:
- default config-file discovery;
- any deliberate future precedence policy;
- coordinate/location -> maparea selection;
- automatic soil/profile choice;
- end-to-end source-profile artifact ingestion into typed horizon rows.
