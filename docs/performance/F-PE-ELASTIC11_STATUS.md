# F-PE-ELASTIC11 — work-unit status

Date: 2026-09-29

WORKSTREAM:
F-PE / physical elastic-storage parameterization

WORK UNIT:
F-PE-ELASTIC11 — BHR-GT mechanical relation identification and independent holdout

BASELINE:
integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214

RECOVERY BRANCH:
work/f-pe-elastic01-soil-storage

RECOVERY POINT:
eb1ee6ff65de1cb588fed3950069ae735b68915c

SCOPE:
Identify a source-bound Dutch mechanical relation for skeleton specific storage
from BRO BHR-GT geotechnical settlement data without using MvG parameters,
SWAP runtime performance or holdout targets during model selection.

OWNED SURFACE:
- research/elastic/**
- docs/performance/F-PE-ELASTIC10*
- docs/performance/F-PE-ELASTIC11*
- research-only GitHub workflows for ELASTIC10/11

PRODUCTION SURFACE:
None.

INTERFACES CHANGED:
None.

INVARIANTS AFFECTED:
No production invariant changed. Physical versus numerical policy separation is
preserved.

IMPLEMENTATION STATUS:
- BHR-GT public schema/service acquisition: complete.
- frozen national 16-object mechanical corpus: complete.
- exact settlement-determination identity reconciliation: complete.
- 47 source-bound mechanical Ssk targets: complete.
- target-blind predictor corpus: complete.
- object-grouped calibration model selection: complete.
- frozen 8-object holdout evaluation: complete.

TEST / QUALIFICATION STATUS:
- ELASTIC10E-R1 target authority: 47 targets, qualified.
- ELASTIC11B predictor corpus: 47 rows, 16 objects, qualified.
- ELASTIC11C calibration-only model selection: qualified.
- selected model M5:
  log10(Ssk_cm_inv) =
  -5.213084677584852
  + 1.0383403589566573 * log10(water_content_pct)
  - log10(stress_midpoint_kpa).
- ELASTIC11D frozen holdout run 36534683481: PASS.
- holdout rows: 25; objects: 8.
- mean object MAE: 0.1379154881 log10.
- median object MAE: 0.1638016666 log10.
- maximum object MAE: 0.2306336583 log10.
- all 8/8 objects have MAE <= 0.50.
- mean object MAE improvement over frozen constant M0: 0.3376670451 log10.
- no post-holdout refitting.

QUALIFICATION STATUS:
Deep BHR-GT mechanical generalization is qualified within the frozen population.

QUALIFIED CLAIM:
Within the frozen deep BHR-GT mechanical population, inverse stress scaling plus
source-bound geotechnical specimen water content generalizes to held-out BRO
objects substantially better than a constant Ssk baseline.

NOT QUALIFIED:
- root-zone transfer;
- BOFEK/Staringreeks ELAS mapping;
- production ELAS default;
- substitution of SWAP volumetric theta for BHR-GT gravimetric water content;
- use of current SWAP pressure head as mechanical effective stress;
- peat/root-zone extrapolation;
- a causal water-content law.

DEPENDENCY SURFACE:
- docs/performance/F-PE-ELASTIC10E_R1_RESULT.md
- docs/performance/F-PE-ELASTIC11B_RESULT.md
- docs/performance/F-PE-ELASTIC11C_RESULT.md
- docs/performance/F-PE-ELASTIC11D_HOLDOUT_PREREGISTRATION.md
- docs/performance/F-PE-ELASTIC11D_RESULT.md
- research/elastic/evaluate_bhrgt_ssk_holdout.py
- qualified artifacts from runs 36532519843, 36533233002, 36533818344,
  and 36534683481.

EXTERNAL SEMANTIC AUTHORITIES:
- BRO BHR-GT current catalogue/service documentation;
- NEN-EN-ISO 17892-1 water-content definition;
- USGS WSP 2064 consolidation-to-specific-storage identity.

BLOCKER:
No blocker for mechanical identification.

Transfer to SWAP/root-zone is not yet identified because:
1. BHR-GT waterContent is geotechnical gravimetric water content referenced to
   dry solids, while SWAP theta is volumetric;
2. conversion requires a dry bulk density or equivalent mass/volume authority;
3. M5 is qualified only over mechanical stress midpoint log10 range
   [1.78718, 2.66514], approximately 61-463 kPa;
4. shallow/root-zone effective stress will often lie below that range;
5. Staringreeks-2018 hydraulic parameter files do not themselves supply dry
   bulk density or mechanical stress state.

NEXT SAFE STEP:
F-PE-ELASTIC12A — preregister and execute a target-free root-zone transfer
semantics audit.

It must:
- bind BHR-GT waterContent explicitly as gravimetric dry-mass water content;
- freeze the volumetric-to-gravimetric conversion requiring dry bulk density;
- quantify stress-domain mismatch before applying M5 to shallow soils;
- use source-bound BHR-P/HYDROFIT dryBulkDensity only where ASSIGNED;
- treat any root-zone Ssk values as transfer sensitivity/prior envelopes, not
  validation;
- not use SWAP runtime performance or the ELASTIC01 numerical screen as a
  physical fitting target.

RECOVERY:
Repository postimage is safe at
eb1ee6ff65de1cb588fed3950069ae735b68915c.
No expensive or hidden state exists outside persisted artifacts and documents.
