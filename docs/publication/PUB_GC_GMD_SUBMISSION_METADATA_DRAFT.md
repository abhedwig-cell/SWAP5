# PUB-GC GMD submission metadata draft

## Status

**STRUCTURE_READY — VERSION / LICENCE / DOI / AUTHOR METADATA UNRESOLVED**

Date: 2026-09-18.

This file is a submission-form working record. Placeholders are intentional and must not be interpreted as repository authority.

## Journal and manuscript type

- Journal: **Geoscientific Model Development**
- Manuscript type: **Development and technical paper**
- Scientific state: E1–E7 closed/bounded
- E7 state: `CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT`

## Title

Working journal-neutral title:

> Hydrologically accountable finite-window coupling of independently time-integrating vadose-zone and groundwater models: SWAP5–MODFLOW6

GMD submission title template:

> **Hydrologically accountable finite-window coupling of SWAP5 (<<SWAP5_PUBLICATION_VERSION>>) and MODFLOW 6.8.0**

Do not resolve `<<SWAP5_PUBLICATION_VERSION>>` until archival blocker A1 is closed.

## Authors and affiliations

- Authors: `<<FINAL_AUTHOR_LIST>>`
- Affiliations: `<<FINAL_AFFILIATIONS>>`
- Corresponding author: `<<CORRESPONDING_AUTHOR>>`
- Corresponding email: `<<CORRESPONDING_EMAIL>>`

No names, affiliations or ordering are inferred from repository commits.

## Short summary

Current candidate, below the 500-character GMD limit:

> Vadose-zone and groundwater models often exchange water while keeping separate numerical solvers. We developed a coupling contract for SWAP5 and MODFLOW6 that separates trial calculations from accepted state and water balance. Controlled tests show reliable but weak feedback, while a realistic Hupsel case reaches a process-domain boundary before coupling, showing that component admissibility is part of the coupled-model problem.

Frozen working count in the journal-positioning record: **432 characters including spaces**. Recount after any change.

## Key figure

Primary candidate: **F1 — solver ownership, trial authority and publication boundary**.

Rationale: F1 communicates the general coupling contribution. F7 is a scientific result but should not make the paper appear to be primarily a failed Hupsel application.

## Keywords — working set

- vadose-zone–groundwater coupling
- SWAP5
- MODFLOW6
- partitioned coupling
- hydrological model interoperability
- transactional state
- mass conservation
- component admissibility

These are descriptors, not novelty claims.

## Abstract

Use the current result-bearing abstract from `PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md`.

Do not add a realistic Hupsel loose/strong correction magnitude; no such E7 coupled windows were executed.

## Author contributions

Complete after the author list is governed. Do not infer roles from Git history.

- Conceptualization: `<<NAMES>>`
- Methodology: `<<NAMES>>`
- Software: `<<NAMES>>`
- Validation: `<<NAMES>>`
- Formal analysis: `<<NAMES>>`
- Investigation: `<<NAMES>>`
- Data curation: `<<NAMES>>`
- Visualization: `<<NAMES>>`
- Writing – original draft: `<<NAMES>>`
- Writing – review & editing: `<<NAMES>>`
- Supervision: `<<NAMES>>`
- Project administration: `<<NAMES>>`
- Funding acquisition: `<<NAMES>>`

## Funding / acknowledgements / competing interests

- Funding: `<<FUNDING_STATEMENT>>`
- Acknowledgements: `<<ACKNOWLEDGEMENTS>>`
- Competing interests: `<<COMPETING_INTERESTS_STATEMENT>>`
- AI-tool-use disclosure, if required by the selected submission policy: `<<AI_TOOL_DISCLOSURE>>`

## Code and data availability

Use `PUB_GC_GMD_CODE_DATA_AVAILABILITY_TEMPLATE.md`.

Unresolved mandatory fields:

- `<<SWAP5_PUBLICATION_VERSION>>`
- `<<SWAP5_ARCHIVE_DOI_OR_PID>>`
- `<<SWAP5_LICENSE_AUTHORITY>>`
- `<<PUBLIC_REPRODUCTION_ARCHIVE_PID_IF_SEPARATE>>`

## Supplement

Current journal-neutral supplement: `PUB_GC_SUPPLEMENTARY_METHODS_AND_EVIDENCE.md`.

Figures F1–F7 and Tables T1–T6 are complete in the repository evidence package.

## Submission claims guard

The submission metadata must not imply:

- regional Hupsel groundwater validation;
- completed realistic Hupsel loose/strong coupled windows;
- a measured realistic E7 coupling correction;
- generic novelty for partitioned coupling, checkpoint/restore, Aitken/IQN, derivative exposure, MODFLOW API control or modularity;
- physical validity of heterogeneous N:1 aggregation.

## Completion gate

This metadata record becomes submission-ready only after:

1. A1 release/version authority closes;
2. A2 licence/redistribution authority closes;
3. A3 persistent archive/PID closes;
4. final author/affiliation/contribution metadata is supplied;
5. final GMD formatting and submission-policy check is completed.
