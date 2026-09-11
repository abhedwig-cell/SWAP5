# F-DOC11 — RB1 Controlled Theory/Formal Gap Decomposition

## Decision scope

F-DOC10 closed the post-T11 aggregate reconciliation with the fixed 15-capability RB1 denominator intact and with `GAP-CONTROLLED-THEORY-FORMAL` still open. F-DOC11 does not attempt to close that scientific/documentation gap by inference. It decomposes the gap into bounded authority classes so later remediation can be performed without mixing physical science, numerical method, runtime architecture and application policy.

Base authority: `F-DOC10@ef34a9f5a01d78ff9c2628315b484c5a8ff4f717`.

RB1 science and release authority remain immutable:

- canonical scientific source: `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`;
- RB1 qualification: `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`;
- RB1 final metadata authority: `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`.

## Why decomposition is required

The F-DOC01 T0–T14 architecture intentionally distinguishes physical theory, formal equations, numerical formulation, software contracts, implementation, verification, validation, qualification and release. A release PASS therefore cannot manufacture a missing T1 theory source, T3 mathematical specification, T6 discretisation or T7 numerical-method authority.

The remaining T0–T7 gap is not homogeneous. Treating all 15 RB1 capabilities as if they require the same kind of scientific document would itself be a traceability error. F-DOC11 therefore classifies each capability by the authority type that must be reviewed or created later.

## Four authority classes

### Physical science

`RB1-SW-REFERENCE`, `RB1-ET-ROOT-SERIAL` and `RB1-SURFACE-EVAP-RESTRICTED` require a controlled physical-science chain. That chain can include literature, legacy SWAP theory, SWAP-specific formulation and the numerical route, but every claimed link must be controlled and source-bound. Existing verification or release evidence does not substitute for the theory chain.

### Numerical method

`RB1-TIME-REFERENCE` is primarily a numerical-method/acceptance capability. F-VQ34 and F-DOC08 provide bounded scientific and verification authority for the admitted temporal-acceptance behaviour, but they do not select a universal application `H_budget` and do not establish universal groundwater-head accuracy. Application-specific error policy stays external.

### Runtime architecture

The core interval/data/transaction/diagnostic capabilities, execution topologies and restart capabilities need controlled architecture and formal state-transition semantics. Some T0–T1 tiers may ultimately be `NOT_APPLICABLE`, but that is only legitimate after an explicit applicability review with rationale. F-DOC11 does not mark those tiers N/A itself.

### Hybrid

`RB1-CORE-MASS` and `RB1-ROOT-PARALLEL` combine science/numerics with runtime semantics. Mass conservation requires both physical conservation meaning and discrete accepted-only accounting. Root-parallel execution inherits root science from the physical-process authority and must separately document isolation, parallel execution and deterministic publication semantics.

## Fixed denominator and decomposition result

All 15 required RB1 capabilities are assigned exactly once:

- 3 physical-science capabilities;
- 1 numerical-method capability;
- 9 runtime-architecture capabilities;
- 2 hybrid capabilities.

This is a gap decomposition only. F-DOC11 resolves **zero** T0–T7 tiers, makes **zero** `FULLY_TRACED` promotions and makes **zero** Status A readiness promotions.

The machine-readable authority is `docs/scientific/registries/rb1-controlled-theory-formal-gap-decomposition.json`.

## Hard nonclaims

F-DOC11 does not:

- reopen RB1 science or release authority;
- alter production source, reference data, physics, solver, tolerances, mass criteria, temporal acceptance or performance policy;
- infer scientific theory from release qualification;
- mark any T0–T7 tier resolved;
- claim `FULLY_TRACED`, Status A readiness, Status A compliance or Status AA compliance;
- select or recommend a universal `H_budget`, temporal tolerance or groundwater-head accuracy budget;
- convert functional surface-evaporation MultiSWAP compatibility into a throughput/scaling claim.

## Residual work after F-DOC11

The decomposition makes the next work separable. Later bounded workunits may address controlled physical-science authority, controlled numerical/formal authority, controlled architecture/state semantics, or explicit tier-applicability decisions. T12 application validation, the controlled WR-QA-2024 dependency, application-specific temporal/groundwater error policy and surface-evaporation performance remain distinct gaps.

No later remediation may silently change physics or numerical policy while being labelled documentation work. Any discovered source defect must be persisted as a defect and routed to a separate production/scientific workunit.
