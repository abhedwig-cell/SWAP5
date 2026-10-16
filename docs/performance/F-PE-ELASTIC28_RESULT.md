# F-PE-ELASTIC28 — request source arbitration result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Baseline:
`integration/f-ci-canonical@12e12538f043c6716086615ea51c8b87610600c4`

Qualified postimage:
`8a791816b9f3393a8db46a7600532f929b4e7e61`

Workflow run:
`36583470077`

Job:
`109457454727`

Conclusion:
SUCCESS.

## Qualified policy

ELASTIC28 admits typed source arbitration without silent precedence:

- zero supplied sources -> INACTIVE;
- exactly one valid supplied source -> selected;
- multiple supplied sources -> CONFLICT, fail closed;
- supplied blank path -> INVALID_SOURCE, fail closed.

The three typed candidate classes are:
- explicit application path;
- CLI-derived path;
- environment-derived path.

ELASTIC28 itself reads none of those external sources.

## Qualification

- A1 zero sources inactive: PASS;
- A2 each candidate class succeeds independently: PASS;
- A3 all multi-source combinations fail closed: PASS;
- A4 blank supplied source fails closed: PASS;
- A5 path identity/no leading-space normalization: PASS;
- A6 inactive selection composes through ELASTIC27 as default OFF: PASS;
- A7 single source composes through ELASTIC27 to valid request: PASS;
- A8 ambiguous sources do not proceed to file access: PASS;
- A9 O0/O2 identity: PASS;
- A10 exact production source scope: PASS.

## Ownership boundary

ELASTIC28 is I/O-free. It does not:
- read CLI arguments;
- read environment variables;
- discover a default file;
- inspect file existence or contents;
- retrieve soil/profile data;
- perform spatial selection;
- derive or activate ELAS.

## Decision

Classification:
`QUALIFIED_ADMISSION_CANDIDATE`.
