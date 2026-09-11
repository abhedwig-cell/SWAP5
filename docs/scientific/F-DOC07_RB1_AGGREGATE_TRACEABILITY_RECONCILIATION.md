# F-DOC07 - RB1 Aggregate Traceability Coverage and Gap Reconciliation

## Purpose

F-DOC07 reconciles the bounded capability-population work completed in F-DOC03 through F-DOC06 against the immutable `SWAP5-RB1-v1` required denominator. It answers one narrow question: are all 15 required RB1 capabilities now assigned to an explicit bounded traceability population authority exactly once, with their remaining maturity gaps still visible?

The answer is yes for **coverage**, not for complete scientific traceability.

F-DOC07 changes no production source, reference data, physics, solver, numerical policy, scientific tolerance, acceptance threshold or performance policy. It does not reopen F-RB01/F-RB02 or any F-DOC03..06 qualification authority.

## Exact 15-capability partition

The frozen required denominator remains the 15 capabilities in `release/f-rb01/RB1_CAPABILITY_MATRIX.json`.

F-DOC03 owns bounded population traceability for the five core capabilities:

- `RB1-CORE-INTERVAL`;
- `RB1-CORE-DATA`;
- `RB1-CORE-TRANSACTION`;
- `RB1-CORE-MASS`;
- `RB1-CORE-DIAGNOSTICS`.

F-DOC04 owns the two reference/temporal capabilities:

- `RB1-SW-REFERENCE`;
- `RB1-TIME-REFERENCE`.

F-DOC05 owns five execution/restart capabilities:

- `RB1-STANDALONE-N1`;
- `RB1-MULTISWAP-SERIAL`;
- `RB1-MULTISWAP-PARALLEL-V1`;
- `RB1-RESTART-SERIAL`;
- `RB1-RESTART-PARALLEL`.

F-DOC06 owns the remaining three ET/root/surface-process capabilities:

- `RB1-ET-ROOT-SERIAL`;
- `RB1-ROOT-PARALLEL`;
- `RB1-SURFACE-EVAP-RESTRICTED`.

The four sets are disjoint and their union is exactly the frozen 15-capability RB1 denominator. F-DOC07 therefore records `COMPLETE_REQUIRED_CAPABILITY_POPULATION_COVERAGE`.

That statement does **not** mean `FULLY_TRACED`.

## Why coverage is not full traceability

F-DOC02 created the release-bound index and explicitly required missing T0-T12 evidence to remain visible rather than inferred from release PASS. F-DOC03 through F-DOC06 then populated bounded portions of those traces. Their exact maturity differs by capability and workunit, and F-DOC07 does not flatten those distinctions.

The aggregate result still has material open evidence classes:

1. controlled T0-T7 theory/conceptual/formal/numerical bindings are not complete across the denominator;
2. complete T11 equation-to-test graphs are not complete across the denominator;
3. T12 application-class validation remains open;
4. the controlled Revised checklist Status A/AA 2024 copy and exact reconciliation remain pending under F-DOC01;
5. application-specific groundwater-head/error-budget policy remains external to the temporal qualification;
6. surface-evaporation throughput/scaling and call-local copy/allocation performance remain separate work and do not reopen the closed scientific/canonical authority.

Release qualification is evidence for released behaviour inside the frozen RB1 scope. It is not a substitute for missing theory provenance, full equation-to-test traceability, application validation or external quality-system audit.

## Status A/AA boundary

F-DOC01 established a T0-T14 architecture and explicitly blocked Status A readiness/compliance language until the controlled WR-QA-2024 authority is obtained/reconciled and the evidence dossier is completed through the competent WUR process.

The external-authority gate remains exactly `formal_2024_reconciliation = PENDING_CONTROLLED_COPY`.

F-DOC07 does not change that boundary. Even after 15/15 capability population coverage:

- `ready_for_status_a_review = false`;
- `status_a_compliant = false`;
- `status_aa_compliant = false`;
- no external audit is claimed.

The maximum claim from this workunit is therefore:

`COMPLETE_RB1_REQUIRED_CAPABILITY_POPULATION_COVERAGE_WITH_EXPLICIT_MATURITY_GAPS`.

## Preserved scientific boundaries

The aggregation keeps all important downstream nonclaims intact.

No universal `H_budget`, groundwater-head accuracy budget or universal temporal tolerance is created. Application-specific error-budget selection remains external.

For root-active parallel execution, the frozen 2/4-worker and physics-profile limits remain unchanged; no speedup or root-active restart claim is added.

For restricted surface evaporation, `SWINTER=0` and `SWREDU=0` remain the frozen scientific profile. Functional MultiSWAP compatibility does not imply throughput/scaling qualification. The call-local copy/allocation topic stays in its separate performance workunit.

Mass conservation remains hard. Aggregate documentation cannot create a second authoritative water booking, relax a mass gate, or reinterpret attribution as an additional flux.

## Architecture-invariant review

F-DOC07 is an aggregate documentation/governance delta only. It changes no kernel/runtime/process implementation and therefore introduces no adverse delta against the 30 SWAP5 architecture invariants. The explicit F-DOC07 invariant audit records 30/30 PASS for no-adverse-delta and `HARD_UNCHANGED` mass conservation.

## Completion criterion

F-DOC07 is qualified only if its validator mechanically proves all of the following on the exact head:

- F-DOC03, F-DOC04, F-DOC05 and F-DOC06 immutable status authorities are exact and their exact-head workflows were green;
- their capability sets are pairwise disjoint;
- their union equals the 15 required F-RB01 capability IDs exactly;
- all 15 frozen RB1 release gates are PASS;
- the F-DOC01/F-DOC02 Status A boundaries remain fail-closed;
- no `src` or `reference` delta exists relative to F-DOC06;
- no aggregate `FULLY_TRACED`, Status A/AA, universal H-budget or surface-evaporation throughput/scaling claim is made;
- the 30-invariant audit is complete and mass conservation remains hard.

A green exact-head workflow establishes the aggregate coverage authority. Any future work that resolves scientific/documentation gaps must be a new bounded workunit and must not silently rewrite these historical population authorities.
