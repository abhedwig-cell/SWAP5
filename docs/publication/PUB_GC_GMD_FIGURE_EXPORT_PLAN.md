# PUB-GC GMD figure export plan

## Status

**EXPORT PLAN READY — PDF EXPORTS NOT YET FROZEN**

GMD final-production upload accepts PDF/PS/EPS/JPG/PNG/TIF/GIF figure files, not SVG as the submission figure format. The governed repository SVGs remain the scientific source.

| Figure | Governed source | GMD target |
| --- | --- | --- |
| F1 | `PUB_GC_F1_OWNERSHIP_AUTHORITY.svg` | `f01.pdf` |
| F2 | `PUB_GC_F2_TYPED_HYDROLOGICAL_INTERFACE.svg` | `f02.pdf` |
| F3 | `PUB_GC_F3_CLOSURE_VS_HEAD_CORRECTION.svg` | `f03.pdf` |
| F4 | `PUB_GC_F4_RESPONSE_IDENTITY.svg` | `f04.pdf` |
| F5 | `PUB_GC_F5_RESPONSE_INFORMATION_VALUE.svg` | `f05.pdf` |
| F6 | `PUB_GC_F6_COMPONENT_ADMISSION_ENVELOPE.svg` | `f06.pdf` |
| F7 | `PUB_GC_F7_REALISTIC_COMPONENT_DOMAIN_LIMIT.svg` | `f07.pdf` |

Final upload: one flat zip, no subfolders.

Validation after export:

- each figure <=5 MB;
- all labels and symbols remain legible;
- no clipping;
- no scientific content changes;
- F7 must continue to show a participant-domain stop, not imply a coupled Hupsel trajectory;
- total submitted files excluding supplements must remain <=30 MB.

Machine-readable companion: `PUB_GC_GMD_FIGURE_EXPORT_PLAN.json`.
