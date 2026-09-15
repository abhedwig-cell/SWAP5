# F-WOF-PP01 PCSE WOFOST 8.1 potential-production mapping contract

## Purpose

This document defines the test-only semantic bridge required before the independent PCSE 6.0.13 WOFOST 8.1 potential-production trajectories may be used as an oracle for SWAP5. It is not a new crop-physics contract and does not authorize production changes.

## Established direct mappings

The current canonical `wofost_rate_parameter_bundle_t` explicitly documents legacy WOFOST mnemonics for the following rate parameters. These can be mapped from the reference `ModelParameters` after unit/table-shape validation:

| PCSE/reference | SWAP5 rate parameter | Status |
|---|---|---|
| IDSL | development_daylength_mode | DIRECT |
| DLO | daylength_upper_hours | DIRECT when IDSL=1; intentionally inactive/canonicalized when IDSL=0 |
| DLC | daylength_lower_hours | DIRECT when IDSL=1; intentionally inactive/canonicalized when IDSL=0 |
| TSUM1 | vegetative_temperature_sum_required | SEMANTIC DIRECT; SWAP5 comment retains older mnemonic TSUMEA |
| TSUM2 | generative_temperature_sum_required | SEMANTIC DIRECT; SWAP5 comment retains older mnemonic TSUMAM |
| DTSMTB | temperature_sum_increment | DIRECT |
| TMPFTB | daytime_temperature_factor | DIRECT |
| TMNFTB | minimum_temperature_factor | DIRECT |
| RFSETB | maintenance_respiration_factor | DIRECT |
| FRTB | root_partition_fraction | DIRECT |
| FLTB | leaf_partition_fraction | DIRECT |
| FSTB | stem_partition_fraction | DIRECT |
| FOTB | storage_partition_fraction | DIRECT |
| RDRRTB | relative_root_death_rate | DIRECT |
| RDRSTB | relative_stem_death_rate | DIRECT |
| SLATB | specific_leaf_area | DIRECT |
| CVR | conversion_efficiency_root | DIRECT |
| CVS | conversion_efficiency_stem | DIRECT |
| CVL | conversion_efficiency_leaf | DIRECT |
| CVO | conversion_efficiency_storage | DIRECT |
| Q10 | respiration_temperature_q10 | DIRECT |
| RMR | maintenance_respiration_root | DIRECT |
| RML | maintenance_respiration_leaf | DIRECT |
| RMS | maintenance_respiration_stem | DIRECT |
| RMO | maintenance_respiration_storage | DIRECT |
| PERDL | maximum_leaf_relative_death_rate | DIRECT |
| TBASE | leaf_age_base_temperature | DIRECT |
| RGRLAI | maximum_relative_lai_growth_rate | DIRECT |

## Mappings that must be derived and independently checked

The reference uses WOFOST 8.1 parameterization that is not represented by a single identically named SWAP5 field. In particular, assimilation uses `AMAX_REF`, `AMAX_LNB`, `AMAX_SLP`, `EFFTB`, `KDIFTB`, `CO2EFFTB`, `CO2AMAXTB` and `CO2`, whereas the current SWAP5 restricted rate bundle consumes compact `AMAXTB`, scalar EFF/KDIF and daily CO2 factors. A test adapter may derive the daily/effective compact inputs only when the WOFOST 8.1 transformation is demonstrated from independent semantics. It must not invent a conversion from numerical coincidence.

Weather is similarly not a direct struct copy. PCSE reference weather contains IRRAD, TEMP/TMIN/TMAX and latitude/date, while `wofost_prepare_assimilation_forcing_t` requires TAVD, RAD, DAYL, SINLD, COSLD, DIFPP, DSINBE, FCO2EFF, FCO2AMAX and TMNR. DAYL/SINLD/COSLD/DIFPP/DSINBE and running minimum temperature therefore require the same astronomical/weather preprocessing semantics as the reference. No approximate replacement is admissible for the equivalence gate.

## Potential-production binding

`finalize_wofost_one_day_rates` applies `gass = prepared%actual_pgass * reltr`, where `reltr` is computed from accepted actual root uptake and potential transpiration. For the potential-production oracle the test-only accepted aggregates must establish exactly non-limiting water supply, i.e. `reltr = 1`, without changing production code. The PCSE fixture's constant external SM=0.3 and NAVAIL=100 are reference-side non-limiting states; they are not permission to bypass SWAP5 accepted-aggregate semantics.

## Output mapping

The following scientific outputs are presently observable from the SWAP5 crop-owner/biomass state or are straightforward derived totals once a complete daily driver exists:

| Reference output | SWAP5 observation | Status |
|---|---|---|
| DVS | development stage | DIRECT |
| LAI | derived actual leaf area index | DIRECT |
| TWRT | actual root biomass | DIRECT subject to unit check |
| TWST | actual stem biomass | DIRECT subject to unit check |
| TWSO | actual storage biomass | DIRECT subject to unit check |
| TWLV | living leaf biomass | DIRECT subject to PCSE TWLV definition/unit check |
| TAGP | TWLV + TWST + TWSO only if PCSE TAGP definition matches | DERIVED, definition check required |

The following oracle fields are not currently established as equivalent observations in the restricted standard WOFOST path and therefore remain BLOCKING for a claim that the complete YAML precision contract has passed: `RD`, `TRA`, `NamountLV`, `NamountRT`, `NamountSO`, `NamountST`, `NuptakeTotal`.

The absence of a current N-state observation is especially important: repository code search on the live canonical found no `Namount*`/`NuptakeTotal` implementation in the current restricted WOFOST crop path. These fields may not be silently omitted from a claim of full reference equivalence. A narrower carbon/phenology potential-production qualification may be defined later, but it must be explicitly named as narrower and must not be reported as full WOFOST 8.1 PP equivalence.

## Admission rule

F-WOF-PP01 is eligible for PASS only after all required input transformations, start/termination semantics, state initialization and output units have independent justification and all ten cases satisfy the immutable per-variable precision values. Until then the correct verdict is `BLOCKED_MAPPING_INCOMPLETE`.
