# F-DOC15 — SWAP5 RB1 and Current-Canonical Status-A Readiness Final Gap Assessment & Closure Plan

## Decision

Exit decision:

`QUALIFIED_STATUS_A_READINESS_GAP_ASSESSMENT_AND_CLOSURE_PLAN_ESTABLISHED`

This workunit does **not** claim `QUALIFIED_READY_FOR_FORMAL_STATUS_A_ASSESSMENT` and does not certify Status A.

The reason is substantive, not administrative: multiple Status-A evidence classes remain incomplete, especially the physical-system-to-conceptual-model foundation, physical-science authority, parameter/input provenance, sensitivity, uncertainty, validation, fitness for purpose, organisational/external-use evidence and user guidance. In addition, the controlled `Revised checklist Status A/AA, 2024` has not yet been obtained and reconciled against the public 22-requirement baseline.

## Authority boundary

The formal SWAP5 criterion authority remains `WR-QA-2024`, `Revised checklist Status A/AA, 2024`, but its controlled copy is still unavailable. F-DOC15 therefore uses the fixed `WR-QA-PUBLIC-22` denominator of **22 requirements** for readiness-gap analysis only. No percentage is reported.

Live recheck result for the documentation chain:

- F-DOC01 through F-DOC13: qualified authorities and used;
- F-DOC14: **not** a distinct qualified authority. The live branch points to the F-DOC13 head and contains no independent F-DOC14 closeout/qualification artifact;
- therefore F-DOC15 does not treat the existence of the F-DOC14 branch name as evidence that the physical-science formal-authority work is complete.

## Assessment objects

### Immutable RB1

The immutable release object is `SWAP5-RB1-v1` with:

- scientific source authority: `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`;
- qualification authority: `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`;
- release metadata authority: `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`.

RB1 has a fixed required denominator of 15 capabilities. F-DOC07 established complete 15/15 capability-population coverage, but explicitly not complete scientific traceability or Status-A readiness.

### Current post-RB1 canonical snapshot

The live current canonical assessed here is:

`integration/f-ci-canonical@e537baf521e633c432a9f33de495fab9f18e918d`

with tree `b55f077657fc82b421a63f927965ff47821fc987`.

This branch is 74 commits ahead of the RB1 scientific-source authority at the time of this audit. It is a moving integration authority, not an immutable release. Its Status-A readiness therefore cannot simply be inherited from RB1. A future formal Status-A assessment must bind to an exact frozen candidate/release, not to a moving branch name.

The current canonical documentation tree also does not itself contain the F-DOC01-F-DOC13 `docs/scientific` authority set. Those documentation authorities exist on their qualified documentation lineage and are evidence inputs to this audit, but they are not silently treated as if already admitted into the moving canonical tree.

## Classification semantics

- `SATISFIED`: sufficient evidence and documentation are present for readiness analysis against the public requirement heading, subject to the still-open WR-QA-2024 reconciliation and external audit.
- `EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE`: evidence is sufficient but the Status-A documentation view is incomplete.
- `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE`: required documentation architecture/content exists but scientific or empirical evidence is incomplete.
- `PARTIAL`: both documentation and/or evidence are materially incomplete, but relevant qualified material exists.
- `MISSING`: the required evidence object is not presently established at Status-A-ready level.
- `NOT_APPLICABLE_WITH_RATIONALE`: only used where the requirement is genuinely not applicable and the rationale is explicit.

## 22-requirement readiness matrix

| Req | Heading | Immutable RB1 | Current canonical snapshot | Primary evidence / remaining gap |
|---|---|---|---|---|
| 1.1 | General model description | `PARTIAL` | `PARTIAL` | Purpose/scope fragments exist, but `SCI-FOUND-01` is open: no qualified real-system -> purpose -> scales -> boundary -> abstraction -> conceptual-model chain. |
| 1.2 | Conceptual and formal model documented | `PARTIAL` | `PARTIAL` | Runtime and TIME-REFERENCE formal authorities are strong; physical-system conceptualisation and physical-process formal chains remain incomplete. |
| 2.1 | Implementation documented | `PARTIAL` | `PARTIAL` | Exact production/release authorities exist, but complete T8-T10 mappings across all scientific capabilities are not yet closed. Current canonical also needs post-RB1 consolidated mapping. |
| 2.2 | Technical environment documented | `PARTIAL` | `PARTIAL` | CI/toolchain evidence exists, but one Status-A-ready environment/limitations record bound to the assessed release is not complete. |
| 2.3 | Model tested | `PARTIAL` | `PARTIAL` | Extensive qualification/testbanks exist, but complete T11 equation-to-test graphs and explicit untested/deviation scope are not complete across the model. |
| 3.1 | Parameters and variables documented | `PARTIAL` | `PARTIAL` | F-DOC01 defines the required parameter schema; complete populated parameter/variable units/default/range/provenance coverage is absent. |
| 3.2 | Calibration described | `MISSING` | `MISSING` | No complete calibrated/not-applicable per-parameter/application-class authority exists. |
| 3.3 | Input and output described | `PARTIAL` | `PARTIAL` | Typed contracts and architecture exist; complete scientific semantics, precision and version lineage for user-facing I/O are not yet consolidated. |
| 3.4 | Origin of input data described | `MISSING` | `MISSING` | Provenance policy exists, but no complete raw-data -> preprocessing -> adapter -> typed object -> kernel lineage is populated. |
| 4.1 | Sensitivity analysis performed | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | Sensitivity architecture is defined; model/application-class coverage is not complete. |
| 4.2 | Uncertainty analysis performed | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | Uncertainty architecture is defined; qualitative/quantitative evidence coverage is incomplete. |
| 4.3 | Model validated | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | Validation is correctly distinguished from verification, but T12 application-class validation evidence is materially incomplete. |
| 4.4 | Use monitored | `MISSING` | `MISSING` | No complete use-monitoring authority with applications, issues and feedback loop was found. |
| 4.5 | General quality assessment | `PARTIAL` | `PARTIAL` | Fitness-for-purpose framework exists, but application-class evidence and `SCI-FOUND-01` validity limits are not populated sufficiently. |
| 5.1 | Development plan | `SATISFIED` | `SATISFIED` | Qualified gap registries, migration gates, workunit governance and this closure plan provide explicit development planning. |
| 5.2 | Version control system | `SATISFIED` | `SATISFIED` | Git, exact SHA/tree binding, qualification, immutable RB1 release authority and canonical-admission governance are established. |
| 6.1 | Metadata available | `PARTIAL` | `PARTIAL` | RB1 release metadata is strong, but required WUR/domain metadata format remains subject to WR-QA-2024 reconciliation and current-canonical snapshot metadata is not a release dossier. |
| 6.2 | Management plan | `PARTIAL` | `PARTIAL` | Ownership/maintenance schema exists; named/organisational assignments, succession, continuity and support responsibilities are incomplete. |
| 6.3 | Dependencies discussed | `PARTIAL` | `PARTIAL` | Technical dependencies and component boundaries are documented; Status-A-level external dependency ownership/obligations are not fully populated. |
| 6.4 | External use formalised | `MISSING` | `MISSING` | No complete external-use/support/conditions authority was established by the qualified F-DOC chain. |
| 7.1 | Interpretation guidance | `PARTIAL` | `PARTIAL` | Interpretation architecture exists, but model-abstraction assumptions, validation/uncertainty limits and application-class guidance remain incomplete. |
| 7.2 | User manual | `PARTIAL` | `PARTIAL` | Documentation exists, but there is not yet one Status-A-ready operational/user manual view covering installation, supported scope, I/O, diagnostics, limitations and support. |

No requirement is marked `NOT_APPLICABLE_WITH_RATIONALE` at this model-level Status-A assessment because all 22 public requirement headings are relevant to SWAP5 as a maintained scientific model/software product. Sub-elements within a requirement may still be explicitly N/A where justified.

## Scientific gaps that block readiness

### SCI-FOUND-01 — physical-system-to-conceptual-model foundation

Status: `OPEN_BLOCKER`.

F-DOC15 separately records the detailed assessment in `F-DOC15_SCI_FOUND_01_ASSESSMENT.md`. The qualified chain lacks one authoritative scientific reasoning path from the physical soil-plant-atmosphere-hydrological system through modelling purpose, scale, boundaries, abstraction and idealisation to the SWAP conceptual model. Existing equations or implementation do not close this gap.

### Physical-science T0-T7 authority

Status: `OPEN_BLOCKER`.

F-DOC11 identifies physical-science authority gaps for `RB1-SW-REFERENCE`, `RB1-ET-ROOT-SERIAL` and `RB1-SURFACE-EVAP-RESTRICTED`, and hybrid gaps for `RB1-CORE-MASS` and `RB1-ROOT-PARALLEL`. F-DOC14 has not actually closed them.

### Validation

Status: `OPEN_BLOCKER`.

Verification, conservation, legacy comparison and cross-solver qualification are not validation. Application-class T12 evidence against observations, experiments or defensible independent application benchmarks remains incomplete.

### Sensitivity and uncertainty

Status: `OPEN_BLOCKER`.

The documentation architecture is sound, but it intentionally contains no fictitious results. Status-A readiness requires populated, scoped sensitivity and uncertainty evidence sufficient for the intended application classes.

### Fitness for purpose and applicability

Status: `OPEN_BLOCKER`.

There is a first-class framework but no sufficiently populated application-class dossier that binds required outputs, scales, processes, accuracy expectations, validation coverage, uncertainty, limitations and unsupported uses.

### Parameter and input provenance

Status: `OPEN_BLOCKER`.

The schema and provenance policy exist. Complete parameter/variable population, calibration/N-A decisions, defaults/ranges and raw-input-to-kernel provenance do not.

### Theory-code discrepancies

Status: `OPEN_CONTROLLED_RISK`.

F-DOC01 has a discrepancy policy and requires scientific-change chains. Status A requires all material known theory-code discrepancies affecting the assessed release either to be closed or explicitly bounded as limitations/nonclaims. A release PASS may not erase an unresolved scientific discrepancy.

### User guidance

Status: `OPEN_BLOCKER`.

A user-facing publication architecture exists, but the actual guidance is not yet complete enough to let an external user determine supported applications, abstraction assumptions, active processes, parameter/input provenance, numerical policy, diagnostics, validation/uncertainty coverage and nonclaims from a single release-bound user view.

## Prioritised closure backlog

| Priority | Gap / requirement | Evidence needed | Owner | Work type | Dependency | Blocks formal Status A? | Suggested bounded workunit |
|---|---|---|---|---|---|---|---|
| P0 | `SCI-FOUND-01`; 1.1, 1.2, 4.5, 7.1 | Authoritative real-system -> purpose -> scales -> boundary -> abstraction -> conceptual-model chain; 1D admissibility; process disposition; composition; validity limits; conceptual-to-formal traceability | scientific model owner + documentation owner | science + documentation | F-DOC01-F-DOC13; immutable RB1 scope | YES | `F-DOC16` |
| P0 | WR-QA-2024 authority gate; all requirements | Controlled 2024 checklist, exact numbering/text, delta against PUBLIC-22, migrated matrices | quality-audit/documentation owner | governance + documentation | external controlled authority | YES | `F-DOC17` |
| P0 | Physical-science formal authority; 1.2, 2.1, 2.3, 7.1 | T0-T7 chains for soil-water reference, ET/root, surface evaporation and hybrid mass/root-parallel families, including literature/provenance and explicit nonclaims | scientific process owners | science + documentation | `SCI-FOUND-01` should define shared conceptual frame first | YES | `F-DOC18` |
| P0 | Validation; 4.3, 4.5, 7.1 | Application-class observation/experiment/benchmark datasets, metrics, provenance, version, limitations and explicit unvalidated scope | validation/scientific owner | science | SCI-FOUND-01 + application classes + stable assessed release | YES | `F-VAL01` |
| P0 | Parameter/variable/calibration/input provenance; 3.1-3.4 | Populated parameter and variable registry, units/defaults/ranges/provenance, calibration/N-A records, raw->preprocess->adapter->kernel chains | parameter/data owner | science + data + documentation | SCI-FOUND-01/process authorities | YES | `F-DOC19` |
| P0 | Current-canonical assessment target | Freeze exact post-RB1 release candidate, enumerate delta from RB1, bind qualification and documentation denominator | release authority + integration owner | release/governance | post-RB1 integration/rebaseline authority | YES for current canonical | `F-RB03` |
| P1 | Sensitivity; 4.1 | Scoped parameter/numerical/forcing/structural sensitivity studies with outputs, ranges and interpretation | scientific analysis owner | science | application classes + parameter registry | YES | `F-SENS01` |
| P1 | Uncertainty; 4.2 | Qualitative minimum plus quantitative evidence where required, with forcing/parameter/structural/model-form/numerical/output uncertainty | scientific analysis owner | science | parameter/input provenance + application classes | YES | `F-UNC01` |
| P1 | Fitness for purpose; 4.5, 7.1 | Populated application-class records tying purpose, scales, required physics, error expectations, validation, sensitivity/uncertainty and nonclaims | scientific owner + application owner | science + documentation | SCI-FOUND-01, validation, sensitivity, uncertainty | YES | `F-FFP01` |
| P1 | Complete T11 graph; 2.3 | Equation/contract/algorithm -> permanent tests/oracles -> exact evidence authority, plus untested/deviation scope | verification/testbank owner | verification + documentation | physical/formal authorities | YES | `F-DOC20` |
| P1 | Organisational management; 6.2, 6.3 | Maintained role assignments, succession, continuity/funding where required, external-dependency owners and escalation | model management | governance | organisational decisions | YES | `F-GOV02` |
| P1 | External use; 6.4 | Formal external-use conditions, support ownership, release/use policy and responsibility boundary | model management + legal/support owner | governance + user guidance | management plan | YES | `F-GOV03` |
| P1 | Use monitoring; 4.4 | Registered applications/use cases, issue/feedback monitoring, review trigger and linkage to fitness/validation | model management + scientific owner | governance + science | external-use/application-class registry | YES | `F-USE01` |
| P2 | User manual and interpretation; 7.1, 7.2 | Release-bound user view for installation, supported scope, I/O, model assumptions, diagnostics, mass balance, fallback, limitations, support | documentation/user-support owner | documentation + user guidance | upstream scientific gaps largely closed | YES | `F-DOC21` |
| P2 | Metadata packaging; 6.1, 2.2 | WUR-required metadata/environment record bound to exact release, including system/toolchain/dependency limits | release/documentation owner | documentation | WR-QA-2024 reconciliation + frozen candidate | YES | `F-DOC22` |

The backlog is intentionally bounded. It is not a proposal to keep incrementing DOC numbers indefinitely. Each workunit must close a named Status-A evidence gap or it should not exist.

## RB1 readiness conclusion

RB1 is a strong restricted production release with immutable scientific, qualification and metadata authority. It also has mature architecture, transaction/restart/MultiSWAP qualification and extensive verification evidence.

It is nevertheless **not ready for formal Status-A assessment** yet. The blocking gaps are primarily scientific/documentary rather than release-engineering gaps: conceptual foundation, physical-science formal chains, validation, sensitivity/uncertainty, parameter/input provenance, fitness for purpose, organisational/external-use evidence and complete user guidance. The controlled WR-QA-2024 authority gate is additionally mandatory.

## Current-canonical readiness conclusion

The post-RB1 canonical snapshot is **not ready for formal Status-A assessment** and cannot inherit RB1 readiness automatically. It has substantial additional admitted implementation capability, but it is a moving integration branch and its consolidated Status-A documentation/evidence denominator has not been rebaselined to those post-RB1 changes.

Before formal assessment, current canonical must become an exact frozen assessment/release candidate, enumerate its delta from RB1, bind post-RB1 scientific/verification authorities, and re-run the same 22-requirement readiness process on that frozen object.

## Hard nonclaims

F-DOC15 does not:

- certify Status A or Status AA;
- claim the public 22-requirement wording is identical to the controlled 2024 checklist;
- infer validation from verification;
- infer conceptual-model validity from implementation existence;
- infer theory from legacy SWAP code;
- reopen immutable RB1 science, production source or release authority;
- change production source, physics, solver, mass criteria, numerical policy or acceptance thresholds;
- treat the unimplemented F-DOC14 branch name as qualified physical-science authority;
- treat a moving canonical branch as a certified release.
