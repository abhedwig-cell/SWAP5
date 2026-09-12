# F-DOC15 R1 — SWAP5 RB1 and current-canonical Status-A readiness final gap assessment

## Decision

This document is the reconciled R1 continuation of the qualified F-DOC15 authority at `1c4d97de16cf6d1eaf6289e920a32c4167536060`.

R1 decision, valid only when the exact branch head passes the dedicated F-DOC15 qualification workflow:

`QUALIFIED_STATUS_A_READINESS_GAP_ASSESSMENT_RECONCILED_R1`

Neither immutable RB1 nor the current-canonical snapshot is ready for a formal Status-A assessment. F-DOC15 R1 does not certify Status A or Status AA.

The important change since the original F-DOC15 assessment is that two previously open documentation/science gaps have genuinely closed on the same qualified lineage:

- F-DOC16 closes `SCI-FOUND-01`, the physical-system to 1D-column conceptual-foundation gap;
- F-DOC18 closes the three F-DOC11 `PHYSICAL_SCIENCE` capabilities at T0 through T7.

Those closures materially narrow the backlog. They do not close validation, sensitivity, uncertainty, parameter/input provenance, application-class fitness for purpose, complete T11 traceability, organisational/external-use evidence or user guidance.

## Authority lineage and reconciliation

The authoritative documentation lineage used here is:

1. F-DOC01 through F-DOC13, with F-DOC13 at `1c63aeede05180d3628873083d9351da6e67175f`;
2. qualified F-DOC15 at `1c4d97de16cf6d1eaf6289e920a32c4167536060`, exact-head run `34678212271`;
3. qualified F-DOC16 at `b0bdf08b5c38771a4ee22c93ed0949f408ceeb2b`, exact-head run `34678704795`;
4. qualified F-DOC18 at `bddb43d821fd757a307aad88528464dd0c89a484`, exact-head run `34679868415`;
5. this R1 reconciliation commit.

F-DOC14 remains not an independent authority.

The parallel branch `work/f-doc15-rb1-current-canonical-status-a-final-gap-assessment@81af9e509445b8e31caba00ef7c1d158da17dc45` had a green workflow and useful candidate material, but it diverged from the lineage on which F-DOC16 and F-DOC18 were qualified. It is therefore not promoted as the F-DOC15 authority. Its useful structure was reviewed as candidate evidence only.

## WUR Status-A criterion boundary

The project control target remains `WR-QA-2024`, `Revised checklist Status A/AA, 2024`.

Its controlled full text is still `NOT_OBTAINED`. The only inspectable denominator currently qualified by F-DOC01 is `WR-QA-PUBLIC-22`, exactly 22 public requirements in seven families. R1 therefore performs a readiness-gap assessment against those 22 rows. It reports no compliance percentage and makes no claim that the public wording is identical to the controlled 2024 checklist.

Obtaining and reconciling the controlled `WR-QA-2024` authority remains a hard prerequisite for a defensible formal Status-A assessment.

## Assessment objects

### Immutable RB1

Release: `SWAP5-RB1-v1`.

- scientific source authority: `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`;
- qualification authority: `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`;
- final release authority: `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`;
- authoritative closeout path: `release/f-rb02/F-RB02_CLOSEOUT.json`.

RB1 remains immutable. F-DOC15 R1 changes no RB1 source, reference data, release denominator, physics, numerical policy or acceptance criteria.

### Current post-RB1 canonical snapshot

The live canonical snapshot rechecked immediately before this R1 materialisation was:

`integration/f-ci-canonical@eba90d79010b095b6556e93bd8b77a8c28d25560`

with tree `ed3187c068697f17886cc85ddb9291dfbbd161d4`, commit `F-CI50P R1: finalize post-reconciliation closeout`.

That snapshot is 112 commits ahead of the RB1 scientific source. It includes post-RB1 admitted implementation and governance, including the F-CI50/F-CI50P-R1 groundwater-interface contract/policy lineage. F-CI50P-R1 explicitly does not admit production predictor-corrector execution or a MODFLOW adapter.

The canonical branch remains a moving integration branch. The snapshot above is evidence context, not a frozen release. A formal Status-A assessment of post-RB1 SWAP5 must name an exact assessment/release candidate and reconcile every affected scientific, implementation, verification and user-documentation delta to that SHA.

## What F-DOC16 and F-DOC18 actually closed

### Conceptual foundation

`SCI-FOUND-01` is closed by F-DOC16 at the conceptual-foundation level. The physical system, modelling purpose, relevant scales, system boundary, abstraction/idealisation and representative 1D-column conceptual model now have a qualified authority.

This closure is not application validation. It also does not replace process-specific scientific/formal authority.

### Physical-science T0 through T7

F-DOC18 closes all three capabilities assigned by F-DOC11 to `PHYSICAL_SCIENCE`:

- `RB1-SW-REFERENCE`;
- `RB1-ET-ROOT-SERIAL`;
- `RB1-SURFACE-EVAP-RESTRICTED`.

F-DOC12 already closes T0 through T7 applicability/state-transition authority for all nine `RUNTIME_ARCHITECTURE` capabilities. F-DOC13 closes all eight T0 through T7 dispositions for the single `NUMERICAL_METHOD` capability `RB1-TIME-REFERENCE`.

Therefore the only unresolved F-DOC11 T0 through T7 family is now `HYBRID`, exactly:

- `RB1-CORE-MASS`;
- `RB1-ROOT-PARALLEL`.

That is the correct remaining RB1 theory/formal gap. The older generic blockers `SCI-FOUND-01` and `PHYSICAL-SCIENCE-T0-T7` must no longer be reported as open.

## Classification semantics

- `SATISFIED`: sufficient controlled evidence is present for readiness analysis against the public row, subject to later controlled WR-QA-2024 reconciliation and formal assessment.
- `EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE`: underlying evidence is sufficient but the controlled assessment/user view is incomplete.
- `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE`: the governing documentation/framework exists but required scientific or empirical evidence is incomplete.
- `PARTIAL`: material evidence/documentation exists, but both coverage and/or binding are incomplete.
- `MISSING`: the required evidence object is not established at Status-A-ready level.
- `NOT_APPLICABLE_WITH_RATIONALE`: permitted only with explicit controlled rationale.

## 22-requirement readiness matrix

| Req | Family | RB1 | Current snapshot | Principal remaining gap |
|---|---|---|---|---|
| 1.1 | ST.1 | `PARTIAL` | `PARTIAL` | F-DOC16 closes the conceptual foundation, but the application envelope and evidence-bounded intended/non-intended application classes remain incomplete; current canonical also needs post-RB1 science reconciliation. |
| 1.2 | ST.1 | `PARTIAL` | `PARTIAL` | Runtime, TIME-REFERENCE and physical-science families are now closed at T0-T7; `RB1-CORE-MASS` and `RB1-ROOT-PARALLEL` remain open as HYBRID T0-T7 authorities. Current canonical has additional post-RB1 formal/scientific delta obligations. |
| 2.1 | ST.2 | `PARTIAL` | `PARTIAL` | Residual T8-T10 implementation mappings and one release/candidate-bound technical implementation view remain incomplete. |
| 2.2 | ST.2 | `PARTIAL` | `PARTIAL` | Reproducible environment/toolchain evidence exists in workflows, but a complete assessed install/build/platform/limitations record is not yet consolidated. |
| 2.3 | ST.2 | `PARTIAL` | `PARTIAL` | Qualification is extensive, but complete equation/contract-to-test T11 coverage, deviations and explicit untested scope remain incomplete. |
| 3.1 | ST.3 | `PARTIAL` | `PARTIAL` | No complete model-wide parameter/variable registry with units, provenance, defaults/ranges where real, ownership and applicability is established. |
| 3.2 | ST.3 | `MISSING` | `MISSING` | No complete calibration-or-explicit-N/A authority by relevant parameter/process/application class. |
| 3.3 | ST.3 | `PARTIAL` | `PARTIAL` | Typed contracts exist, but complete scientific/user I/O semantics and adapter/version lineage are not consolidated. |
| 3.4 | ST.3 | `MISSING` | `MISSING` | Complete raw-data/preparation/adapter-to-kernel provenance is not populated. |
| 4.1 | ST.4 | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | Sensitivity framework exists; scoped application evidence does not. |
| 4.2 | ST.4 | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | Uncertainty framework exists; controlled application-level uncertainty evidence does not. |
| 4.3 | ST.4 | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | T12 independent application validation remains open. Verification, conservation, restart identity and cross-solver checks are not validation. |
| 4.4 | ST.4 | `MISSING` | `MISSING` | No complete controlled use-monitoring/application evidence authority. |
| 4.5 | ST.4 | `PARTIAL` | `PARTIAL` | Conceptual foundation is now qualified, but application-class fitness-for-purpose records still require validation, sensitivity/uncertainty, accuracy/decision criteria and limitations. |
| 5.1 | DO.5 | `SATISFIED` | `SATISFIED` | Controlled workunit/gap/admission governance provides an explicit development and closure mechanism. |
| 5.2 | DO.5 | `SATISFIED` | `SATISFIED` | Git, exact-SHA authorities, immutable RB1 and canonical-admission governance are established. |
| 6.1 | DO.6 | `PARTIAL` | `PARTIAL` | Strong RB1 release metadata exists, but the required controlled WR/domain metadata package is not reconciled/populated. |
| 6.2 | DO.6 | `PARTIAL` | `PARTIAL` | Ownership schema exists; operational roles, succession, continuity/resources and support responsibility remain incomplete. |
| 6.3 | DO.6 | `PARTIAL` | `PARTIAL` | Technical dependencies are visible, but a complete controlled dependency/communication register with ownership/version boundaries is absent. |
| 6.4 | DO.6 | `MISSING` | `MISSING` | External-use conditions, support route and responsibility boundaries are not consolidated as a qualified authority. |
| 7.1 | IU.7 | `PARTIAL` | `PARTIAL` | Conceptual interpretation improved through F-DOC16/F-DOC18, but validation, uncertainty, applicability, limitations and current-canonical delta guidance remain incomplete. |
| 7.2 | IU.7 | `PARTIAL` | `PARTIAL` | No single release-bound Status-A-ready operation/install/I/O/diagnostics/limitations/support manual exists. |

Classification counts for both RB1 and this current-canonical snapshot are deliberately conservative:

- `SATISFIED`: 2;
- `EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE`: 0;
- `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE`: 3;
- `PARTIAL`: 13;
- `MISSING`: 4;
- `NOT_APPLICABLE_WITH_RATIONALE`: 0.

These are counts, not compliance percentages.

## Remaining blockers after reconciliation

The residual gap is no longer dominated by missing conceptual framing. It is now concentrated in five evidence classes plus governance/publication closure:

1. the two RB1 HYBRID T0-T7 authorities and post-RB1 science/formal delta reconciliation;
2. complete implementation/test traceability, especially residual T8-T10 and complete T11 graphs;
3. parameter/variable/calibration/input provenance;
4. empirical application evidence: T12 validation, sensitivity, uncertainty, monitored use and application-class fitness for purpose;
5. controlled model-management, metadata, dependency/external-use and user-guidance evidence;
6. the external `WR-QA-2024` controlled-authority reconciliation;
7. for current canonical only, an exact frozen assessment candidate and complete post-RB1 delta rebaseline.

## Bounded closure backlog

| Priority | Gap | Evidence needed | Accountable role | Work type | Dependency | Blocks RB1 | Blocks current |
|---|---|---|---|---|---|---|---|
| P0 | Controlled `WR-QA-2024` reconciliation | Controlled checklist, provenance/version, exact delta to PUBLIC-22 | WUR QA authority owner + SWAP model manager | governance + documentation | external authority | yes | yes |
| P0 | RB1 HYBRID T0-T7 | Explicit T0-T7 dispositions for `RB1-CORE-MASS` and `RB1-ROOT-PARALLEL`, preserving single mass booking and serial/parallel scientific equivalence | scientific lead + runtime/numerical lead | science + documentation | F-DOC11/12/13/16/18 | yes | yes as RB1 inheritance base |
| P0 | Parameter/provenance/calibration | Model-wide parameter/variable registry, origin, units, ranges/defaults where real, calibration or N/A, raw-input transformation provenance | parameter/data steward + scientific lead | science + data + documentation | process authorities | yes | yes |
| P0 | T12 application validation | Independent observations/experiments/benchmarks, metrics, scales, provenance, explicit unvalidated scope | validation lead + application owners | science | application classes + data | yes | yes |
| P0 | Current-canonical freeze/rebaseline | Exact candidate SHA, RB1-to-candidate capability/science/interface delta and affected evidence requalification | release/integration owner + model manager | release + governance + documentation | stable candidate | no | yes |
| P1 | Sensitivity and uncertainty | Scoped decision-relevant sensitivity plus qualitative/quantitative uncertainty evidence with interpretation | scientific analysis owner | science | parameter registry + application classes | yes | yes |
| P1 | Fitness for purpose and use monitoring | Application-class outputs/scales/required physics/accuracy criteria, validation support, uncertainty, limitations, monitored use | scientific lead + application owners + model manager | science + governance + user guidance | validation + sensitivity/uncertainty | yes | yes |
| P1 | Complete T8-T11 traceability | Claim/equation/contract to implementation to permanent test/oracle, including deviations and untested scope | technical lead + testbank lead | verification + documentation | formal authorities | yes | yes |
| P1 | Metadata, management, dependencies and external use | Controlled metadata, ownership/succession, dependency register, support and external-use conditions | model manager + metadata/support owners | governance + documentation | WR-QA reconciliation for exact fields | yes | yes |
| P2 | Status-A-ready user guidance | Release-bound install/operation/I/O/diagnostics/mass-balance/fallback/limitations/support and interpretation view | user-documentation owner + scientific/technical leads | documentation + user guidance | upstream evidence largely closed | yes | yes |

This backlog is intentionally bounded by evidence class. New work should close one of these named gaps. A new documentation workunit is not justified merely because another document number is available.

## Architecture-invariant audit

F-DOC15 R1 is documentation/governance reconciliation only. It changes no production source or reference data and introduces no architecture delta. All 30 SWAP architecture invariants were reviewed as unchanged for this workunit. In particular:

- kernel/I-O separation remains unchanged;
- state, forcing, numerical-policy and result ownership remain unchanged;
- transaction/rollback and generic-time semantics remain unchanged;
- MultiSWAP execution topology is unchanged;
- coupling contracts are not broadened;
- physical options remain separate from solver policy;
- mass conservation remains hard and non-negotiable.

## Final readiness conclusion

RB1 is a strong immutable restricted production baseline with much stronger conceptual and physical-science documentation than at the original F-DOC15 assessment. It is still **not ready for formal Status-A assessment**, mainly because empirical application evidence, provenance, complete traceability, management/user evidence, the two HYBRID T0-T7 authorities and the controlled WR-QA-2024 authority remain incomplete.

The current canonical snapshot is also **not ready**. In addition to the shared gaps, it needs an exact frozen candidate and a full post-RB1 evidence/documentation rebaseline.

Verification was not relabelled as validation. F-DOC16 conceptual admissibility is not empirical validation. F-DOC18 physical-science closure is not complete T11 traceability or T12 validation. No Status-A or Status-AA certification is claimed.