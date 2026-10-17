# F-WOF-EXT01: identified conditional GLAIEX semantic mismatch (2026-10-17)

**Research-only source finding, not yet experimentally established as the cause. No production edits or science admission.**

## Pinned source paths

* PCSE research branch `research/wofost81-external-day-probe-20261017`: `pcse/crop/leaf_dynamics.py`, class `WOFOST_Leaf_Dynamics_N.calc_rates`.
* SWAP5 research branch `research/f-wof-ext01-contract-feasibility-20261017`: `src/crop/mod_wofost_finalize_rates.f90` and `src/crop/mod_wofost81_rate_correction.f90`.

The PCSE N-enabled leaf model computes:
```python
if k.DVS < 0.2 and s.LAI < 0.75:
    factor = k.RFTRA * k.RFRGRL
else:
    factor = 1.
r.GLAIEX = s.LAIEXP * p.RGRLAI * DTEFF * factor
```
for `LAIEXP < 6`.

The SWAP5 Fortran common rate finalizer instead computes:
```fortran
glaiex = reltr * state_view%exponential_leaf_area_index * &
    scalars%maximum_relative_lai_growth_rate * dteff
```
for `LAIEXP < 6`, with no juvenile DVS/LAI condition. The subsequent WOFOST81 correction applies `rfrgrl` to this base rate only *inside* the juvenile condition. Accordingly, for the fixed research `RFTRA=0.5`, outside the juvenile condition PCSE's multiplier is 1 while Fortran's remains 0.5. Inside juvenile conditions the expected multipliers may match if `RFRGRL` and forcing semantics are identical.

## Falsifiable next test

On 2010-05-05, 2010-05-06 and 2010-05-07, print the **pre-rate** DVS, LAI, LAIEXP, RFRGRL, RFTRA, GRLV, GLAIEX, GLASOL, SLAT and **post-integrated** youngest SLA, leaf cohort vectors and LAI on each side. Specifically establish whether 2010-05-06 coincides with leaving `DVS<0.2 && LAI<0.75`, and whether `GLAIEX` or `SLAT` then separates first. Verify date-indexing from 61 observations versus 60 transitions. Run fixed reference O0/O2 again only after instrumenting a research-only driver and Python exporter. Do not edit admitted physiology or tolerances to force matching.

A source-level difference is **not** proof that it caused the observed first difference. There may also be unequal N-stress activation or other state/rate-timing semantics. Original PP01/PP02 preservation remains binding.
