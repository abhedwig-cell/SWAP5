# F-PE-ELASTIC10 — work-unit status

Date: 2026-09-29

WORKSTREAM:
F-PE / physical elastic-storage parameterization

WORK UNIT:
F-PE-ELASTIC10 — BRO BHR-GT mechanical target acquisition

BASELINE:
integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214

RECOVERY BRANCH:
work/f-pe-elastic01-soil-storage

RECOVERY POINT:
964c43d674622e796d5874ec81f67a23c46c0509

SCOPE:
Acquire independent Dutch geotechnical settlement/compression evidence suitable
for constraining legacy SWAP ELAS without fitting ELAS from hydraulic MvG
parameters or solver performance.

FILES / COMPONENTS TOUCHED:
- docs/performance/F-PE-ELASTIC10_BHR_GT_TARGET_PREREGISTRATION.md
- docs/performance/F-PE-ELASTIC10_PHASE_A_RESULT.md
- docs/performance/F-PE-ELASTIC10A_BHR_GT_SEMANTICS_PREAUDIT.md
- docs/performance/F-PE-ELASTIC10B_PILOT_PREREGISTRATION.md
- docs/performance/F-PE-ELASTIC10B_ATTEMPT1_RESULT.md
- docs/performance/F-PE-ELASTIC10B_ATTEMPT2_RESULT.md
- docs/performance/F-PE-ELASTIC10C_PILOT_PREREGISTRATION.md
- research/elastic/bro_bhrgt_fetch.py
- research/elastic/run_bhrgt_settlement_pilot.py
- research/elastic/run_bhrgt_settlement_pilot10.py
- .github/workflows/f-pe-elastic10-bhrgt.yml
- .github/workflows/f-pe-elastic10b-bhrgt-pilot.yml
- .github/workflows/f-pe-elastic10c-bhrgt-pilot.yml

INTERFACES CHANGED:
None. Research-only external evidence acquisition.

INVARIANTS AFFECTED:
None in production. Physical/numerical policy separation is preserved.

IMPLEMENTATION STATUS:
- Phase A BHR-GT service/schema acquisition: implemented and qualified.
- Public service base, OpenAPI, object/search endpoints and settlement semantics:
  source-bound.
- Phase B attempt 1: invalid discovery parse, explicitly rejected as evidence.
- Phase B attempt 2: valid 0.5-km and 5-km empty searches; 25-km request rejected
  by official service because radius > 10 km.
- ELASTIC10C: service-valid 10.0-km successor executed and closed as a valid
  local coverage negative; step-local R0-R3 classifier was not exercised because
  no objects were returned.

TEST STATUS:
- F-PE-ELASTIC10 Phase A run 36526529454: PASS.
- F-PE-ELASTIC10B attempt 1: INVALID_DISCOVERY_PARSE, not scientific evidence.
- F-PE-ELASTIC10B attempt 2 run 36528193825: service-contract evidence only.
- F-PE-ELASTIC10C run 36528898941: PASS; HTTP 200; zero BRO-IDs at 10 km.
  Result authority: F-PE-ELASTIC10C_RESULT.md.
- F-PE-ELASTIC10D run 36529870974: PASS; 86 unique grid BRO-IDs; fixed 16-object
  sample; 8 R3 + 8 R2 target-ready objects.
  Result authority: F-PE-ELASTIC10D_RESULT.md.

QUALIFICATION STATUS:
- Phase A: qualified.
- Fixed local mechanical-target coverage at the official example center through
  the service-valid maximum 10-km radius: qualified negative.
- National fixed-grid mechanical-target availability: qualified positive.
- F-PE-ELASTIC10D found 86 unique settlement registrations across the frozen
  12-cell grid and selected 16/16 target-ready objects (8 R3, 8 R2).
- No ELAS target value, prior mapping or pedotransfer relation admitted.

DEPENDENCY SURFACE:
- docs/performance/F-PE-ELASTIC10D_NATIONAL_GRID_PREREGISTRATION.md
- docs/performance/F-PE-ELASTIC10D_RESULT.md
- research/elastic/run_bhrgt_national_grid_pilot.py
- research/elastic/run_bhrgt_settlement_pilot10.py
- research/elastic/bro_bhrgt_fetch.py
- .github/workflows/f-pe-elastic10d-bhrgt-grid.yml
- official BHR-GT v2 public service contract

BLOCKER:
None for target availability. The fixed national grid contains multiple
source-bound R2/R3 mechanical targets.

NEXT SAFE STEP:
Preregister a separate mechanical-target extraction workunit on the frozen
16-object ELASTIC10D sample. Before calculating any compressibility, bind the
SWE record-column semantics and units for HeightAtSpecificState.xml and
StressAtSpecificSettlement.xml. Then freeze conversion rules for R2
unload/reload and R3 effective-stress targets.

PROHIBITED UNTIL TARGET-EXTRACTION PREREGISTRATION:
- calculating m_v, S_s or ELAS from the object series;
- changing the frozen 16-object sample;
- fitting a pedotransfer relation;
- using solver performance as target evidence.
