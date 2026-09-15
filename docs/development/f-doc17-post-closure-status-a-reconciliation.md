# F-DOC17 Post-Closure Status-A Reconciliation

## Decision

F-DOC17 reconciles the qualified historical Status-A readiness work against the live SWAP5 canonical state after the recent kernel, mass, solver-interface and surface-publication closures.

The decision is:

`PERSISTED_POST_CLOSURE_STATUS_A_RECONCILIATION_NOT_READY_FOR_FORMAL_ASSESSMENT`

This is a documentation and governance reconciliation. It does not certify Status A or Status AA, does not modify RB1, does not modify production or reference source, and does not change physics, solver policy, mass criteria, interfaces or architecture.

The current canonical baseline for this reconciliation is:

- branch: `integration/f-ci-canonical`;
- commit: `379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`;
- tree: `556221f62b4fde616981499eba68ef5460f5d83c`;
- canonical closeout at that head: F-CI59P atomic surface-publication postimage reconciliation.

Two F-DOC17 branch names existed before materialisation. Both pointed exactly at the canonical baseline above and contained no distinct F-DOC17 content. This work uses `work/f-doc17-post-closure-status-a-reconciliation` as the materialised work-unit branch. `work/f-doc17-rb1-status-a-post-closure-reconciliation` remains an untouched duplicate pointer and is not a second authority.

## Authority boundary

F-DOC17 keeps three evidence classes separate.

### 1. Immutable RB1 authority

RB1 remains immutable. The relevant frozen authorities remain:

- scientific source: `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`;
- qualification authority: `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`;
- final release authority: `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`;
- release closeout: `release/f-rb02/F-RB02_CLOSEOUT.json`.

Nothing in F-DOC17 changes the RB1 denominator, release meaning or qualification status.

### 2. Qualified historical documentation authority

F-DOC15 R1 at `75df47fb5cf6188535a9705165785fc8744b2cb2` is retained as the historical Status-A readiness authority. Its decision was `QUALIFIED_STATUS_A_READINESS_GAP_ASSESSMENT_RECONCILED_R1` and explicitly concluded that neither RB1 nor the then-current canonical snapshot was ready for formal Status-A assessment.

F-DOC18 at `bddb43d821fd757a307aad88528464dd0c89a484` is retained as qualified historical documentation evidence for the bounded RB1 `PHYSICAL_SCIENCE` T0 through T7 closure of:

- `RB1-SW-REFERENCE`;
- `RB1-ET-ROOT-SERIAL`;
- `RB1-SURFACE-EVAP-RESTRICTED`.

F-DOC18 is not an ancestor of the live canonical head. The branch and current canonical have diverged. Its qualification therefore remains historical branch authority and is not silently relabelled as current-canonical documentation.

F-DOC19 at `3161abec6a063f20e2184324248747d95a9a134c` is a separate agent-execution/documentation-navigation branch. No inspected evidence binds it to a Status-A scientific, validation or criterion closure. F-DOC17 therefore assigns it no Status-A closure credit.

### 3. Current-canonical implementation and qualification evidence

Current canonical has materially advanced since the snapshot assessed by F-DOC15 R1. In particular:

- F-CI57 records canonical admission and postpromotion preservation of F-KT18 fail-closed mass completeness, with invariant 13 passing and the frozen Kernel / Transactions / Generic Time / Mass v1 denominator at 8 of 8 qualified;
- F-CI58/F-CI58P record the mandatory production soil-water solver seam and its postimage reconciliation, including common-service use, transaction replay, hard mass, dynamic top-boundary regimes, bottom-boundary sensitivity, worker scratch isolation, research-solver isolation, MultiSWAP preservation and groundwater-coupling preservation;
- F-CI59/F-CI59P record atomic accepted surface-evaporation publication, independent replay, postpromotion qualification and permanent preservation.

These are strong implementation, transaction, mass, interface and qualification results. They do not by themselves establish scientific theory, application validation, sensitivity, uncertainty, parameter provenance, input-data provenance, fitness for purpose, user guidance or compliance with an unavailable controlled external quality criterion.

## WUR Status-A authority gate remains hard

The formal project criterion authority remains `WR-QA-2024`, `Revised checklist Status A/AA, 2024`.

The controlled full criterion text has not been established in the inspected repository state. The qualified historical documentation instead used `WR-QA-PUBLIC-22`, the public 22-requirement checklist, as an inspectable readiness denominator while explicitly forbidding an assumption that it is text-identical to the controlled 2024 authority.

F-DOC17 preserves the F-DOC01 authority gate. Before a result such as `STATUS_A_COMPLIANT`, `STATUS_A_QUALIFIED` or `SWAP5_HAS_STATUS_A` can be valid, the project must at minimum:

1. obtain the controlled `WR-QA-2024` authority or a formally designated replacement;
2. pin its issuer, version, source and full requirement set;
3. reconcile its exact differences from `WR-QA-PUBLIC-22`;
4. update the requirement mappings to that controlled authority;
5. complete the competent WUR assessment procedure;
6. bind the assessment result to an exact frozen SWAP5 release or assessment candidate.

Until then the maximum defensible internal outcome is readiness for review, not external Status-A compliance.

## Post-closure 22-row readiness reconciliation

The following matrix deliberately retains the F-DOC15 classification semantics. The recent closures improve evidence within several rows but do not remove the remaining evidence class required to promote those rows.

| Req | Family | Current classification | Post-closure reconciliation |
| --- | --- | --- | --- |
| 1.1 | ST.1 | `PARTIAL` | Conceptual foundation exists historically, but a current-candidate-bound application envelope and intended/non-intended application classes remain incomplete. |
| 1.2 | ST.1 | `PARTIAL` | Current canonical has much stronger mass, transaction and solver-interface evidence. That does not replace the remaining RB1 HYBRID T0-T7 scientific/formal authority or a complete post-RB1 theory/formal rebaseline. |
| 2.1 | ST.2 | `PARTIAL` | Implementation evidence is extensive, but no single frozen candidate-bound implementation account reconciles all post-RB1 deltas and residual T8-T10 obligations. |
| 2.2 | ST.2 | `PARTIAL` | CI/toolchain evidence is substantial; a complete assessed install/build/platform/limitations record is not consolidated. |
| 2.3 | ST.2 | `PARTIAL` | F-CI57, F-CI58P and F-CI59P strengthen testing and preservation materially. Complete claim/equation/contract-to-test T11 coverage and explicit untested scope remain incomplete. |
| 3.1 | ST.3 | `PARTIAL` | No complete model-wide parameter and variable registry with units, provenance, ownership, applicability and justified defaults/ranges is established. |
| 3.2 | ST.3 | `MISSING` | No complete calibration or explicit N/A authority by relevant parameter, process and application class. |
| 3.3 | ST.3 | `PARTIAL` | Typed contracts and adapters exist, but complete scientific/user I/O semantics and version lineage are not consolidated for an assessment candidate. |
| 3.4 | ST.3 | `MISSING` | Complete raw-data, preparation and adapter-to-kernel input provenance is not populated. |
| 4.1 | ST.4 | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | Sensitivity framework exists historically; controlled application-class sensitivity evidence remains absent. |
| 4.2 | ST.4 | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | Uncertainty framework exists historically; controlled application-level uncertainty evidence remains absent. |
| 4.3 | ST.4 | `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE` | Extensive verification, conservation, transaction and preservation evidence is not independent application validation. T12 remains open. |
| 4.4 | ST.4 | `MISSING` | No complete controlled use-monitoring/application evidence authority is established. |
| 4.5 | ST.4 | `PARTIAL` | Architecture and qualification are stronger, but application-class fitness for purpose still requires validation, sensitivity/uncertainty, decision criteria and limitations. |
| 5.1 | DO.5 | `SATISFIED` | Work-unit, gap, admission, preservation and closeout governance provide an explicit development mechanism. |
| 5.2 | DO.5 | `SATISFIED` | Git, exact-SHA authorities, immutable RB1 and canonical-admission governance remain established. |
| 6.1 | DO.6 | `PARTIAL` | Strong technical metadata exists, but the required controlled WUR/domain metadata package is not reconciled and populated for an assessment candidate. |
| 6.2 | DO.6 | `PARTIAL` | Technical ownership is visible; operational model-management roles, succession, continuity/resources and support responsibility remain incomplete as Status-A evidence. |
| 6.3 | DO.6 | `PARTIAL` | Dependencies are technically visible, but a complete controlled dependency and communication register with ownership/version boundaries is absent. |
| 6.4 | DO.6 | `MISSING` | External-use conditions, support route and responsibility boundaries are not consolidated as qualified assessment authority. |
| 7.1 | IU.7 | `PARTIAL` | Interpretation material exists, but validation, uncertainty, applicability, limitations and post-RB1 evidence binding are incomplete. |
| 7.2 | IU.7 | `PARTIAL` | No single release-bound Status-A-ready install, operation, I/O, diagnostics, limitations and support manual exists. |

Classification counts remain deliberately unchanged from F-DOC15 R1:

- `SATISFIED`: 2;
- `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE`: 3;
- `PARTIAL`: 13;
- `MISSING`: 4;
- `EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE`: 0;
- `NOT_APPLICABLE_WITH_RATIONALE`: 0.

These are readiness counts against the public 22-row working denominator, not a compliance percentage.

## What the recent closures do and do not close

The post-F-DOC15 canonical work eliminates several major software-architecture closure gaps. In particular, mass completeness, the mandatory production solver seam and accepted surface-publication semantics now have strong canonical qualification and preservation evidence.

That changes the quality of the evidence but not the formal Status-A verdict. A scientific quality assessment cannot replace missing application evidence with software verification. In particular:

- hard mass closure is not a T12 validation study;
- transaction/restart correctness is not sensitivity or uncertainty evidence;
- a common solver seam is not a parameter-provenance register;
- canonical CI preservation is not controlled external-use governance;
- branch-qualified RB1 science is not automatically current-canonical science documentation;
- an exact canonical head is not automatically a frozen assessment candidate while the integration branch continues moving.

## Minimal remaining closure set

F-DOC17 reduces the remaining work to evidence classes rather than creating more document numbers without need.

### P0 external criterion and assessment object

- Obtain and reconcile the controlled `WR-QA-2024` criterion authority.
- Freeze an exact SWAP5 assessment candidate or release candidate.
- Create a complete RB1-to-candidate science, interface, implementation and qualification delta rebaseline.

### P0 scientific and data evidence

- Close the remaining RB1 HYBRID T0-T7 scientific/formal authority, specifically `RB1-CORE-MASS` and `RB1-ROOT-PARALLEL`, without treating current implementation qualification as a substitute for theory/formal authority.
- Establish a model-wide parameter/variable/calibration-or-N/A/input-provenance authority.
- Establish independent T12 application validation for declared application classes.

### P1 application quality evidence

- Add application-class sensitivity analysis.
- Add controlled uncertainty analysis.
- Bind validation, sensitivity, uncertainty, accuracy/decision criteria and limitations into explicit fitness-for-purpose records.
- Establish monitored-use evidence where required.

### P1 traceability and management

- Complete affected T8-T11 traceability, including explicit deviations and untested scope.
- Reconcile controlled metadata, model-management roles, dependencies, external-use/support conditions and ownership continuity.

### P2 user guidance

- Produce one release-bound Status-A-ready user view covering installation, operation, inputs/outputs, diagnostics, water-balance interpretation, fallback/limitations, support and interpretation boundaries.

## Architecture-invariant audit

F-DOC17 changes documentation and work-unit metadata only. It introduces no production, reference, physics, solver, API, state, runtime, coupling, MultiSWAP or numerical-policy delta.

All 30 current SWAP architecture invariants are therefore unchanged by this workunit. In particular, invariants 7, 9, 11, 13, 16, 20, 23, 25, 26 and 30 are not broadened or weakened by the reconciliation. The recent current-canonical evidence is cited only for the scope it actually qualifies.

## Final conclusion

The live canonical state is materially stronger than the snapshot used in F-DOC15 R1. Several difficult software and architecture closure gaps have been genuinely closed and preserved.

That is not enough for formal Status-A assessment. The decisive remaining blockers are now predominantly external-criterion, scientific/application-evidence, provenance, traceability, model-management and release-bound documentation gaps rather than core transaction, mass or solver-seam implementation gaps.

F-DOC17 therefore closes the post-closure reconciliation question with a negative but bounded result:

`CURRENT_CANONICAL_MATERIALLY_STRONGER_STATUS_A_FORMAL_ASSESSMENT_NOT_YET_JUSTIFIED`
