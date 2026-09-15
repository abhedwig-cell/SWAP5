# F-VQ01 - F-CI11 verification admission

## Scope

F-VQ01 starts the SWAP5 Verification & Qualification workstream as a qualification-only line. It changes verification assets, qualification metadata and CI only. Production source is not modified.

Exact qualification basis:

```text
repository                  abhedwig-cell/SWAP5
canonical production line   integration/f-ci-canonical
qualified source head       4e8894fc741d7abd711367f712e7aad29d1361eb
qualification evidence      b18150cb4f5313f01fc1c775917c617b421c9ba0
canonical workflow run      34100440481
corrected legacy oracle      B1.10
B1.10 source manifest       2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1
```

F-VQ01 does not reinterpret older branch PASS results as current qualification. Every reusable asset is classified in `integration/f-vq/F-VQ01_ASSET_INVENTORY.json`; every qualification claim is controlled by `integration/f-vq/F-VQ01_ADMISSION_MATRIX.json`.

## Qualification semantics

The matrix keeps five states independent:

```text
contract exists
implementation exists
test can execute
test is PASS
claim is QUALIFIED
```

A PASS is therefore insufficient by itself. In particular:

- a synthetic adapter or testdouble may qualify verifier logic, never real SWAP5 physics;
- a focused Hupsel physical test qualifies only the exercised physical profile;
- a hard mass PASS for a profile without snow or macropores does not qualify missing optional storage accounting;
- a successful full-versus-split run does not establish an acceptable physical temporal error without a qualified metric and tolerance;
- the B2/canonical-reference gate remains blocked until the real canonical physical entrypoint and result contract are executable.

## B1.10 admission

The B1.10 snapshot and admission tools are directly reusable against the F-CI11 qualification tree. The exact reference identity is:

```text
snapshot       B1.10
family         SWAP-4.3.1-corrected
members        63
source bytes   1,863,575
manifest       2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1
```

`tools/vq/b1_10_admission_gate.py` is the executable static admission check. `tools/vq/b1_10_reconstruct.py` remains the deterministic reconstructor, but a fresh reconstruction requires the exact externally supplied canonical B0 archive. F-VQ does not substitute another archive or fabricate the required source identity.

## Directly reusable F-CI11 qualification

The F-CI03 through F-CI11 canonical dependency chain is green on the exact source head. F-VQ01 admits existing source-bound evidence only within its stated scope.

The directly reusable physical claims include:

- focused whole-day checkpoint, restore and same-committed-state rerun for the qualified F-CI07 Hupsel cases;
- process continuation capture/restore for the F-CI08 admitted process set;
- non-midnight generic physical intervals for the F-CI11 admitted profiles;
- physical intervals crossing a calendar-day boundary for the same profiles;
- unrounded trial-mass wiring and hard mass accounting for the admitted non-snow/non-macropore profile;
- O0/O2 identity for the recorded qualification cases.

F-CI11 records a hard mass limit of `1e-6 cm` and a maximum observed absolute residual of `1.8590012175467852e-07 cm` for the source-bound local qualification matrix.

## Fail-closed blockers

The following claims remain blocked and must not be promoted by F-VQ01:

1. Binding the qualified generic advance and mass seam in `b1_10_transaction_model_t`. F-CI12 owns this production change.
2. A qualified physical temporal-error metric and tolerances for full-versus-split comparisons.
3. Real B1.10 physical execution through `execute_reference_interval`.
4. Complete snow storage accounting.
5. Complete macropore storage accounting.
6. A canonical result and transaction-diagnostic contract bound to the real physical entrypoint.
7. Full reentrant and parallel qualification of the serialized legacy backend.
8. Production warm-start independence through the canonical transaction route.

The existing B2 candidate file is not current F-CI11 evidence because its production observation baseline predates F-CI11. The B2 gate remains useful only as a fail-closed negative admission gate until that candidate is exactly rebased and a real production target exists.

## Historical VQ assets

The older VQ-1e1 transaction/time harness contains useful verifier cases for rollback, commit, accounting, rerun, forcing replay, warm start and generic time. Its own evidence explicitly states that production physics was not executed. It is therefore not current production qualification.

The historical VQ-1d2 and VQ-1d3 seam/result contracts also predate B1.10. Their semantics may be rebased in later F-VQ work, but their old oracle binding cannot be carried forward as qualification evidence.

## Executable F-VQ01 gate

`tools/vq/fvq01_admission.py` verifies, fail closed:

- the exact source/evidence/workflow provenance chain;
- absence of F-VQ production-source changes under `src/`;
- exact B1.10 identity and static admission;
- completeness and semantics of the current admission matrix;
- completeness and classification semantics of the asset inventory;
- expected failure of the unavailable B2/canonical-reference admission;
- F-CI11 non-midnight, cross-day, unrounded-mass and hard-mass evidence;
- explicit non-admission of physical temporal-error qualification.

A blocked B2/reference gate is a PASS for F-VQ01 fail-closed behavior. It is not a B2 physics PASS.

## Planned next work units

`F-VQ02` rebases the reusable VQ seam/result and transaction-time verifier contracts onto the exact B1.10/F-CI baseline, still without claiming production physics.

`F-VQ03` is conditional on F-CI12 and admits the real canonical production adapter. It then runs rollback/retry, same-state rerun, forcing replay, warm-start and generic-time cases against real physics.

`F-VQ04` defines and qualifies the physical temporal-error metric and tolerance policy before any full-versus-split physical-equivalence claim is admitted.

`F-VQ05` qualifies complete optional water storage accounting, beginning with snow and macropores, using real unrounded storage and boundary terms.

`F-VQ06` performs B1.10 versus canonical-reference result/diagnostic admission once the real `execute_reference_interval` route and result contract are available.

`F-VQ07` qualifies legacy-backend reentrancy, isolation and parallel execution separately from worker-local state ownership.

## Exit decision

F-VQ01 may be marked QUALIFIED only after its persisted qualification postimage has passed the F-VQ01 admission gate, its unit tests, the B1.10 admission gate, the expected fail-closed B2 gate and the selected reusable F-CI gates in CI. Until then the persisted matrix is the recovery point, not final qualification evidence.
