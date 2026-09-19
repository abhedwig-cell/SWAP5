# PUB-GC GMD figure export plan

## Status

**EXPORT PIPELINE QUALIFIED — FINAL RELEASE-BOUND PDF HASHES PENDING R1/L1/ARCHIVE**

Date: 2026-09-19.

Repository SVGs remain the governed scientific source. For GMD, export F1–F7 as separate numbered vector PDFs where possible.

| Figure | Governed source | Target |
| --- | --- | --- |
| F1 | `PUB_GC_F1_OWNERSHIP_AUTHORITY.svg` | `f01.pdf` |
| F2 | `PUB_GC_F2_TYPED_HYDROLOGICAL_INTERFACE.svg` | `f02.pdf` |
| F3 | `PUB_GC_F3_CLOSURE_VS_HEAD_CORRECTION.svg` | `f03.pdf` |
| F4 | `PUB_GC_F4_RESPONSE_IDENTITY.svg` | `f04.pdf` |
| F5 | `PUB_GC_F5_RESPONSE_INFORMATION_VALUE.svg` | `f05.pdf` |
| F6 | `PUB_GC_F6_COMPONENT_ADMISSION_ENVELOPE.svg` | `f06.pdf` |
| F7 | `PUB_GC_F7_REALISTIC_COMPONENT_DOMAIN_LIMIT.svg` | `f07.pdf` |

Submission archive: one flat zip with no subfolders.

Validation:

- preferred PDF vector output with embedded fonts;
- each PDF <=2 MB;
- non-PDF figures, if needed, <=5 MB;
- overall non-supplement submission <=30 MB;
- no clipping or scientific-content changes;
- F7 must remain a participant-domain stop with zero E7 coupled windows.

Machine-readable companion: `PUB_GC_GMD_FIGURE_EXPORT_PLAN.json`.


## Qualification result

Reproducible export route qualification:

- workflow run: **35425367690** — SUCCESS;
- fonts embedded: PASS;
- each PDF <=2 MB: PASS;
- flat zip `f01.pdf`–`f07.pdf`: PASS;
- total seven-PDF bytes: **164,666**;
- qualification record: `PUB_GC_GMD_FIGURE_EXPORT_QUALIFICATION.md` / `.json`.

The final paper-release PDFs must be regenerated from the immutable publication release after R1/L1/archive identity is resolved.
