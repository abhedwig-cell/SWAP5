# MC-NUT01 B1.11 eight-pool original organic parameter profile — admission receipt

2026-10-17. Source authority: `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`; original `SWAP/wofost_soil_parameters.f90`, SHA256 `4b91311612182ea3fc977051a3d52243957e32cbdbef413ab94b7cf8905f5f7a`, source lines 18–61. No historical reimplementation of WOFOST81 crop growth.

Work unit: MC-NUT01 original FOM/Bio/Hum reaction-parameter profile. Baseline: `dcda2dded1ecd6bed9d29d09c9b4025ba5785579`. Qualification code head: `370f5e8db6eb7f3124cd6fb42ac9b497bb30cbf6`; PR #1283.

## Implemented scope
Source-backed eight FOM rate constants: pools 1–4 at 3/year, 5–8 at 0.3/year with year 365.2425 days; Bio 0.66/year, Hum 0.02/year. Eight organic assimilation splits: AsfaMin=.04 at pools 1,2,5,6 and AsfaMax=.28 at pools 3,4,7,8, each partitioned .46 to Bio and .54 to Hum. Bio=.46*.2 and Hum=.54*.2. Carbon FOM=.45, Bio/Hum=.58. N fraction FOM alternates .06/.002 for all eight, Bio=.58/10, Hum=.58/14.

Existing reactive owner, calendar, Richardson/Full Richards carrier and transaction/restart ownership preserved. Named input path now binds this source profile before atomic project parameter initialization. The typed parameter-template route remains independently available for tests and explicit profiles. No change to solver, weather, hydro model, N physics formulas, rollback/restart codec, whole-N thresholds or WOFOST81 growth contract.

## Proof and dependency selection
Actual GitHub run [39039132451](https://github.com/abhedwig-cell/SWAP5/actions/runs/39039132451) on candidate code head `370f5e8db6eb7f3124cd6fb42ac9b497bb30cbf6`: completed SUCCESS, native historical activation two O0/O2 PASS, and actual Richards/reactive N integration two O0/O2 PASS. Artifact `12103338465` (31989314 bytes). Explicit assertions bind original eight rates, assimilation and N/C fractions through source production routine and actual runtime, plus existing whole-N budget, water rollback and native restart.

Full moving F-CI and unrelated long low-air/performance not selected: modified input-only bounded original organic coefficients and N initialization, not water solver/coupling/transaction semantics; actual owner Richards and restart test was executed. This evidence qualifies source parameter translation in the tested domain only, not complete SWAP4.3.1 equivalence.

## Still open
Original TTUTIL and full unified `.snm` project parser and cross-checked project fixture; complete atmospheric/top-boundary concentration transport ownership, crop residue apparent ages and crop lifecycle coupling, other historical extended rate switches, and nine broad MC-NUT01 mastercoverage rows. No broad capability promotion. This receipt is evidence record, not a separate scientific approval for untested original source envelopes.
