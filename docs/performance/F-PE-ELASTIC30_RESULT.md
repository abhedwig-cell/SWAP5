# F-PE-ELASTIC30 — CLI config-path source result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Baseline:
`integration/f-ci-canonical@15d7bc8e01ef47354083826b8aa656786c419bb8`

Qualified postimage:
`5447e96a768d92eada1a975de1662273d81025dd`

Workflow run:
`36585267891`

Job:
`109463769152`

Conclusion:
SUCCESS.

## Qualified seam

`--elastic-storage-config=<path>`
-> typed CLI-derived path candidate
-> ELASTIC28 source arbitration
-> ELASTIC27 request loading.

No matching option remains inactive.

## Qualification

- A1 no matching CLI option inactive: PASS;
- A2 exact option/path identity: PASS;
- A3 unrelated CLI arguments ignored: PASS;
- A4 duplicate ELAS options fail closed: PASS;
- A5 empty option value fail closed: PASS;
- A6 overlength path fail closed: PASS;
- A7 valid CLI candidate composes to generated-prior request: PASS;
- A8 simultaneous CLI+environment source remains conflict: PASS;
- A9 O0/O2 identity: PASS;
- A10 exact production source scope: PASS.

## Ownership boundary

ELASTIC30 owns only the fixed CLI option syntax and materialization into a typed
candidate.

It does not read environment variables, discover defaults, assign precedence,
parse the selected file, retrieve soil/profile data, perform spatial selection,
derive ELAS or activate runtime parameters.

## Decision

Classification:
`QUALIFIED_ADMISSION_CANDIDATE`.
