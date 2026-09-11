# F-DOC02 RB1 release-bound traceability gap matrix

## Scope

This matrix is a documentation view over the machine-readable `rb1-release-traceability-index.json` registry. It is bound to the immutable `SWAP5-RB1-v1` release authorities and does not change or reopen RB1 science, physics, solver behaviour, acceptance thresholds, performance claims or release scope.

F-DOC02 does **not** claim that RB1 is a complete Status A dossier, is ready for Status A review, is Status A compliant, or is Status AA compliant. The controlled `Revised checklist Status A/AA, 2024` reconciliation remains open under F-DOC01 governance.

## Population rule

For every required RB1 capability:

- T11 is `SCOPED_EVIDENCE_LINKED_NOT_FULLY_TRACED` because F-RB01 provides qualification/verification evidence locators, but F-DOC02 does not pretend those release gates are a complete equation-to-test verification graph;
- T13 is `RESOLVED_RB1_RELEASE_SCOPE` because the frozen F-RB01 capability matrix qualifies all 15 required capabilities;
- T14 is `RESOLVED_RB1_RELEASE_AUTHORITY` and points to the definitive F-RB02 closeout;
- T0-T10 and T12 remain explicit `GAP_NOT_POPULATED` until capability-specific scientific records and exact implementation/validation links are populated under the F-DOC01 architecture.

A release PASS never fills a missing theory, formulation, code-mapping or validation tier by inference.

## Fixed denominator

| Capability | T11 | T13 | T14 | Explicit open tiers |
|---|---|---|---|---|
| RB1-CORE-INTERVAL | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-CORE-DATA | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-CORE-TRANSACTION | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-CORE-MASS | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-CORE-DIAGNOSTICS | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-SW-REFERENCE | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-TIME-REFERENCE | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-STANDALONE-N1 | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-MULTISWAP-SERIAL | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-MULTISWAP-PARALLEL-V1 | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-ET-ROOT-SERIAL | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-ROOT-PARALLEL | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-SURFACE-EVAP-RESTRICTED | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-RESTART-SERIAL | evidence linked | resolved | resolved | T0-T10, T12 |
| RB1-RESTART-PARALLEL | evidence linked | resolved | resolved | T0-T10, T12 |

The denominator is exactly 15 and may not move inside F-DOC02. The two F-RB01 admitted optional capabilities remain outside this required denominator.

## Authority pins

- F-DOC01 architecture: `999d4fa3da6fa08c5d57e23b9949f3920de37fbe`.
- RB1 scientific source authority: `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`.
- F-RB01 qualification authority: `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`.
- F-RB02 definitive release-metadata authority: `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`.
- F-RB02 exact-head workflow: run `34586202805`, `success`.

## High-priority follow-on gaps

The matrix exposes where real documentation population must continue. Highest-value next targets are the physical Full Richards chain, temporal acceptance, root uptake/ET chain, restricted surface evaporation, transactional/restart semantics and MultiSWAP execution contracts. For each target the next work should create stable F-DOC01 scientific IDs and exact edges rather than broad prose-only summaries.

T12 must remain application-class specific. Numerical equivalence, hard mass conservation, restart identity and release qualification are not substitutes for validation against independent observations or application benchmarks.

## Surface-evaporation scope hold

For `RB1-SURFACE-EVAP-RESTRICTED`, functional MultiSWAP compatibility is qualified. Throughput/scaling of the call-local copy/allocation path remains a separate performance subject and must not reopen the closed scientific/canonical authority.
