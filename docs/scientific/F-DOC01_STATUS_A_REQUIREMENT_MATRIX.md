# F-DOC01 Status A requirement matrix

Authority state: the row numbering and targets below are derived from the publicly inspectable WUR 22-requirement checklist (`WR-QA-PUBLIC-22`). The formal SWAP5 project criterion authority is `WR-QA-2024`, `Revised checklist Status A/AA, 2024`. Its controlled full text was not obtained in F-DOC01, so every row remains `PENDING_2024_RECONCILIATION`. This matrix is suitable for architecture and gap analysis, not a compliance verdict.

| Req | Target evidence in SWAP5 | Primary F-DOC01 object | Initial state |
|---|---|---|---|
| 1.1 | purpose, application envelope, theory/paradigms | capability + fitness-for-purpose records | GAP_ANALYSED |
| 1.2 | conceptual/formal model, assumptions, simplifications, literature | T1-T4 graph | GAP_ANALYSED |
| 2.1 | implementation structure tied to code | T8-T10 graph | GAP_ANALYSED |
| 2.2 | language/toolchain/settings/technical limits | release/environment record | PARTIALLY_READY |
| 2.3 | test protocol, evidence, deviations, untested scope | F-TB01 crosswalk + T11 | PARTIALLY_READY |
| 3.1 | parameters/variables, units/defaults/provenance | parameter registry | GAP_ANALYSED |
| 3.2 | calibration procedure and effects where applicable | calibration records | GAP_ANALYSED |
| 3.3 | input/output semantics, precision, version trace | contract + I/O lineage | GAP_ANALYSED |
| 3.4 | raw-data-to-kernel provenance and preparation | input provenance graph | GAP_ANALYSED |
| 4.1 | documented/interpreted sensitivity evidence | sensitivity registry | GAP_ANALYSED |
| 4.2 | qualitative uncertainty assessment | uncertainty registry | GAP_ANALYSED |
| 4.3 | external-information validation and unvalidated scope | T12 validation registry | GAP_ANALYSED |
| 4.4 | monitored use and example applications | use-monitoring registry | GAP_ANALYSED |
| 4.5 | explicit application-class fitness for purpose | fitness-for-purpose object | GAP_ANALYSED |
| 5.1 | development gaps, plan and progress tied to evaluation | roadmap/gap registry | PARTIALLY_READY |
| 5.2 | development/release versioning, acceptance, differences, archive | Git/F-CI/release governance | PARTIALLY_READY |
| 6.1 | model metadata in required WR/domain format | metadata record | GAP_ANALYSED |
| 6.2 | management, ownership, succession, funding responsibilities | ownership/maintenance record | GAP_ANALYSED |
| 6.3 | input/output/third-party dependencies | dependency registry | GAP_ANALYSED |
| 6.4 | external-use conditions and support ownership | use/support record | GAP_ANALYSED |
| 7.1 | interpretation, assumptions, evaluation, applicability/nonclaims | interpretation + fitness-for-purpose view | GAP_ANALYSED |
| 7.2 | operation, install, system requirements, user I/O, support | generated user-manual view | GAP_ANALYSED |

## Assessment semantics

`PARTIALLY_READY` means that reusable version-controlled evidence exists, not that the formal requirement is satisfied. `GAP_ANALYSED` means the missing evidence class is identified. `READY_FOR_STATUS_A_REVIEW` may only be assigned after WR-QA-2024 reconciliation and evidence completion. External audit outcome is kept separately from internal readiness.

## Evidence ownership

This matrix never copies F-VQ, F-MQ, F-CI or F-TB01 evidence into a new authority. It points to exact existing evidence objects. Requirement coverage is a documentation relationship, not a second qualification decision.
