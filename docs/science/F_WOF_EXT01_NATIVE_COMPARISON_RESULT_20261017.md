# F-WOF-EXT01 native Python/Fortran research comparison (2026-10-17)

## Executed run

- Workflow: https://github.com/abhedwig-cell/SWAP5/actions/runs/39046941184
- Research branch: `research/f-wof-ext01-contract-feasibility-20261017`
- GitHub Actions conclusion: SUCCESS (execution and byte identity), **scientific equivalence FAIL / not admitted**.
- Artifact: `ext01-research-native-fortran-comparison` (id 12105943441). The artifact includes Python input/reference CSV and O0/O2 native CSV and difference JSON.
- Actual SWAP5 source compiled in one GitHub runner with actual PCSE research branch. Fortran 60 daily transitions, 61 observations, all twelve crop-owned fields.
- O0 and O2 native CSVs are **byte-identical**; compiler optimization is not the divergence source.

## Scientific comparison: observed, not presumed

| Field | Largest absolute Python/Fortran discrepancy |
| --- | ---: |
| DVS | 0 (identical through 61 observations) |
| LAI | 0.25444462831059345 |
| TAGP | 173.1558148777532 kg/ha |
| TWLV | 85.59775451366991 kg/ha |
| TWRT | 66.32674698643146 kg/ha |
| TWST | 87.55806036408325 kg/ha |
| NamountLV | 2.213942572215511 kg N/ha |
| NamountRT | 1.0763808239372779 kg N/ha |
| NamountST | 1.2111318860946723 kg N/ha |
| NuptakeTotal | 4.933043744568067 kg N/ha |
| TWSO / NamountSO | 0 (both zero in this selected window) |

The initial state and the first 20 LAI observations agree (within 1e-12 absolute).
The **first observed numerical divergence is LAI at observation 21**, -0.0004639948884571643 (native minus Python). **TWLV, TWRT, TAGP, organ N first diverge at observation 22**; TWST diverges at observation 28. Development stage DVS remains identical.

This suggests inspecting leaf structural evolution/cohort ageing and prospective-rate timing *first*, not preemptively rewriting assimilation, root or N science. It is NOT a confirmed causal diagnosis.

## Authority and source constraints

- Python research fixture: pinned Spring_barley_301, native PCSE meteorology, PCSE astro, synthetic constant TRA/TRAMX/RFTRA 0.15/0.30/0.5 cm/d, external EVS=0, potential soil N.
- Fortran research driver: existing `tests/fwof/pp02/test_wofost81_fullseason_replay.f90` reused with **only** test-local uptake ratio adjusted from 1 to 0.5; existing process equations untouched. Input line derived from matched Python weather and astronomy.
- Prior parameter preflight compared 31 values/tables successfully. Exact equality of all hidden process/state semantics is still unproven.
- Existing PP01/PP02 ten-case historical scientifically qualified results are unaffected; this is a **NEW** research scenario and does not supersede them.
- The successful workflow proves successful native Fortran execution and O0/O2 identity, *not* Python/Fortran crop equivalence.

## Next cohesive research action

Inspect and compare the one-day internal leaf cohort, leaf age, specific leaf area, structural rate inputs, and PCSE post-integration-vs-prospective-rate timing at observations 19-23. Instrument **test-only** per-day diagnostics on both sides and reproduce the first difference. Fix interface/forcing/state mapping if evidenced; do not weaken tolerances or edit admitted WOFOST production formulas to force a pass.

Separately, full PCSE internal checkpoint serialization is still open: process-loss recovery by replay passed, but plain full-engine pickle failed.

**Verdict: CONDITIONAL GO for investigating replaceable crop backends. NO PRODUCTION ADMISSION.**
