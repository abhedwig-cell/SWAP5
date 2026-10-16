# F-PE-ELASTIC30 — CLI config-path source preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@15d7bc8e01ef47354083826b8aa656786c419bb8`

Parent authority:
- `F-PE-ELASTIC29_CLOSURE.md`;
- `F-PE-ELASTIC28_CLOSURE.md`;
- `F-PE-ELASTIC27_CLOSURE.md`.

## Purpose

Add one bounded application adapter that reads the command-line arguments and
materializes the ELASTIC28 CLI-derived path candidate.

Admitted CLI syntax:

`--elastic-storage-config=<path>`

The seam is:

`command-line option`
-> typed CLI path candidate
-> ELASTIC28 source arbitration
-> ELASTIC27 request loader.

## CLI contract

Rules:
- no matching option -> candidate `supplied=.false.`, status INACTIVE;
- exactly one matching option with non-empty path -> exact path candidate,
  status OK;
- duplicate matching options -> MULTIPLE, fail closed;
- empty path after `=` -> INVALID_SYNTAX, fail closed;
- path longer than candidate capacity -> TOO_LONG, fail closed;
- command-argument intrinsic read failure -> READ_FAILED, fail closed.

Unknown/unrelated command-line arguments are ignored by ELASTIC30.

No alternate spellings, space-separated value form, case normalization or
aliases are admitted.

## Ownership boundary

ELASTIC30 owns only reading this single fixed CLI option into a typed candidate.

It does not:
- read the environment;
- discover default files;
- assign precedence;
- inspect file existence or contents;
- retrieve BOFEK/BRO data;
- perform spatial selection;
- derive or activate ELAS.

ELASTIC28 remains source-arbitration authority. A simultaneous CLI candidate
and environment or explicit candidate remains a conflict.

## Qualification matrix

A1. no matching option returns INACTIVE.

A2. exact option returns OK and preserves the path.

A3. unrelated CLI arguments do not affect the result.

A4. duplicate ELAS CLI options fail closed as MULTIPLE.

A5. empty value fails closed as INVALID_SYNTAX.

A6. overlength path fails closed as TOO_LONG.

A7. valid CLI candidate composes through ELASTIC28 + ELASTIC27 to the typed
generated-prior request.

A8. valid CLI candidate plus environment candidate is rejected by ELASTIC28 as
CONFLICT.

A9. O0/O2 identity.

A10. production source scope is exactly one new adapter module; no runtime,
solver, kernel or legacy changes.

## Admission boundary

A green ELASTIC30 admits only CLI candidate materialization.

Still outside:
- default-file discovery;
- any deliberate precedence policy;
- location/coordinate -> maparea selection;
- automatic soil/profile choice.
