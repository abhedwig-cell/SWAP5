# F-DOC15 — RB1 and current-canonical Status-A readiness final gap assessment

## Decision scope

F-DOC15 is a documentation/governance assessment only. It does not alter production source, reference data, physics, solver policy, tolerances, mass criteria, RB1 authority or current-canonical admission. It does not certify Status A.

The purpose is to stop open-ended documentation growth and identify the bounded work that still separates the existing evidence from a defensible formal Status-A assessment.

## Assessment authorities

### WUR requirement authority

F-DOC01 remains the requirements authority.

- project control target: `WR-QA-2024`, `Revised checklist Status A/AA, 2024`;
- controlled full text status in F-DOC01: `NOT_OBTAINED`;
- inspectable assessment baseline: `WR-QA-PUBLIC-22`;
- fixed public denominator: **22 requirements** in seven families;
- authority artifact: `docs/scientific/F-DOC01_STATUS_A_REQUIREMENT_MATRIX.md`;
- authority head: `999d4fa3da6fa08c5d57e23b9949f3920de37fbe`.

All 22 public rows therefore remain subject to a later controlled `WR-QA-2024` reconciliation. The classifications below are readiness classifications against the pinned public baseline, not claims that the unknown controlled 2024 wording is satisfied.

### Qualified F-DOC chain rechecked live

| Workunit | Qualified authority head | F-DOC15 disposition |
|---|---|---|
| F-DOC01 | `999d4fa3da6fa08c5d57e23b9949f3920de37fbe` | admitted authority |
| F-DOC02 | `18942fee83eb385fccc1663230772ae03dcc9ae6` | admitted authority |
| F-DOC03 | `0c25d97bd180378a916fbb14a1e45768af9ec63a` | admitted reconciliation authority |
| F-DOC04 | `a703747ce1991c5601b76a84f04969b602298268` | admitted authority |
| F-DOC05 | `919f228d8aedc1029b5080bb019fbe61d2e1d7c6` | admitted authority |
| F-DOC06 | `c20c0fd4c53ef65f3c8d375362908a25f0855a4b` | admitted authority |
| F-DOC07 | `492b984bca282d6ec11dcaa727227b34c0ff3a84` | admitted authority |
| F-DOC08 | `8e5863510004ec11ab377b5bc9d3bd5df6d69777` | admitted authority |
| F-DOC09 | `2a4a8738496329001a3c3af9b5e50a9f31d0c44f` | admitted authority |
| F-DOC10 | `ef34a9f5a01d78ff9c2628315b484c5a8ff4f717` | admitted authority |
| F-DOC11 | `df438f8d0eaa4117e3e6df13a7061985fe233a16` | admitted authority |
| F-DOC12 | `e34caabe225986db3c60551f4168869f3e4cc2a2` | admitted authority |
| F-DOC13 | `1c63aeede05180d3628873083d9351da6e67175f` | admitted authority |
| F-DOC14 | branch points to F-DOC13 head; no `F-DOC14_STATUS.json` | **not an independent qualified authority** |

For F-DOC01 through F-DOC13 the required exact-head qualification workflow was rechecked live as successful. F-DOC14 is deliberately excluded from the authority chain.

### Immutable RB1 assessment object

- canonical scientific source: `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`;
- RB1 qualification authority: `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`;
- final RB1 release authority: `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`;
- release artifact: `integration/f-ci/F-RB02_RB1_RELEASE_AUTHORITY.json`;
- required exact-head F-RB02 release-authority workflow: rechecked successful;
- Git tag or GitHub Release: not required by the qualified F-RB01/F-RB02 authority.

RB1 is immutable and is not reopened by this assessment.

### Moving current-canonical assessment object

At the final live recheck used for this assessment:

- branch: `integration/f-ci-canonical`;
- snapshot head: `42544af575db522d012db491db801615577048df`;
- commit: `promote(F-CI49): admit definitive F-KT15 solver-service transaction composition`;
- parent canonical: `e537baf521e633c432a9f33de495fab9f18e918d`;
- F-CI49 is a true post-RB1 production admission and therefore cannot inherit RB1 documentation completeness by assertion;
- current-head Actions visible at the recheck are successful for the triggered canonical documentation/reference workflows.

This is a snapshot of a moving branch. A formal assessment of current canonical must freeze or name its candidate SHA and reconcile all documentation/evidence deltas to that exact SHA.

## Classification semantics

- `SATISFIED`: sufficient evidence and documentation are present for the pinned public requirement at the named assessment object.
- `EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE`: the underlying implementation/test evidence is sufficient but the controlled explanatory/user-facing documentation is not complete.
- `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE`: the governing framework/documentation exists but required empirical/scientific evidence is incomplete.
- `PARTIAL`: both useful evidence/documentation and material gaps remain, or the available evidence is not complete enough to use either asymmetric classification.
- `MISSING`: the required evidence object is not present in a form that can support assessment.
- `NOT_APPLICABLE_WITH_RATIONALE`: only permitted with an explicit, controlled rationale. No public requirement is assigned this status in F-DOC15.

## Requirement-by-requirement assessment

The identifiers below follow the exact 22-row F-DOC01 public matrix. Family labels are added only for readability.

| Req | Family | Pinned target | RB1 | Current canonical | Principal evidence and limiting fact |
|---|---|---|---|---|---|
| 1.1 | ST.1 | purpose, application envelope, theory/paradigms | PARTIAL | PARTIAL | F-DOC01 fitness/theory architecture exists; F-DOC11 leaves controlled physical/hybrid theory authority open; post-RB1 capabilities are not covered by an equivalent current-canonical theory closure. |
| 1.2 | ST.1 | conceptual/formal model, assumptions, simplifications, literature | PARTIAL | PARTIAL | F-DOC03-F-DOC13 improve bounded traceability; F-DOC10/11 explicitly retain controlled T0-T7 gaps; F-DOC13 closes only restricted TIME-REFERENCE T0-T7. |
| 2.1 | ST.2 | implementation structure tied to code | PARTIAL | EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE | RB1 has substantial T8-T10 traceability but F-DOC10 retains incomplete routes. Current F-CI49 has exact source/admission evidence, but the F-DOC line is RB1-scoped and does not document the post-RB1 composition as a current-canonical technical model view. |
| 2.2 | ST.2 | language/toolchain/settings/technical limits | PARTIAL | EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE | Qualified workflows demonstrate executable toolchains. Repository README still primarily documents the docs build and is not a complete SWAP5 execution/install environment description. Current canonical has stronger live CI evidence than controlled user-facing documentation. |
| 2.3 | ST.2 | test protocol, evidence, deviations, untested scope | PARTIAL | EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE | RB1 verification/qualification evidence is extensive but F-DOC10 retains incomplete whole-denominator T11 traceability. Current canonical has qualified admission/test evidence, including F-CI49, without a current-canonical Status-A test/evidence view. |
| 3.1 | ST.3 | parameters/variables, units/defaults/provenance | PARTIAL | PARTIAL | F-DOC01 defines the required parameter record; no complete evidence-backed model-wide parameter/variable registry with provenance, ranges/defaults and applicability is established. |
| 3.2 | ST.3 | calibration procedure and effects where applicable | PARTIAL | PARTIAL | F-DOC01 defines calibration records and N/A rationale, but does not manufacture calibration evidence. Model-wide applicable/non-applicable calibration coverage remains incomplete. |
| 3.3 | ST.3 | input/output semantics, precision, version trace | PARTIAL | PARTIAL | Kernel/adapter separation and many typed contracts are qualified, but there is no complete Status-A input/output semantic view for RB1, and post-RB1 typed interfaces extend the current-canonical surface. |
| 3.4 | ST.3 | raw-data-to-kernel provenance and preparation | PARTIAL | PARTIAL | F-DOC01 input-provenance policy exists; complete raw-data/preparation/provenance graphs for the model/application classes are not established. |
| 4.1 | ST.4 | documented/interpreted sensitivity evidence | DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE | DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE | F-DOC01 defines sensitivity classes and evidence levels and explicitly states that it creates no sensitivity results. Existing solver/interface sensitivities are not a model/application sensitivity assessment. |
| 4.2 | ST.4 | qualitative uncertainty assessment | DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE | DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE | F-DOC01 defines uncertainty classes and scope rules but creates no uncertainty results. No controlled model/application-class uncertainty assessment closes the requirement. |
| 4.3 | ST.4 | external-information validation and unvalidated scope | DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE | DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE | F-DOC01 verification/validation policy is explicit; F-DOC10-F-DOC13 keep T12 application validation open. Verification, legacy identity, conservation and cross-solver qualification are not validation. |
| 4.4 | ST.4 | monitored use and example applications | MISSING | MISSING | No qualified use-monitoring/application-example evidence object was found that closes the public requirement. Test cases are not automatically monitored real-world use. |
| 4.5 | ST.4 | explicit application-class fitness for purpose | DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE | DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE | The F-DOC01 fitness-for-purpose framework is explicit, including nonclaims and coupled use, but application-class records cannot be completed without validation plus sensitivity/uncertainty and independent accuracy/decision criteria. |
| 5.1 | DO.5 | development gaps, plan and progress tied to evaluation | SATISFIED | SATISFIED | F-DOC governance, bounded workunits, explicit residual-gap registries and current canonical admission governance provide a controlled development/gap/progress mechanism. |
| 5.2 | DO.5 | development/release versioning, acceptance, differences, archive | SATISFIED | SATISFIED | Git, exact-SHA authorities, F-CI admission, frozen RB1 authority and preservation/requalification records provide versioned acceptance and immutable historical authority. |
| 6.1 | DO.6 | model metadata in required WR/domain format | MISSING | MISSING | No qualified model-metadata record in the required controlled WR/domain format is established; controlled WR-QA-2024 is itself unavailable for reconciliation. |
| 6.2 | DO.6 | management, ownership, succession, funding responsibilities | PARTIAL | PARTIAL | F-DOC01 defines an ownership/maintenance schema, but a complete controlled operational record of responsible roles, succession and funding/maintenance obligations is not established. |
| 6.3 | DO.6 | input/output/third-party dependencies | PARTIAL | PARTIAL | Dependencies and couplings are visible in architecture/admission evidence, but no complete current controlled dependency register covers the whole assessed model and external communication surface. |
| 6.4 | DO.6 | external-use conditions and support ownership | PARTIAL | PARTIAL | Licensing and governance fragments exist; external-use conditions, support route and support ownership are not consolidated into a qualified operational record. |
| 7.1 | IU.7 | interpretation, assumptions, evaluation, applicability/nonclaims | PARTIAL | PARTIAL | F-DOC01 defines the required interpretation view, but missing validation, uncertainty, fitness and controlled theory prevent a complete user interpretation statement. Current-canonical additions also require delta reconciliation. |
| 7.2 | IU.7 | operation, install, system requirements, user I/O, support | PARTIAL | PARTIAL | The repository documents docs validation and many developer workflows, but not a comprehensive assessed SWAP5 user operation/install/I/O/support manual for RB1 or the moving current canonical. |

### Classification counts with fixed denominator 22

RB1:

- `SATISFIED`: 2
- `EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE`: 0
- `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE`: 4
- `PARTIAL`: 14
- `MISSING`: 2
- `NOT_APPLICABLE_WITH_RATIONALE`: 0

Current canonical snapshot `42544af575db522d012db491db801615577048df`:

- `SATISFIED`: 2
- `EVIDENCE_COMPLETE_DOCUMENTATION_INCOMPLETE`: 3
- `DOCUMENTATION_COMPLETE_EVIDENCE_INCOMPLETE`: 4
- `PARTIAL`: 11
- `MISSING`: 2
- `NOT_APPLICABLE_WITH_RATIONALE`: 0

These are counts, not compliance percentages.

## Scientific gap conclusions

1. **Validation is still open.** T12/application validation is explicitly open in F-DOC10-F-DOC13. Passing tests, conservation, restart identity, legacy preservation and solver cross-checks are verification/qualification evidence only.
2. **Sensitivity and uncertainty have architecture but not sufficient application evidence.** The framework is controlled; the required studies are not.
3. **Fitness for purpose cannot be inferred from numerical correctness.** Application classes need target outputs, decision scales, validation coverage, uncertainty/sensitivity and independent accuracy criteria.
4. **Applicability remains underdocumented.** Intended and unsupported uses must be connected to evidence, not copied from legacy narrative.
5. **Theory-code discrepancies remain a live governance object.** F-DOC11 decomposes the missing controlled T0-T7 authorities and resolves none by inference. F-DOC13 is a bounded numerical exception for TIME-REFERENCE, not model-wide theory closure.
6. **Parameter provenance is incomplete.** The policy exists, but a model-wide evidence-backed registry with origins, ranges/defaults, applicability, calibration role and uncertainty does not.
7. **User guidance is not yet comprehensive enough for Status A.** The interpretation architecture defines what a user must know, but the evidence needed to populate validation, uncertainty, applicability and nonclaims is incomplete.
8. **Current canonical is a distinct target.** F-CI49 admitted a definitive solver-service transaction composition after RB1. Its implementation/qualification evidence is strong, but RB1-scoped F-DOC authorities do not automatically document or validate the moving post-RB1 model.

## Global blockers outside individual public rows

### G0 — Controlled `WR-QA-2024` reconciliation

This blocks a defensible claim that the project-specific 2024 checklist is satisfied. Obtain the controlled authority, preserve its provenance/version, compare it with all 22 `WR-QA-PUBLIC-22` rows and add/alter requirements only through an explicit reconciliation authority. Do not silently assume equivalence.

### G1 — Current-canonical assessment candidate pin

A formal assessment cannot target an indefinitely moving branch. Name an exact candidate SHA, reconcile post-RB1 production/science/interface changes against the Status-A evidence set, and restart only affected evidence if the candidate changes.

G1 does not block formal assessment of immutable RB1. It does block formal assessment of a moving post-RB1 canonical unless a candidate snapshot is named.

## Architecture-invariant audit

F-DOC15 changes no production design. Against the 30 SWAP architecture invariants:

- no kernel/I/O coupling is introduced;
- no parameter/state/forcing/numerics/result ownership is changed;
- no persistent or scratch state is changed;
- transaction, rollback, generic time, coupling and mass contracts are not changed;
- no alternative solver, performance policy or physical option is altered;
- no MultiSWAP execution topology is altered;
- mass conservation remains hard;
- F-DOC15 makes no new physics, solver, performance, coupling or application-accuracy claim.

The only architecture-relevant decision is governance: documentation may not silently promote verification into validation, or RB1 evidence into current-canonical evidence.

## Readiness decision

The evidence is **not** sufficient for `QUALIFIED_READY_FOR_FORMAL_STATUS_A_ASSESSMENT` for either assessment object.

The qualified target for this workunit is therefore:

`QUALIFIED_STATUS_A_READINESS_GAP_ASSESSMENT_AND_CLOSURE_PLAN_ESTABLISHED`

This is a readiness-gap authority only. Formal Status A must be assessed separately by the competent process after the blocking gaps are closed. F-DOC15 never self-certifies Status A.
