# F-PE-ELASTIC28 — application request source arbitration preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@12e12538f043c6716086615ea51c8b87610600c4`

Parent authority:
- `F-PE-ELASTIC27_CLOSURE.md`;
- `F-PE-ELASTIC26_CLOSURE.md`;
- `F-PE-ELASTIC25_CLOSURE.md`.

## Purpose

Introduce a typed, I/O-free arbitration seam for application configuration
sources before any CLI/environment discovery is admitted.

The seam is:

`typed candidate config paths from external application ownership`
-> zero / exactly one / conflicting source decision
-> one explicit path or inactive result
-> ELASTIC27 request loader.

This work unit deliberately does not read command-line arguments, environment
variables or default files.

## Candidate-source contract

The caller may supply up to three typed candidate sources:

- explicit application path;
- CLI-derived path;
- environment-derived path.

Each candidate carries:
- `supplied` logical;
- path text.

A supplied candidate must have a non-empty trimmed path.

## Arbitration policy

No silent precedence is admitted.

Rules:
- zero supplied candidates -> INACTIVE, no selected path;
- exactly one valid candidate -> OK, that source/path is selected;
- two or more supplied candidates -> CONFLICT, fail closed;
- supplied empty path -> INVALID_SOURCE, fail closed.

Therefore ELASTIC28 does not decide that CLI, environment or explicit
application configuration is inherently stronger than another source.

## Ownership boundary

ELASTIC28 may:
- validate typed candidate presence/path shape;
- count supplied sources;
- select exactly one unambiguous source;
- report selected source provenance.

ELASTIC28 may not:
- read process environment;
- inspect command-line arguments;
- discover a default file;
- test file existence;
- parse config-file contents;
- retrieve BOFEK/BRO data;
- perform spatial selection;
- derive or activate ELAS.

ELASTIC27 remains the owner of loading an already selected path.

## Qualification matrix

A1. zero candidates returns INACTIVE.

A2. each of explicit, CLI and environment source succeeds independently when
it is the only supplied source.

A3. all pairwise and three-way multiple-source combinations fail closed as
CONFLICT.

A4. a supplied blank path fails closed as INVALID_SOURCE.

A5. selected path is preserved exactly except harmless trailing character
padding; no leading-space normalization is performed.

A6. zero-source arbitration composes through ELASTIC27 as exact inactive/default
OFF.

A7. single-source arbitration composes through ELASTIC27 to a valid generated
prior request.

A8. ambiguous sources never cause file access through ELASTIC27.

A9. O0/O2 identity.

A10. production source scope is exactly one typed arbitration module; no file
adapter, solver, kernel or legacy source changes.

## Admission boundary

A green ELASTIC28 admits only source arbitration semantics.

Still outside scope:
- actual CLI argument reading;
- actual environment-variable reading;
- default config-file discovery;
- any future policy that deliberately assigns precedence;
- location/coordinate -> maparea selection;
- automatic soil/profile choice.
