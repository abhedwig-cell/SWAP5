# F-PE-ELASTIC29 — environment config-path source preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@03ed5e45bdf35a659cc1a69bf5d7ba5ff05edb47`

Parent authority:
- `F-PE-ELASTIC28_CLOSURE.md`;
- `F-PE-ELASTIC27_CLOSURE.md`.

## Purpose

Add one bounded application adapter that reads exactly one named process
environment variable and materializes the ELASTIC28 environment-derived path
candidate.

Environment variable:
`SWAP5_ELASTIC_STORAGE_CONFIG`.

The seam is:

`SWAP5_ELASTIC_STORAGE_CONFIG`
-> typed environment path candidate
-> ELASTIC28 source arbitration
-> ELASTIC27 request loader.

## Environment contract

Rules:
- variable absent -> candidate `supplied=.false.`, status INACTIVE;
- variable present with non-empty value -> exact value materialized as candidate,
  status OK;
- empty value -> INACTIVE;
- value longer than the typed candidate path capacity -> TOO_LONG, fail closed;
- intrinsic environment-read error -> READ_FAILED, fail closed.

No trimming or path normalization is performed beyond the Fortran intrinsic
returning the environment value itself.

## Ownership boundary

ELASTIC29 owns only reading the single fixed environment variable into a typed
candidate.

It does not:
- read CLI arguments;
- discover default files;
- assign precedence;
- inspect file existence or contents;
- retrieve BOFEK/BRO data;
- perform spatial selection;
- derive or activate ELAS.

ELASTIC28 remains the source-arbitration authority. Therefore any simultaneous
explicit/CLI/environment candidates still fail closed as a conflict.

## Qualification matrix

A1. absent environment variable returns INACTIVE and an unsupplied candidate.

A2. present exact path returns OK, supplied environment candidate, exact path
identity.

A3. present environment path composes through ELASTIC28 as the sole environment
source.

A4. present environment path plus an explicit candidate is rejected by
ELASTIC28 as CONFLICT; ELASTIC29 does not override it.

A5. empty variable is inactive.

A6. overlength environment value fails closed as TOO_LONG.

A7. valid environment path composes through ELASTIC28 + ELASTIC27 to the typed
generated-prior request.

A8. no environment source composes as default OFF.

A9. O0/O2 identity.

A10. production source scope is exactly one new adapter module; no runtime,
solver, kernel or legacy changes.

## Admission boundary

A green ELASTIC29 admits only environment-variable candidate materialization.

Still outside:
- CLI candidate materialization;
- default-file discovery;
- any explicit precedence policy;
- location/coordinate -> maparea selection;
- automatic soil/profile choice.
