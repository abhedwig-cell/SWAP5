# F-DOC01 Status A/AA authority

## Decision

F-DOC01 distinguishes **formal authority** from **publicly inspectable reference text**.

| Role | Pinned authority | Status |
|---|---|---|
| Current WUR quality process | Wageningen Research, `Quality of Models and Databases The Statutory Research Tasks Unit for Nature & the Environment`, current support page | VERIFIED_CURRENT_PROCESS_SOURCE |
| Formal project criterion authority | `Revised checklist Status A/AA, 2024`, Wageningen Research | PINNED_BY_CURRENT_WUR_REPORT_BUT_CONTROLLED_COPY_REQUIRED |
| Public inspectable requirement baseline | Wageningen University & Research, `A checklist for the Quality of Models, Datasets and Indicators to be used in policy and decision support` | VERIFIED_PUBLIC_REFERENCE_BASELINE |
| Historical context | Houweling et al. (2015), `Quality of models for policy support`, WOt-paper 38 | HISTORICAL_CONTEXT_ONLY |

Retrieval date for all web authorities in this workunit: **2026-09-11**.

## Source pins

### WR-QA-PROCESS-CURRENT

- issuing organisation: Wageningen Research, WOT Nature & Environment;
- title: `Quality of Models and Databases The Statutory Research Tasks Unit for Nature & the Environment`;
- URL: `https://support.wur.nl/esc/en/wageningen-research-research-funding/quality-of-models-and-databases-the?id=kb_article&sysparm_article=KB0017434`;
- observed statements: assessment protocol of 22 requirements; Status A is the baseline quality level; Status AA contains Status A plus additional requirements; audit and re-audit are part of the quality process;
- authority use: current process-level interpretation, not replacement for the detailed criterion text.

### WR-QA-2024

- issuing organisation: Wageningen Research;
- title/version as cited by WUR: `Revised checklist Status A/AA, 2024`;
- direct controlled publication/URL: **not obtained during F-DOC01**;
- provenance pin: Bulens, J., Heuer, H., Jagtman, D., Kumar, P., van Leeuwen, S. & Urdu, D. (2025), `Towards digital knowledge management at Wageningen University & Research`, Wageningen Environmental Research Report 3421, DOI `10.18174/689500`, which labels its Status A/AA description `[Source: Revised checklist Status A/AA, 2024]`;
- authority use: this is the formal project criterion authority that must be obtained as a controlled copy before an A/AA compliance decision;
- access state: `CONTROLLED_COPY_REQUIRED`;
- unresolved item: exact 2024 requirement wording and any changes relative to the public 22-requirement checklist are not independently established here.

### WR-QA-PUBLIC-22

- issuing organisation: Wageningen University & Research;
- title: `A checklist for the Quality of Models, Datasets and Indicators to be used in policy and decision support`;
- publication URL: `https://assets.foleon.com/eu-west-2/uploads-7e3kk3/20634/wrqualitycriteriamodelsdatasets_2.d65c4f6abfac.pdf`;
- WUR publication route: `https://magazines.wur.nl/kb-magazine-2023-en/a-quality-checklist`;
- explicit structure: 2 quality levels, 22 requirements, 7 themes, 3 perspectives;
- exact public numbering: `1.1`, `1.2`, `2.1`, `2.2`, `2.3`, `3.1`, `3.2`, `3.3`, `3.4`, `4.1`, `4.2`, `4.3`, `4.4`, `4.5`, `5.1`, `5.2`, `6.1`, `6.2`, `6.3`, `6.4`, `7.1`, `7.2`;
- authority use: public architecture baseline and requirement identifiers pending reconciliation against WR-QA-2024;
- version/date printed in checklist: no explicit revision identifier established by F-DOC01. Association with the 2023 WUR magazine does **not** turn the checklist into a presumed `2023 version`.

## Public requirement headings

The public baseline uses these headings. Detailed normative criterion prose remains external and is not duplicated in this repository.

| ID | Perspective/theme | Requirement heading |
|---|---|---|
| 1.1 | ST.1 | General model/dataset description |
| 1.2 | ST.1 | Conceptual and formal model documented |
| 2.1 | ST.2 | Implementation documented |
| 2.2 | ST.2 | Technical environment documented |
| 2.3 | ST.2 | Model/dataset tested |
| 3.1 | ST.3 | Parameters and variables documented |
| 3.2 | ST.3 | Calibration described |
| 3.3 | ST.3 | Input and output described |
| 3.4 | ST.3 | Origin of input data described |
| 4.1 | ST.4 | Sensitivity analysis performed |
| 4.2 | ST.4 | Uncertainty analysis performed |
| 4.3 | ST.4 | Model/dataset validated |
| 4.4 | ST.4 | Use monitored |
| 4.5 | ST.4 | General quality assessment |
| 5.1 | DO.5 | Development plan |
| 5.2 | DO.5 | Version control system |
| 6.1 | DO.6 | Metadata available |
| 6.2 | DO.6 | Management plan |
| 6.3 | DO.6 | Dependencies discussed |
| 6.4 | DO.6 | External use formalised |
| 7.1 | IU.7 | Interpretation guidance |
| 7.2 | IU.7 | User manual |

## Status A and AA interpretation

The current WUR process page characterises Status A as the baseline quality level and Status AA as Status A plus additional requirements. The public checklist gives a criterion-specific A baseline and AA additions. F-DOC01 may use those public additions to design an AA-ready architecture, but **not** to certify that the public text is identical to the revised 2024 authority.

The 2025 WUR report adds current institutional context: model impact classes drive self-assessment, Status A audit or Status AA audit, and Status A/AA is described as a WUR quality-certification method. That strengthens the rule that repository self-assessment is not certification.

## Authority gate

Before any future result named `STATUS_A_COMPLIANT`, `STATUS_AA_COMPLIANT`, `SWAP5_HAS_STATUS_A`, or `STATUS_A_QUALIFIED` is valid, all of the following must hold:

1. a controlled copy of WR-QA-2024, or a later formally designated replacement, is obtained;
2. title, issuer, version/date, source location and complete requirement numbering are pinned;
3. differences from WR-QA-PUBLIC-22 are recorded without silent merging;
4. the machine-readable matrices are updated to the controlled normative text;
5. applicable evidence is audited through the competent WUR procedure;
6. the resulting audit/re-audit authority is pinned to the exact SWAP5 release.

Until then the maximum internal state is `READY_FOR_STATUS_A_REVIEW`, never external compliance.

## Change-control rule

External quality criteria are versioned dependencies. A new WUR checklist does not silently overwrite prior audit meaning. A criterion-authority change requires a documented delta, migration of requirement mappings, impact assessment on existing evidence and explicit acceptance before it becomes the active SWAP5 documentation authority.
