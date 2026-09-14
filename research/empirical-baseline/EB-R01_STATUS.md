# EB-R01 status: restricted forcing and reference-ET observation

Decision: **CLOSED_EMPIRICAL_OBSERVATION_SLICE**

This status closes only EB-R01 inside the continuing `research/swap431-empirical-baseline` capability.

## Evidence identity

- observation implementation head: `8a3327ffe24d2cd2671b9ce9026e1f44895f6430`
- pinned canonical start: `d44b2eb48e7187f8ddc622a5f2329d7a24c24aa0`
- inherited F-PM06A candidate head: `23206aaf996ffb7dde355508fa2379a5efbd3d57`
- observed process blob: `f5e88ec5089fd3b57ac111065fab2aa32dde0fae`
- GitHub Actions run: `34868440722`
- workflow job: `104058063273`
- observation SHA-256: `58353687ab86f6320c8c14ea9c44ddffba29dda187910adb06d7574bc7ec1436`

## Results

All required gates passed:

- pinned canonical start: PASS
- exact inherited F-PM06A process-module identity: PASS
- `-O0` versus `-O2` observation identity: PASS
- independent numerical anchor falsification: PASS

Observed outputs are in cm/day:

| case | ETref mm/day | emerged | cover | crop factor | CO2 factor | pond factor | PTRA | PEVA | EPOND |
| --- | ---: | :---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| zero_forcing_bare | 0.0 | no | 0.00 | 0.0 | 1.0 | 1.2 | 0.0 | 0.0 | 0.0 |
| bare_5p2 | 5.2 | no | 0.00 | 0.0 | 1.0 | 1.2 | 0.0 | 0.52 | 0.624 |
| inactive_cover_0p30 | 5.2 | no | 0.30 | 7.0 | 8.0 | 1.2 | 0.0 | 0.364 | 0.4368 |
| active_cover_0p25 | 4.0 | yes | 0.25 | 1.0 | 1.0 | 1.0 | 0.1 | 0.3 | 0.3 |
| active_reference | 5.2 | yes | 0.65 | 1.1 | 0.9 | 1.2 | 0.33462 | 0.182 | 0.2184 |
| active_full_cover | 5.2 | yes | 1.00 | 1.1 | 0.9 | 1.2 | 0.5148 | 0.0 | 0.0 |
| active_half_variable | 2.3 | yes | 0.50 | 1.4 | 0.8 | 0.7 | 0.1288 | 0.115 | 0.0805 |
| active_no_pond | 5.2 | yes | 0.50 | 1.0 | 1.0 | 0.0 | 0.26 | 0.26 | 0.0 |

The run also confirms the legacy restricted-route semantics already encoded by F-PM06A: non-emerged crop-specific factors are not consumed for transpiration, while the vegetation-cover view still partitions the surface evaporation demand.

## Evidence inheritance

The closeout commit adds only this status record. The run remains valid for EB-R01 while all of these dependencies remain unchanged:

- `src/process/mod_reference_et_demand_process.f90` blob `f5e88ec5089fd3b57ac111065fab2aa32dde0fae`;
- `tests/empirical_baseline/observe_restricted_reference_et.f90` from observation head `8a3327ffe24d2cd2671b9ce9026e1f44895f6430`;
- the interpretation boundary `SWETR=1`, `SWMETDETAIL=0`, `SWCFBS=0`, `SWINTER=0`.

A change to one of those dependencies requires re-observation. A documentation-only or unrelated production change does not invalidate this immutable evidence.

## Hard nonclaims

EB-R01 does not claim:

- a complete meteorological-forcing baseline;
- equivalence to running the complete supplied SWAP 4.3.1 binary distribution;
- coverage of other ET or meteorological option routes;
- soil-water, boundary-condition, drainage, solute, crop/LAI or output equivalence;
- any new SWAP5 production or scientific qualification.

## Next empirical slice

Continue on the same capability branch with the forcing layer upstream of this restricted ET demand surface. The next target is to observe how legacy/reference forcing values are acquired, transformed and presented to ET processing before expanding to the remaining baseline domains.
