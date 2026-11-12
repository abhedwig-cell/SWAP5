# F-WOF-EXT01: Fortran comparison admission gap, executable contract mapping

**2026-10-17; research only; scientific comparison NOT YET DONE.**

## Existing production/test entrypoint

The candidate target for an exact first-day Fortran crop-only comparison is
`src/crop/mod_wofost81_one_day_candidate.f90` and the tested call in
`tests/fwof/pp02/test_wofost81_fullseason_replay.f90`.

The PP02 test driver fixes its own crop parameters in `configure_common`
and `configure_p81`. Its initial owner is hard-coded with DVS=0,
root biomass=36, live leaf biomass=24, SLA=.002 and no older leaf cohorts.
Those values belong to the original independent PP01/PP02 Spring Barley
qualification, **not automatically to NEW F-WOF-EXT01**.

## Precisely what is common already

- Both use WOFOST81 physiology and a bounded crop-only daily forcing idea.
- Both have a crop N state and N-unlimited comparison path.
- The independent PCSE research experiment has a pinned
  `Spring_barley_301` parameter YAML and a fully specified weather provider.
- A new Python reference artifact with state outputs and hashes exists.
- Existing Fortran PP02 can compile and replay its ORIGINAL barley fixture.

## Blocks to a valid NEW matched Fortran one-day test

1. **Parameter mapping.** Derive versioned SWAP5 common and WOFOST81 parameter
   bundles from the new *pinned* YAML, including lookup tables and CO2/N
   conventions. Do not silently use original PP02 hardcoded values because
   names or crop identity look similar.
2. **Meteorological mapping.** For the same Python date, derive typed
   `wofost_one_day_forcing_t` from the identical original weather input,
   preserving astronomy, temperature conversions, radiation units and time
   interpretation. Historical `forcing.dat` from PP02 belongs to a
   different weather experiment.
3. **Initial full owner.** Compare full Python crop initialization (leaf
   cohort ages, biomass, phenology, N pools, source information) to
   a valid Fortran owner. Do not initialize using 12 daily observations only.
4. **External water semantics.** New Python crop-only test supplies synthetic
   fixed daily TRA=0.15, TRAMX=0.30, RFTRA=0.5 cm/day and EVS=0; it is not
   SWAP5 accepted flux. Fortran accepts `actual_root_uptake` and
   `potential_transpiration` integrated over one accepted model-day.
   Date, duration and units must be reconciled; `RFTRA` cannot replace all
   oxygen/water stress semantics by fiat.
5. **N semantics.** Existing PP02 sets supplied soil-N equal to crop request;
   PCSE research uses `N_PotentialProduction`. Confirm same bounded N-demand,
   uptake maxima, fixation/translocation and N-stress before comparing 12 fields.
6. **Output timing.** PCSE daily output represents post-integration state +
   prospective rates, while PP02 output labels its INIT and subsequent
   POST states. Map transitions, not merely equal row labels.
7. **Acceptance.** Compare DVS, LAI, organ N amounts, NuptakeTotal, TAGP,
   TWLV/TWRT/TWST/TWSO against predefined, versioned tolerances. Do not
   re-use original PP01 tolerances automatically for a new external-water mode
   without a scoped science decision.

## Review result

The latest Python tests prove 30+30 day *same running Engine* continuation and
two independently initialized Engine repeatability, **not** persistence across
engine shutdown. The performance sample is three sequential simulations in
one subprocess and cannot establish large-scale SWAP-MODFLOW throughput.

**Verdict:** Fortran test-driver production is technically feasible by
composition of existing WOFOST81 modules, but the NEW barley equality
experiment is BLOCKED until exact inputs and owner mapping are implemented
and qualified. Original PP01/PP02 10-case equivalence remains valid and
scientifically distinct. Do not commit altered WOFOST process equations
or merge research to canonical to mask these gaps.
