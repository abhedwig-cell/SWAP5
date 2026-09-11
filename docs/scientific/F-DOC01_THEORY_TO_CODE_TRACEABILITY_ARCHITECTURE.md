# F-DOC01 theory-to-code traceability architecture

## Purpose

SWAP5 scientific documentation is a graph, not a stack of unrelated manuals. A capability is described by one version-controlled vertical chain and publication products are views over that chain.

## Mandatory T0-T14 spine

| Tier | Object | Required content |
|---|---|---|
| T0 | Physical system / phenomenon | real-world process, reservoirs, fluxes, interfaces and observables |
| T1 | Scientific theory | physical principles, empirical theory, primary literature, scope assumptions |
| T2 | Conceptual model | included/excluded processes, conceptual stores, fluxes and dependencies |
| T3 | Formal mathematical model | equations, variables, dimensions, units, sign/coordinate conventions, conservation laws, closures, sources/sinks, BCs and ICs |
| T4 | SWAP-specific formulation | selected parameterisations, approximations, option branches and justified deviations from general theory |
| T5 | Computational continuous formulation | exact continuous form presented for numerical treatment before discretisation |
| T6 | Discretisation | nodes/control volumes/faces, spatial operators, time integration, averaging, source/boundary placement and event treatment |
| T7 | Numerical method | nonlinear residual/Jacobian, nonlinear/linear solver, damping, convergence, acceptance, retry, tolerances and fallback |
| T8 | Algorithm | language-independent ordered procedure and state transitions |
| T9 | Software contract | parameter, forcing, numerical config, committed/candidate state, result, diagnostics, scratch and transaction ownership |
| T10 | Implementation mapping | exact production module/type/routine/interface/code region and source authority |
| T11 | Verification | equation/derivative/conservation/algorithm/transaction tests and evidence locators |
| T12 | Validation | independent observations, experiments or application benchmarks; explicitly unvalidated scope |
| T13 | Qualification and applicability | qualified scope, nonclaims, limits, application envelope, policy/evidence authority |
| T14 | Release authority | exact source commit/tree/release that contains the mapped implementation |

## Completeness rules

A scientific capability is `FULLY_TRACED` only if all applicable tiers have resolved nodes and all mandatory edges are justified. `NOT_APPLICABLE` requires a rationale. A missing tier is a gap, never an implicit edge.

Important scientific production code cannot become internally `READY_FOR_STATUS_A_REVIEW` while a material T1-T11 link is an unexplained black box. T12 may legitimately be incomplete, but the unvalidated scope and consequence for intended use must be explicit.

## Bidirectional queries

### Theory to code

`T1 theory → T3 equation → T4/T5 formulation → T6 discretisation → T7 numerical method → T8 algorithm → T9 contract → T10 implementation → T11 verification → T13 qualification → T14 release`.

A query must expose option-dependent forks and any missing links.

### Code to theory

For each scientific production implementation node:

`T10 code → T9 contract → T8 algorithm → T7/T6 computational formulation → T3 formal model → T2 concept → T1 theory/source → T11 verification → T13 qualification → T14 release`.

Code without a reverse scientific path is an orphan implementation node and blocks readiness unless explicitly classified as non-scientific infrastructure.

## Relationship types

Minimum edge vocabulary:

- `DESCRIBES_PHENOMENON`
- `FORMALISES`
- `SPECIALISES`
- `APPROXIMATES`
- `USES_CLOSURE`
- `USES_BOUNDARY_CONDITION`
- `DISCRETISES`
- `SOLVES`
- `REALISES_ALGORITHM`
- `IMPLEMENTS_CONTRACT`
- `IMPLEMENTED_BY`
- `VERIFIED_BY`
- `VALIDATED_BY`
- `QUALIFIED_BY`
- `APPLICABLE_TO`
- `RELEASED_IN`
- `SUPERSEDES`
- `DERIVED_FROM_LEGACY`
- `DISCREPANCY_WITH`.

Edges carry authority, version/source commit where applicable, status and rationale.

## Option and policy branching

Physical options and numerical policy are separate graph dimensions. Macropores, drainage and crop choices are physical configuration. Reference/balanced/throughput, tolerances and fallback are numerical policy. A numerical policy node may reference a physical equation but cannot silently substitute different physics.

## Time, coupling and transaction semantics

T6-T9 records must not assume a day boundary. Time is `[t0,t1]`; solver steps, forcing intervals, events, reporting and coupling windows are separate concepts. Coupled capability chains include checkpoint/trial/retry/commit/rollback, interface residuals and mass accounting.

## Source-of-truth rule

Repository Markdown explains records; machine-readable registries define IDs and edges; F-VQ/F-MQ/F-CI/F-TB evidence remains authoritative in its owning artifact. PDF/Word/manual outputs are generated publication views and must identify the registry/source commit from which they were built.
