# F-DOC01 Status AA requirement matrix

Status AA is modelled as a separate readiness layer. `Status A + more text` is not an AA architecture. The public WUR checklist states criterion-specific AA additions for most requirements. These targets are provisional until the controlled `Revised checklist Status A/AA, 2024` is reconciled.

| Req | Public AA addition represented by SWAP5 target | Initial AA readiness |
|---|---|---|
| 1.1 | no separate public AA addition identified | PENDING_2024_RECONCILIATION |
| 1.2 | motivate model complexity relative to use and support scientific basis with peer-reviewed publication | GAP |
| 2.1 | code commenting, motivated modular design, review external to development team | GAP |
| 2.2 | no separate public AA addition identified | PENDING_2024_RECONCILIATION |
| 2.3 | scheduled testing and periodic review of test completeness | PARTIAL |
| 3.1 | parameter/value ranges, default uncertainty and precision | GAP |
| 3.2 | no separate public AA addition identified | PENDING_2024_RECONCILIATION |
| 3.3 | address relevant standards and echo input/settings/execution provenance | GAP |
| 3.4 | acquisition protocol for raw data where applicable, periodically updated | GAP |
| 4.1 | repeatable sensitivity protocol and periodic completeness review | GAP |
| 4.2 | quantitative uncertainty analysis with motivated method and periodic scope review | GAP |
| 4.3 | version-aware validation protocol and periodic breadth review | GAP |
| 4.4 | track/evaluate user experience and feed it into development planning | GAP |
| 4.5 | include data reliability/accuracy/precision and external scientific peer review | GAP |
| 5.1 | development timeline, planned extended evaluations and periodic plan update | PARTIAL |
| 5.2 | formal protocol for documentation and code commenting | PARTIAL |
| 6.1 | current public metadata according to FAIR principles | GAP |
| 6.2 | future-use/development vision, risks/opportunities and periodic management-plan update | GAP |
| 6.3 | track dependencies, continuation risks, obligations and liabilities | GAP |
| 6.4 | legally checked user agreement aligned with ownership and financial arrangements | GAP |
| 7.1 | reflect on purpose/domain versus complexity, implementation limits, data quality/availability and realised performance | GAP |
| 7.2 | no separate public AA addition identified | PENDING_2024_RECONCILIATION |

## AA readiness object

Each capability-level AA record contains at least:

- `status_a_complete`;
- `aa_additional_requirements_known`;
- `aa_evidence_available`;
- `independent_or_external_review_complete`;
- `quantitative_uncertainty_complete`;
- `validation_breadth_sufficient`;
- `fair_and_management_requirements_satisfied`;
- `remaining_gaps`;
- `criterion_authority_version`;
- exact evidence and release authorities.

A capability cannot be described as AA-ready merely because its scientific theory and tests are mature. Organisational continuity, metadata, use/applicability, external review and uncertainty evidence remain first-class gates where the governing criterion requires them.
