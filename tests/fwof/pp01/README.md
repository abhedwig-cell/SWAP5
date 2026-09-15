# F-WOF-PP01 independent potential-production oracle

F-WOF-PP01 qualifies the SWAP5 Fortran WOFOST path against ten immutable potential-production reference cases generated independently with PCSE 6.0.13 / WOFOST 8.1.

The source artifact is `tests_Wofost81_PP.zip`, SHA-256 `99a67a0e5f6bd0881b97950a2ff3fe0f387c0a9e0553f2e36197077fbc15d145`. Per-file hashes and reference tolerances are recorded in `REFERENCE_MANIFEST.json`; tolerances must not be relaxed by SWAP5.

## Qualification boundary

The current restricted crop owner directly exposes carbon/phenology observables DVS, LAI, TWLV, TWRT, TWST and TWSO; TAGP is derived as TWLV + TWST + TWSO. These form PP01A once WOFOST-8.1 parameter and weather preprocessing equivalence is proven.

RD, TRA and the five nitrogen outputs are not silently dropped. They are outside the current crop-owner output contract and can only enter a later extension after independent owner, unit and semantic binding. Missing outputs never count as passing comparisons.

Potential-production water forcing is represented test-only by equal accepted actual root uptake and potential transpiration, so the already-qualified relative-transpiration calculation returns one. This does not modify production physics.

## Fail-closed rules

No production source is changed to match the oracle. No tolerance is invented. No PCSE reference is regenerated from SWAP5. Any ambiguous WOFOST-8.1-to-current parameter transform or weather/astronomy transform blocks numerical qualification until demonstrated equivalent.
