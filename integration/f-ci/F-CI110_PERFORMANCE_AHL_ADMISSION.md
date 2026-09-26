# F-CI110 — reconstructed performance + F-AHL50 canonical admission

Date: 2026-09-25

Status: `CANONICAL_ADMISSION_CANDIDATE`

Canonical parent:
`integration/f-ci-canonical@506c36aab6f84b74dffdf5c37fe572c1e0b46610`

Candidate source postimage:
`dc08b4ca5f45ac0703a3bacefbdf05a0b8058c6b`

Governance reconstruction:
F-PERF-CANON01 PR #621.

## Purpose

Admit the independently reconstructed and requalified post-canonical performance lineage, ending in the bounded default-OFF F-AHL50 direct-retention capability.

This candidate is not a merge of the historical research branches. It is the explicitly recomposed postimage produced by Tranches A-D.

## Reconstructed capability chain

- A0: no-op by source equivalence to independently qualified F-CI81 authority;
- A1 PROFILE01: observation only;
- A2 PROFILE02-H03: bounded HeadCalc constitutive-tuple reuse repair;
- A3 PROFILE03: measurement only;
- B1 ZERO-WASTE core exact-P0 postimage: qualified;
- B2 five admitted large-N groundwater fast paths: qualified;
- C PLANVALID01 exact-P0 canonical execution-plan fast path: qualified;
- D F-AHL50 bounded direct-retention opt-in: qualified.

## Final production surface

Relative to current canonical the candidate changes 29 `src/**` files. This is the explicit reconstructed production surface, not 425 commits of historical branch ambiguity.

The candidate remains a descendant of current canonical and is 85 commits ahead because the recomposition itself was persisted as bounded commits and qualification harness work.

## Required final preservation

Before canonical ref mutation:
- generic current-canonical preservation;
- FKT22 physical/runtime preservation;
- PPA-WU01;
- B1 poison and paired runtime;
- B2 large-N focused gates;
- PLANVALID01 semantic/application gates;
- F-AHL50 provider/matrix/default-off/fail-closed/ownership/scale/application;
- verify F-AHL50 remains default OFF and envelope-bounded.

No new optimization or physics work belongs in F-CI110.


## Final preservation result

Final candidate head:
`5000086bf3ba6f1cd5f620f6be02880390380692`

The F-CI110 preservation suite is fully green:
- FKT22: PASS;
- PPA-WU01: PASS;
- B1 poison workspace: PASS;
- PLANVALID01: PASS;
- F-AHL50 provider: PASS;
- F-AHL50 12-case matrix: PASS;
- default-off: PASS;
- fail-closed: PASS;
- ownership: PASS;
- scale: PASS;
- F-GC49D application opt-in: PASS.

No production change was required during final preservation. The only final repair was inherited poison-runner compile ordering for the admitted direct-retention modules.

Status:
`F-CI110 = READY_CANONICAL_MERGE`
