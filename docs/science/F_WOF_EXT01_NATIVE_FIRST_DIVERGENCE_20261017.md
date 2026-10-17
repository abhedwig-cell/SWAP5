# F-WOF-EXT01 native differential triage: first real Python/Fortran result

Research date 2026-10-17. GitHub Actions successful run **39046941184**, input and O0/O2 native Fortran comparison. NO SCIENCE ADMISSION.

The Fortran O0 and O2 replay output files were byte-identical. The respective 60-transition Fortran kernels completed. Numeric differences relative to the separately published 61-row PCSE-WOFOST81 `Spring_barley_301` research trace are real, not build errors.

## Exact first divergences (local analysis of downloaded artifact ID 12105943441)

- Development stage DVS: exact on all 61 reference observations.
- LAI: first divergence on **row 21, 2010-05-06**, Python minus Fortran **0.0004639948884571643**. On this row biomass and crop N amounts still match.
- TAGP and organ biomass: first divergence on **row 22, 2010-05-07**; TAGP Python minus Fortran **0.0064008650550277935 kg/ha**.
- Crop N uptake: first divergence row 22, Python minus Fortran **0.0005004215258175293 kg N/ha**.
- Final row 61: Python TAGP 533.5071863311674, Fortran TAGP 360.35137145341423 kg/ha; N uptake 17.02901096975551 versus 12.095967225187444 kg N/ha; DVS both 0.927375.
- Global maximum |LAI difference| 0.25444462831059345 at row 59; |TAGP difference| 173.1558148777532 kg/ha at row 61.

## Mechanism under investigation

The **leaf structure / SLA / LAIEXP update** is the first evident fork. Inspect
`pcse/crop/leaf_dynamics.py` versus `src/crop/mod_wofost81_leaf_structural_evolution.f90` and `src/crop/mod_wofost81_rate_correction.f90`. The difference in carbon accumulation and N uptake appears one day later as a plausible downstream consequence of changed LAI and interception. No evidence yet isolates the exact leaf arithmetic cause. Do not adjust leaf physiology or tolerances merely to force a match.

## Critical qualification boundary

The driver is based on the previously qualified PP02 implementation with real extracted PCSE astronomy/meteorology and an experimental potential/actual ratio 0.5. The new research output is **not** the original PP01 case, not a same-run SWAP5 hydrology acceptance event, and not an exact state/restart qualification. Compare source semantics, mode flags, crop parameter bundle and leaf age processing before claiming scientific failure of either implementation.

## Required bounded next gate

Instrument daily *candidate* LAIEXP, leaf growth, SLAT, leaf-age cohort shifts and death on **rows 19 through 23** for both implementations; check one-day state/rate alignment. Once the first divergence is explained, rerun the same fixed-input O0/O2 comparison without changing the reference trace or loosening tolerance. No new broad CI is justified for this source-triage stage.
