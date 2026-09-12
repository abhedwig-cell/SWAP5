# F-DOC15 — SCI-FOUND-01 Physical-system-to-conceptual-model foundation assessment

## Decision

`SCI-FOUND-01` is **OPEN** and is a **Status-A closure gap**.

The current qualified scientific-documentation authority chain contains useful fragments of the required reasoning, but it does not contain one explicit, authoritative and qualified chain from the real physical hydrological system to the SWAP conceptual model and onward to the formal/numerical/implementation layers.

This result is deliberately fail-closed. Existing process descriptions, equations, architecture diagrams, release qualification and legacy SWAP documentation are not inferred to close the missing conceptual foundation.

## Assessment target

The required chain is:

`physical system -> modelling purpose -> spatial and temporal scales -> system boundary -> abstraction and idealisation -> conceptual model -> formal mathematical model -> numerical realization -> implementation`.

F-DOC01 already defines T0 `Physical system / phenomenon`, T2 `Conceptual model`, T3 `Formal mathematical model`, T6/T7 numerical realization and T10 implementation as distinct traceability tiers. That architecture proves that the distinction is intended; it does not populate the missing foundation by itself.

## Evidence that exists

The following existing material is relevant but insufficient for closure:

1. `docs/architecture/overview.md` on current post-RB1 canonical states a computational system boundary, a generic `[t0,t1]` time model and a target decomposition into SWAP kernel, runtime/coupler, adapters and optional external components.
2. `docs/architecture/component-map.md` describes target ownership boundaries between kernel, physical process modules, groundwater coupler, MultiSWAP runtime and optional deep-vadose transfer.
3. `F-DOC01_THEORY_TO_CODE_TRACEABILITY_ARCHITECTURE.md` defines the T0-T14 scientific spine and requires explicit included/excluded processes at T2.
4. F-DOC11 explicitly records that the physical-science family still requires a controlled physical-science chain and forbids substituting release verification for missing theory/formal authority.
5. F-DOC12 and F-DOC13 close bounded runtime-architecture and restricted TIME-REFERENCE formal gaps only. They do not establish the physical-system abstraction for SWAP as a whole.

These are fragments of architecture and traceability. They are not a scientific conceptualisation authority.

## Required questions and present disposition

| Required question | Present disposition | Reason |
|---|---|---|
| Which part of the physical soil-plant-atmosphere-hydrological system is represented by SWAP? | `PARTIAL` | Process/module boundaries exist, but no qualified physical-system scope narrative defines the represented real-world domain as one scientific object. |
| Why is the one-dimensional column abstraction admissible for intended applications? | `MISSING` | No qualified authority was found that derives or bounds the 1D abstraction from scale separation, lateral-homogeneity assumptions or application purpose. |
| Which processes are resolved, parameterised, prescribed as forcing/boundary conditions, or delegated externally? | `PARTIAL` | Target component ownership exists, but the scientific classification is not consolidated as a conceptual model authority. |
| What assumptions and limitations are introduced by the abstraction? | `MISSING` | Limitations exist locally in process/qualification artifacts, but the abstraction-level assumption set is not authoritative and complete. |
| How does one SWAP column relate to MultiSWAP, groundwater models, tiles and optional transfer components? | `PARTIAL` | Architecture/coupler documents are explicit, but they are system-composition contracts rather than the scientific justification of the column abstraction. |
| Under which validity limits is the abstraction fit for purpose? | `MISSING` | F-DOC01 defines a fitness-for-purpose framework, but populated application-class validity evidence is absent. |
| Are conceptual entities/processes traceable to formal scientific authorities? | `PARTIAL` | The T0-T14 graph architecture exists and several bounded chains are populated, but physical-process and model-foundation chains remain incomplete. |

## Why the current architecture overview does not close SCI-FOUND-01

The current architecture overview says that SWAP advances one or more soil-plant-atmosphere columns and places components such as deep-vadose transfer outside the kernel. This is valuable architecture, but it starts after the scientific abstraction decision has effectively already been made. It does not establish why a vertical column is an admissible representation of the relevant real system, which lateral processes are neglected or externalised, what spatial support a column represents, or how those assumptions constrain intended use.

Likewise, the component map establishes ownership and composition. It does not replace a conceptual hydrological model.

## RB1 versus current post-RB1 canonical

### Immutable RB1

RB1 remains scientifically and release-wise pinned by:

- scientific source authority `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`;
- qualification authority `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`;
- final release metadata authority `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`.

SCI-FOUND-01 is not closed for RB1. A later foundation document may describe the scientific abstraction underlying RB1, but it may not silently rewrite RB1 physics or broaden its qualified application scope.

### Current post-RB1 canonical snapshot

The F-DOC15 audit pins current canonical at `integration/f-ci-canonical@e537baf521e633c432a9f33de495fab9f18e918d` for assessment only. That snapshot contains a richer target architecture and many post-RB1 admitted capabilities, but SCI-FOUND-01 is also not closed there. The moving canonical branch is not itself a stable external Status-A certification target.

## Closure contract

A future `SCI-FOUND-01` closure artifact must be authoritative for **system scope, abstraction and conceptualisation**, while process-specific formal authorities remain authoritative for their mathematical formulations.

The closure artifact must explicitly establish at minimum:

1. the real-world soil-plant-atmosphere-hydrological domain being represented;
2. modelling purposes and application classes for which the abstraction is intended;
3. spatial support of one logical SWAP column, including the meaning of horizontal homogeneity and lateral-process exclusion/externalisation;
4. temporal support and the distinction between physical-process scales, forcing intervals, solver steps, coupling windows and reporting scales;
5. upper, lower and lateral system boundaries and the meaning of fluxes crossing each boundary;
6. a process disposition table classifying each major process as `RESOLVED`, `PARAMETERISED`, `FORCING`, `BOUNDARY_CONDITION`, `EXTERNAL_COMPONENT`, or `OUT_OF_SCOPE`;
7. the abstraction/idealisation choices that turn the real system into a 1D column conceptual model;
8. principal assumptions, known failure modes and nonclaims introduced by those choices;
9. relation of a logical column to standalone SWAP, MultiSWAP, tiles, direct groundwater coupling and optional deep-vadose transfer;
10. validity limits and application-class fitness consequences, with explicit links to validation/sensitivity/uncertainty evidence where available;
11. stable conceptual entity/process IDs and traceability to the applicable T1-T4 scientific authorities;
12. a delta statement that distinguishes immutable RB1 conceptual scope from any current/post-RB1 extensions without retroactively changing RB1.

The artifact may cite SWAP 4.3.1 manuals and primary literature as source material only after provenance and continuity are assessed. Legacy text is not automatically SWAP5 authority.

## Status-A effect

Until SCI-FOUND-01 is closed:

- requirement 1.1 remains at most `PARTIAL`;
- requirement 1.2 remains at most `PARTIAL`;
- requirement 4.5 cannot have a complete model-level fitness-for-purpose basis;
- requirement 7.1 cannot give complete interpretation guidance for the model abstraction;
- no `READY_FOR_STATUS_A_REVIEW` claim is justified for RB1 or current post-RB1 canonical.

## Suggested bounded closure workunit

`F-DOC16 — SWAP5 Physical-System Scope, 1D Column Abstraction & Conceptual Model Authority`

Owner: scientific model owner, with documentation/traceability owner as co-owner.

Work type: `SCIENCE + DOCUMENTATION`; production-code changes are forbidden unless a discrepancy discovered during the work is routed to a separate scientific/implementation workunit.
