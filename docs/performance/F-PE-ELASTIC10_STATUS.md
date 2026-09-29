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
4d23a9e39e4d3b9b2c9261693aa0d27cbbdab8e5

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
- ELASTIC10C: service-valid successor implemented with exactly 10.0-km search,
  step-local settlement evidence and conservative R0-R3 classifier.

TEST STATUS:
- F-PE-ELASTIC10 Phase A run 36526529454: PASS.
- F-PE-ELASTIC10B attempt 1: INVALID_DISCOVERY_PARSE, not scientific evidence.
- F-PE-ELASTIC10B attempt 2 run 36528193825: service-contract evidence only.
- F-PE-ELASTIC10C run 36528898941: queued; not yet tested.

QUALIFICATION STATUS:
- Phase A: qualified.
- Mechanical target population/object coverage: not yet qualified.
- No ELAS target value, prior mapping or pedotransfer relation admitted.

DEPENDENCY SURFACE:
- research/elastic/run_bhrgt_settlement_pilot10.py
- research/elastic/bro_bhrgt_fetch.py
- docs/performance/F-PE-ELASTIC10C_PILOT_PREREGISTRATION.md
- .github/workflows/f-pe-elastic10c-bhrgt-pilot.yml
- official BHR-GT v2 public service contract

BLOCKER:
GitHub Actions runner capacity. F-PE-ELASTIC10C run 36528898941 remains queued.
No scientific or implementation blocker is known.

NEXT SAFE STEP:
Wait for run 36528898941 to execute. Then:
1. read its log and artifact;
2. record the 10-km search result;
3. if objects exist, record the fixed first-five object set and per-determination
   R0/R1/R2/R3 classes;
4. if at least one R2/R3 exists, preregister a target-extraction/corpus workunit;
5. if zero objects or R0/R1-only, record the bounded negative result without
   geographic expansion.

PROHIBITED UNTIL THAT RESULT:
- expanding beyond 10 km;
- hand-selecting objects;
- changing readiness thresholds;
- calculating production ELAS;
- fitting a pedotransfer relation;
- using solver performance as target evidence.
