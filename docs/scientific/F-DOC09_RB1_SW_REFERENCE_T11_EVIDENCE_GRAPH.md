# F-DOC09 — RB1 Full Richards REFERENCE route bounded T11 verification evidence graph

## Purpose

F-DOC09 consolidates the verification evidence that already exists for the frozen RB1 Full Richards REFERENCE route. It answers a narrower question than a complete theory-to-code trace:

> Which parts of the restricted REFERENCE route are already verified by exact, source-bound qualification evidence, and which material T11 links remain missing?

It does **not** reconstruct missing scientific theory or numerical formulation from the implementation. A passing release suite is not treated as a substitute for a missing equation-to-test edge.

The machine-readable source of truth is `docs/scientific/registries/rb1-sw-reference-t11-evidence-graph.json`.

## Frozen scope

The graph is restricted to the RB1 Full Richards REFERENCE route:

- `SWKIMPL=0`;
- `SWSOPHY=0`;
- inactive macropores in the admitted profile;
- the frozen RB1 reference boundary/profile scope;
- RossFast excluded;
- scientific source authority `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`;
- F-RB01 qualification authority `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`;
- F-RB02 release authority `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`.

No production source or reference data are changed by this workunit.

## Verified subrelations

The existing evidence supports a meaningful but incomplete T11 graph.

| ID | Verified subject | Main authority | What is actually established |
|---|---|---|---|
| R01 | Explicit free-drainage bottom route | F-SI13 | request authority for modes 7/-2, focused unrounded residual, fail-closed unsupported modes, legacy-direct identity |
| R02 | Request-owned grid geometry | F-SI14 | geometry authority, legacy-grid isolation, same-geometry identity, focused residual, worker-owned provider scratch |
| R03 | Inactive-macropore option branch | F-SI15 | explicit physical-option authority, poison isolation, active option fail-closed, focused residual, route identity |
| R04 | Prescribed bottom head and `qbot` | F-SI16 | lower-face Darcy-gradient semantics, positive/negative flux, unrounded residual, `qbot` continuity identity, direct B1.10 identity |
| R05 | Reference linear-solver seam | F-SI19 | direct legacy oracle, TRIDAG and band-solver cases, O0/O2 identity, HeadCalc reference-control identity |
| R06 | Determinism and isolation | F-SI13/14/15/16/19 | O0/O2 identity, ABA where exercised, scratch poisoning, request immutability, serialized worker isolation where exercised |
| R07 | Transaction and mass boundary regression | F-SI13/14/15/16/19 | F-KT boundary regressions, hard mass retained, `qbot` exact-once accounting preserved |
| R08 | Frozen release preservation | F-RB01 | frozen source/reference identity and release replay; this is release preservation, not an equation authority |

F-SI18 is retained separately as diagnostic support. It established that an earlier apparent convergence cliff came from a zero-correction TRIDAG test double. Its production-like TRIDAG control is useful for harness-fidelity interpretation, but F-DOC09 does **not** promote that diagnostic workload into positive scientific admission.

## Why this is not a complete Full Richards equation-to-test graph

F-DOC01 requires a real bidirectional chain. T11 cannot be called complete merely because several strong solver and boundary tests exist.

The following material gaps remain explicit:

1. **T1 scientific theory**: no single controlled complete Full Richards theory authority has been identified for the frozen RB1 route.
2. **T3-T5 formulation**: there is no controlled complete inventory linking every formal Richards equation, closure, source/sink and boundary term to the exact SWAP-specific and computational formulation.
3. **T6-T8 numerical chain**: there is no single controlled graph for the entire discretisation, nonlinear residual/Jacobian, damping/convergence/retry method and ordered algorithmic state transitions.
4. **T11 equation coverage**: this workunit does not claim exhaustive equation-level verification of every interior residual/Jacobian term, constitutive closure, top boundary, drainage/irrigation term or root-sink contribution.
5. **T12 validation**: application validation remains outside this bounded verification graph.

Therefore:

- the bounded evidence **inventory** can be complete;
- the complete Full Richards **equation-to-test graph is not complete**;
- `RB1-SW-REFERENCE` remains **not fully traced**;
- F-DOC09 does **not** make it `READY_FOR_STATUS_A_REVIEW`.

## Important equation-level evidence that is already source-bound

F-SI16 is a useful example of what an actual equation-to-test link looks like. It records the lower-face prescribed-head gradient

`head_gradient(NN+1) = (h(NN) - hbot) / disnod(NN+1) + 1`

and the corresponding mode-5 Darcy term

`kmean(NN+1) * head_gradient(NN+1)`.

Its qualified matrix includes an unrounded equation residual, multiple prescribed heads, positive and negative bottom flux, authoritative `qbot` continuity identity, and direct B1.10 numeric identity. That is strong scoped T11 evidence. It does not by itself document or verify every equation of the Full Richards route.

F-SI13, F-SI14 and F-SI15 likewise contain focused unrounded residual checks for their admitted seams. F-SI19 qualifies numerical fidelity of the reference linear-solver seam. Those records are preserved as independent scoped evidence nodes rather than inflated into a whole-route claim.

## Mass, transaction and determinism

Mass conservation remains hard and unchanged. F-DOC09 introduces no tolerance, no relaxed balance criterion and no fallback exception.

Transaction ownership remains in the already qualified kernel/runtime chain. F-DOC09 only records existing regression evidence. A failed or rejected trial is not reinterpreted as committed state.

Determinism claims are limited to the exact qualified subroutes and worker-count/case matrices that their owning evidence actually exercised. No wider bitwise-determinism promise is inferred.

## Hard nonclaims

F-DOC09 does not:

- create or infer a missing Full Richards T1 theory authority from code, legacy behavior or release PASS;
- claim a complete equation-to-test graph for the entire Full Richards REFERENCE route;
- promote F-SI18 diagnostic fixture evidence into positive scientific admission;
- establish Status A readiness, Status A compliance or Status AA compliance;
- close T12 application validation or controlled-source reconciliation;
- alter production source, reference data, physics, solver behavior, scientific tolerances, mass criteria, temporal acceptance or RB1 scope;
- reopen the separate surface-evaporation throughput/scaling and call-local allocation performance work.

## Qualification meaning

A successful F-DOC09 qualification means only:

`QUALIFIED_BOUNDED_RB1_SW_REFERENCE_T11_EVIDENCE_GRAPH_WITH_EXPLICIT_RESIDUAL_GAPS`

That decision is intentionally weaker than `COMPLETE_FULL_RICHARDS_EQUATION_TO_TEST_GRAPH` and weaker than `FULLY_TRACED`.
