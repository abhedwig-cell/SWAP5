# F-DOC10 — RB1 post-T11 aggregate traceability reconciliation

## Purpose

F-DOC10 updates the central documentary view of RB1 traceability after the qualified F-DOC08 and F-DOC09 remediations. It does not reopen the frozen RB1 science, release denominator or production source.

F-DOC07 remains the immutable authority for assignment of all 15 required RB1 capabilities. F-DOC10 changes no assignment. It only reconciles what F-DOC08 and F-DOC09 improved and which maturity gaps still remain.

The machine-readable authority is `docs/scientific/registries/rb1-post-t11-aggregate-traceability-reconciliation.json`.

## What changed after F-DOC07

### RB1-TIME-REFERENCE

F-DOC08 qualified a bounded temporal-acceptance relation-to-test graph. Its eight bounded relations are mapped to verification evidence and the bounded acceptance semantics are therefore substantially better traced than in F-DOC07.

This does **not** mean that temporal accuracy is universally solved. F-DOC08 deliberately leaves application-specific `H_budget` selection and total temporal/groundwater accuracy budgeting external. T12 application validation also remains open.

### RB1-SW-REFERENCE

F-DOC09 qualified a bounded Full Richards REFERENCE verification-evidence inventory. It binds source-qualified evidence for bottom-boundary behavior, request-owned geometry, inactive-macropore scoping, prescribed-head/`qbot`, linear-solver fidelity, determinism/isolation, transaction/mass regressions and release preservation.

F-DOC09 also makes the remaining Full Richards gaps more precise. A controlled complete T1 theory authority is still missing, T3-T8 formulation/discretisation/numerical traceability is not complete, and the whole-route T11 equation-to-test graph is still open.

## Aggregate result

The F-DOC07 denominator remains exactly:

- 15 required RB1 capabilities;
- 15 assigned exactly once;
- zero duplicate assignments;
- zero unassigned required capabilities.

F-DOC08 and F-DOC09 therefore change **maturity**, not **population coverage**.

The correct current aggregate claim is:

`COMPLETE_RB1_REQUIRED_CAPABILITY_POPULATION_COVERAGE_WITH_IMPROVED_BOUNDED_T11_TRACEABILITY_AND_EXPLICIT_RESIDUAL_MATURITY_GAPS`

This is intentionally weaker than `FULLY_TRACED`, `READY_FOR_STATUS_A_REVIEW`, `STATUS_A_COMPLIANT` or `STATUS_AA_COMPLIANT`.

## Gap state after F-DOC08/F-DOC09

The program-level gap state is now:

| Gap | State after F-DOC10 | Change |
|---|---|---|
| Controlled T0-T7 theory/formal/numerical traceability | OPEN | unchanged program gap; Full Richards subset is now more explicit |
| Complete T11 graphs | OPEN_NARROWED | partially remediated by F-DOC08/F-DOC09 |
| T12 application validation | OPEN | unchanged |
| Controlled WR-QA-2024 reconciliation | OPEN_EXTERNAL_AUTHORITY_DEPENDENCY | unchanged |
| Application-specific temporal/groundwater `H_budget` | OPEN_EXTERNAL_POLICY_DEPENDENCY | unchanged |
| Surface-evaporation throughput/scaling | OPEN_SEPARATE_PERFORMANCE_WORK | unchanged |

`OPEN_NARROWED` is important. It means the T11 gap has genuinely become smaller and better specified, not that the entire denominator now has complete equation-to-test traceability.

## Status A / AA boundary

No Status A readiness or compliance claim follows from this reconciliation. The remaining controlled-theory/formal gaps, incomplete whole-denominator T11 traceability, T12 validation gap, missing controlled WR-QA-2024 reconciliation and absence of a competent external audit remain blockers under the existing F-DOC01 governance.

Release PASS remains release evidence. It is never used as a replacement for missing T0-T12 evidence.

## Architecture and scientific scope

F-DOC10 is documentation/governance only:

- no production source delta;
- no reference-data delta;
- no physics or solver change;
- no tolerance or mass-criterion change;
- no temporal-acceptance change;
- no performance-policy change;
- no RB1 denominator or capability-assignment change.

Mass conservation remains hard and unchanged.

The separate surface-evaporation call-local copies/allocations and throughput/scaling work remains outside this workunit and does not reopen the already closed scientific/canonical admission.

## Qualification meaning

A successful F-DOC10 qualification means only:

`QUALIFIED_RB1_POST_T11_AGGREGATE_TRACEABILITY_RECONCILIATION_WITH_RESIDUAL_GAPS`

It establishes a current central documentary maturity view after F-DOC08/F-DOC09 while preserving all unresolved program dependencies.
