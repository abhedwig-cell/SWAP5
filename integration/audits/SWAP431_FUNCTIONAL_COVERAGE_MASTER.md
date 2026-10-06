# SWAP431 functional coverage master: recoverable review

Baseline: `e5eab995ef04fc813dd644025fb0f32e4f5050a1`. Status: IN_PROGRESS. **Coverage is not closed; the denominator is not yet declared exhaustive.**

The ledger currently contains 212 entries: 77 bounded ADMITTED, 11 SUPERSEDED, 1 REJECTED, 16 NOT_APPLICABLE and 107 ACTIVE_MIGRATION entries across 19 review/migration workunits.

Only 38 entries are currently marked as proven missing production implementation/binding. The other 69 are unresolved source/admission/replacement reviews. Neither number is a final exhaustive missing-functionality count. Review registration is not implementation or admission.

The machine authority is `integration/audits/SWAP431_FUNCTIONAL_COVERAGE_MASTER.json`.
The exact source bundle and input-reader census are in `integration/audits/evidence/`.
The source findings and exclusion reasoning are in `SWAP431_SOURCE_REVIEW.md`.

## Confirmed production gaps traced so far

| Capability | Meaning | Workunit | Dependencies |
|---|---|---|---|
| SW431-HYD-LINEAR-TABLE | Explicit piecewise linear hydraulic input tables | MC-HYD01 | None |
| SW431-IRR-TCS7 | Pressure-head sensor trigger | MC-IRR01 | None |
| SW431-HYD-MODEL10 | Bimodal PDI capillary, adsorption and film-flow relations | MC-HYD01 | None |
| SW431-HYD-MODEL11 | Bimodal PDI normalized at finite dry-end head | MC-HYD01 | None |
| SW431-HYD-MODEL12 | RIA hydraulic relations | MC-HYD01 | None |
| SW431-HYD-MODEL2 | Exponential test hydraulic relations | MC-HYD01 | None |
| SW431-HYD-MODEL3 | Bimodal Mualem-Van Genuchten | MC-HYD01 | None |
| SW431-HYD-MODEL5 | Unimodal Mualem-Van Genuchten normalized at finite dry-end head | MC-HYD01 | None |
| SW431-HYD-MODEL6 | Unscaled bimodal Mualem-Van Genuchten relations | MC-HYD01 | None |
| SW431-HYD-MODEL7 | Bimodal Mualem-Van Genuchten normalized at finite dry-end head | MC-HYD01 | None |
| SW431-HYD-MODEL8 | Unimodal PDI capillary, adsorption and film-flow relations | MC-HYD01 | None |
| SW431-HYD-MODEL9 | Unimodal PDI normalized at finite dry-end head | MC-HYD01 | None |
| SW431-HYD-POWER | Conductivity power-tail extension | MC-HYD01 | None |
| SW431-HYD-TABLE | User-provided hydraulic relation tables | MC-HYD01 | None |
| SW431-ROOT-OXYGEN-EMP | Empirical anaerobic/Feddes wet stress | MC-ROOT01 | None |
| SW431-IRR-SSDI | Single-node or depth-interval subsurface drip irrigation | MC-IRR01 | SW431-IRR-TCS1 |
| SW431-FROST-DIVDRA | Trial-start signed spatial redistribution with frost | PPA-WU05B19 | SW431-FROST-HYD |
| SW431-HYD-RIA-VAPOR | RIA vapour/temperature-dependent conductivity and fitted dry-end relation | MC-HYD01 | SW431-HYD-MODEL12 |
| SW431-HYD-VAPOR | PDI vapour contribution to unsaturated conductivity | MC-HYD01 | SW431-HYD-MODEL8, SW431-HYD-MODEL9, SW431-HYD-MODEL10, SW431-HYD-MODEL11 |
| SW431-HYST1 | Scanning retention history with initial wetting branch | MC-HYST01 | SW431-HYD-MVG |
| SW431-HYST2 | Scanning retention history with initial drying branch | MC-HYST01 | SW431-HYD-MVG |
| SW431-ROOT-MICRO2 | de Jong van Lier microscopic soil-root hydraulic extraction | MC-MICRO01 | SW431-HYD-MVG |
| SW431-ROOT-MICRO3 | de Willigen microscopic soil-root hydraulic extraction | MC-MICRO01 | SW431-HYD-MVG |
| SW431-RUNOFF-NONLINEAR | Nonlinear surface-runoff power law and iterative ponding solution | MC-SUR01 | SW431-PONDING |
| SW431-RUNON | Externally supplied lateral water entering soil surface | MC-SUR01 | SW431-PONDING |
| SW431-TEMP-ANALYTIC | Analytical harmonic soil temperature | MC-HEAT01 | SW431-TEMP-SENSIBLE |
| SW431-TEMP-BC3 | Specified thermal flux boundary | MC-HEAT01 | SW431-TEMP-SENSIBLE |
| SW431-TEMP-BC4 | Surface temperature with heat-flux correction | MC-HEAT01 | SW431-TEMP-SENSIBLE |
| SW431-TEMP-BOTTOM2 | Prescribed bottom temperature | MC-HEAT01 | SW431-TEMP-SENSIBLE |
| SW431-TEMP-SNOW | Snow thermal resistance coupled to sensible heat | MC-HEAT01 | SW431-TEMP-SENSIBLE |
| SW431-TILL-CONSOL | Post-tillage consolidation history | MC-TILL01 | SW431-HYD-MVG |
| SW431-TILL-EVENT | Tillage events modifying density and hydraulic relations | MC-TILL01 | SW431-HYD-MVG |
| SW431-TILL-REDIST | Water redistribution after changing soil geometry/density | MC-TILL01 | SW431-HYD-MVG |
| SW431-AGE-TRACER | Water age tracer with ageing and advective/dispersive transport | MC-SOL01 | SW431-SALT-TRANSPORT |
| SW431-SALT-AQUIFER | Mixed aquifer concentration with storage, sorption, decay and surface-water breakthrough | MC-SOL01 | SW431-SALT-TRANSPORT |
| SW431-SALT-DECAY | Temperature/moisture/depth modified decomposition | MC-SOL01 | SW431-SALT-TRANSPORT |
| SW431-SALT-POND | Ponded solute storage and rain/irrigation/dissolved runoff exchange | MC-SOL01 | SW431-SALT-TRANSPORT |
| SW431-SALT-SORPTION | Freundlich nonlinear sorption/storage | MC-SOL01 | SW431-SALT-TRANSPORT |

## Registered review queue

These are individual capability decisions, not admitted implementation plans. Dependency depth orders prerequisites first; independent qualification reviews can reduce the queue before new physics work.

| Workunit | Open entries | Next action |
|---|---:|---|
| MC-HYD01 | 15 | Source/admission adjudication for the exact IDs below |
| MC-IRR01 | 13 | Source/admission adjudication for the exact IDs below |
| MC-LOW01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-MACRO01 | 7 | Source/admission adjudication for the exact IDs below |
| MC-MET01 | 7 | Source/admission adjudication for the exact IDs below |
| MC-ROOT01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-CROP01 | 11 | Source/admission adjudication for the exact IDs below |
| MC-DRAIN01 | 4 | Source/admission adjudication for the exact IDs below |
| MC-FROST01 | 4 | Source/admission adjudication for the exact IDs below |
| MC-HEAT01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-HYST01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-MACROSUR01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-MICRO01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-NUT01 | 9 | Source/admission adjudication for the exact IDs below |
| MC-SOL01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-SUR01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-SW01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-TILL01 | 3 | Source/admission adjudication for the exact IDs below |
| PPA-WU05B19 | 1 | Source/admission adjudication for the exact IDs below |

### MC-CROP01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-CROP-ATTAINABLE | Attainable versus theoretical potential growth correction | RELFMF parameter and selector not established by ten-case crop-equivalence denominator | SW431-CROP-WOF81 |
| SW431-CROP-CO2 | Time-varying CO2 crop response and forcing | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | SW431-CROP-WOF81 |
| SW431-CROP-FIXED | Prescribed crop development, LAI and harvest tables | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | SW431-CROP-WOF81 |
| SW431-CROP-GRASS | Grass regrowth, mowing and grazing | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | SW431-CROP-WOF81 |
| SW431-CROP-ROOTGROW | Root-depth/distribution development and hydrological feedback | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | SW431-CROP-WOF81 |
| SW431-CROP-ROTATION | Multi-crop start/end/harvest accepted lifecycle | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | SW431-CROP-WOF81 |
| SW431-CROP-SOW | Soil-state-dependent preparation, sowing and germination | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | SW431-CROP-WOF81 |
| SW431-CROP-SOY | Soybean-specific phenology and photoperiod | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | SW431-CROP-WOF81 |
| SW431-CROP-WOF-OTHER | Non-barley/daylength/vernalisation crop envelope | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | SW431-CROP-WOF81 |
| SW431-ROOT-ANAE-GROW | Anaerobic suppression of root extension | Empirical/physical uptake oxygen admissions do not establish oxygen-controlled root growth | SW431-CROP-ROOTGROW |
| SW431-ROOT-DENSITY | Adaptive root density and constant volumetric root length options | Separate root-biomass distribution lifecycle; needs typed crop/root state ownership | SW431-CROP-ROOTGROW |

### MC-DRAIN01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-DRAIN-ALLOCATION | Multilevel exchange allocation and drain/channel type | Trace dynamically named SWALLO(level) fields, not just scalar DRAMET response presence | SW431-DRAIN-EXT |
| SW431-DRAIN-DISLAYER | Absolute or water-level-relative discharge-layer geometry | Individual source spatial allocation and preparation options must be reconciled with admitted typed distribution | SW431-DRAIN-DIV |
| SW431-DRAIN-INF-LIMIT | Head-difference-limited drain/channel infiltration | Source option changes signed exchange, not parser behaviour | SW431-DRAIN-EXT |
| SW431-DRAIN-INF-SPLIT | Separate shallower infiltration spatial distribution | DRAMET3-only ordinary route needs current runtime and preparation qualification evidence | SW431-DRAIN-DIV |

### MC-FROST01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-FROST-EXT-MULTI | Multilevel extended surface-water/drain frost | Current frost runtime admissions explicitly restrict these source-relevant owner combinations | SW431-FROST-DRAIN-EXTENDED |
| SW431-FROST-GW | Frost with other legacy lower-boundary owners | Current frost runtime admissions explicitly restrict these source-relevant owner combinations | SW431-FROST-HYD |
| SW431-FROST-ROOTDRAIN | Root uptake composed with frost drainage | Current frost runtime admissions explicitly restrict these source-relevant owner combinations | SW431-FROST-DRAIN-PRESCRIBED, SW431-ROOT-FROST |
| SW431-FROST-DIV-MULTI | Multilevel frost spatial redistribution | Current frost runtime admissions explicitly restrict these source-relevant owner combinations | SW431-FROST-DIVDRA |

### MC-HEAT01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-TEMP-ANALYTIC | Analytical harmonic soil temperature | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | SW431-TEMP-SENSIBLE |
| SW431-TEMP-BC3 | Specified thermal flux boundary | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | SW431-TEMP-SENSIBLE |
| SW431-TEMP-BC4 | Surface temperature with heat-flux correction | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | SW431-TEMP-SENSIBLE |
| SW431-TEMP-BOTTOM2 | Prescribed bottom temperature | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | SW431-TEMP-SENSIBLE |
| SW431-TEMP-SNOW | Snow thermal resistance coupled to sensible heat | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | SW431-TEMP-SENSIBLE |

### MC-HYD01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-HYD-LINEAR-TABLE | Explicit piecewise linear hydraulic input tables | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL10 | Bimodal PDI capillary, adsorption and film-flow relations | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL11 | Bimodal PDI normalized at finite dry-end head | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL12 | RIA hydraulic relations | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL2 | Exponential test hydraulic relations | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL3 | Bimodal Mualem-Van Genuchten | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL5 | Unimodal Mualem-Van Genuchten normalized at finite dry-end head | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL6 | Unscaled bimodal Mualem-Van Genuchten relations | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL7 | Bimodal Mualem-Van Genuchten normalized at finite dry-end head | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL8 | Unimodal PDI capillary, adsorption and film-flow relations | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-MODEL9 | Unimodal PDI normalized at finite dry-end head | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-POWER | Conductivity power-tail extension | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-TABLE | User-provided hydraulic relation tables | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-HYD-RIA-VAPOR | RIA vapour/temperature-dependent conductivity and fitted dry-end relation | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | SW431-HYD-MODEL12 |
| SW431-HYD-VAPOR | PDI vapour contribution to unsaturated conductivity | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | SW431-HYD-MODEL8, SW431-HYD-MODEL9, SW431-HYD-MODEL10, SW431-HYD-MODEL11 |

### MC-HYST01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-HYST1 | Scanning retention history with initial wetting branch | Persist nodewise INDEKS, FHYST, DELP and accepted head/theta; reversal mutates curve, head and capacity; no admitted typed history owner | SW431-HYD-MVG |
| SW431-HYST2 | Scanning retention history with initial drying branch | Persist nodewise INDEKS, FHYST, DELP and accepted head/theta; reversal mutates curve, head and capacity; no admitted typed history owner | SW431-HYD-MVG |

### MC-IRR01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-IRR-TCS2 | Readily available root-zone water depletion trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-TCS3 | Total available root-zone water depletion trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-TCS4 | Absolute root-zone water depletion trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-TCS6 | Weekly thresholded irrigation trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-TCS7 | Pressure-head sensor trigger | Restricted process exists and is independently qualified; production runtime binding is absent at the audited canonical head. | None |
| SW431-IRR-TCS8 | Water-content sensor trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-DCS1 | Refill-to-field-capacity with under/over depth and rainfall deduction | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | SW431-IRR-TCS1 |
| SW431-IRR-FIXED-SPRINK | Fixed scheduled-date sprinkling | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | SW431-IRR-TCS1 |
| SW431-IRR-FREQ | General minimum interval and seasonal/cross-year scheduling | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | SW431-IRR-TCS1 |
| SW431-IRR-LIMIT | Minimum/maximum irrigation depth constraints | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | SW431-IRR-TCS1 |
| SW431-IRR-SALTEXCESS | Sensor salt-threshold excess irrigation | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | SW431-IRR-TCS1 |
| SW431-IRR-SCHED-SURF | Scheduled surface irrigation routing | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | SW431-IRR-TCS1 |
| SW431-IRR-SSDI | Single-node or depth-interval subsurface drip irrigation | Restricted process exists and is independently qualified; production runtime binding is absent at the audited canonical head. | SW431-IRR-TCS1 |

### MC-LOW01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-LOW3-EXPLICIT | GWL and saturated-profile dependent explicit aquifer resistance exchange | LOW03-A explicitly leaves this route open; profile resistance and GWL reconciliation differ from the bounded implicit provider. Numerical policy alone cannot establish replacement | None |
| SW431-LOW9 | Simultaneously imposed bottom flux and head with forced last-node head/theta/K reset | Parser accepts 9; internal/special label alone does not prove nonapplicability; resolve exact call/state consumers | None |

### MC-MACRO01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-MACRO-ABS2 | Alternative unsaturated absorption route | Standard bounded route/isolated component presence does not establish this selector production envelope | None |
| SW431-MACRO-DARCY | Extra unsaturated Darcy exchange | Standard bounded route/isolated component presence does not establish this selector production envelope | None |
| SW431-MACRO-KINEMATIC | Kinematic-wave main bypass domain with exponent NKWT | Standard bounded route/isolated component presence does not establish this selector production envelope | None |
| SW431-MACRO-POWM | Double convex/concave internal-catchment domain frequency distribution | Standard bounded route/isolated component presence does not establish this selector production envelope | None |
| SW431-MACRO-SEP2 | Alternative saturated exchange geometry | Standard bounded route/isolated component presence does not establish this selector production envelope | None |
| SW431-MACRO-SORP1 | Parlange sorptivity | Trace actual standard macro typed sorptivity preparation before assuming both source relations covered | None |
| SW431-MACRO-SORP2 | Empirical sorptivity law | Trace actual standard macro typed sorptivity preparation before assuming both source relations covered | None |

### MC-MACROSUR01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-MACRO-EVAP | Stateful evaporation with macropore surface input | Explicit additional owner composition is excluded from current A9/MIGMAC09 runtime admissions | SW431-MACRO-TOP |
| SW431-MACRO-POND | Explicit ponding macropore donor and returned surface water | Explicit additional owner composition is excluded from current A9/MIGMAC09 runtime admissions | SW431-MACRO-TOP |
| SW431-MACRO-RUNON | Runon/excess lateral macropore donor | Explicit additional owner composition is excluded from current A9/MIGMAC09 runtime admissions | SW431-MACRO-TOP |
| SW431-MACRO-SNOW | Daily snow and transactional macropore top input | Explicit additional owner composition is excluded from current A9/MIGMAC09 runtime admissions | SW431-MACRO-TOP |
| SW431-MACRO-SW | Rapid-drain receipt into fixed-weir/external surface-water owner | Explicit additional owner composition is excluded from current A9/MIGMAC09 runtime admissions | SW431-MACRO-TOP |

### MC-MET01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-ET-CROPHEIGHT | Crop-height aerodynamic conversion in ET | Restricted forcing/PM admission is not proof of this source selector; source-bound typed derivation/application qualification remains | None |
| SW431-ET-PMDETAIL | Detailed-record Penman-Monteith atmospheric demand | Restricted forcing/PM admission is not proof of this source selector; source-bound typed derivation/application qualification remains | None |
| SW431-ET-PMTRAD | Traditional Penman-Monteith reference demand partition | Restricted forcing/PM admission is not proof of this source selector; source-bound typed derivation/application qualification remains | None |
| SW431-ET-SOILFACTOR | Soil-factor conversion of potential soil evaporation | Restricted forcing/PM admission is not proof of this source selector; source-bound typed derivation/application qualification remains | None |
| SW431-MET-RAIN1 | Within-day rainfall intensity distribution from RAINTB | Restricted forcing/PM admission is not proof of this source selector; source-bound typed derivation/application qualification remains | None |
| SW431-MET-RAIN2 | Daily rainfall duration WET forcing | Restricted forcing/PM admission is not proof of this source selector; source-bound typed derivation/application qualification remains | None |
| SW431-MET-RAIN3 | Separate detailed .rain rainfall forcing | Restricted forcing/PM admission is not proof of this source selector; source-bound typed derivation/application qualification remains | None |

### MC-MICRO01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-ROOT-MICRO2 | de Jong van Lier microscopic soil-root hydraulic extraction | Independent nonlinear MFLP/root-interface/xylem/leaf solver; not equivalent to Feddes or externally compensated MICRO; source-derived candidate/scratch/restart contract required | SW431-HYD-MVG |
| SW431-ROOT-MICRO3 | de Willigen microscopic soil-root hydraulic extraction | Independent nonlinear MFLP/root-interface/xylem/leaf solver; not equivalent to Feddes or externally compensated MICRO; source-derived candidate/scratch/restart contract required | SW431-HYD-MVG |
| SW431-ROOT-MICRO-LIFT | Microscopic hydraulic lift/redistribution | Signed node extraction and shared soil-root potential need one qualified water owner; no extra external sink | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |
| SW431-ROOT-MICRO-STRESS | Microscopic oxygen/salinity reduction and stress attribution | Trace real root dispatcher stress envelope; frost explicitly errors; root-density/rate reductions are separate MICRO options | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |
| SW431-ROOT-MICRO-TRED | MICRO transpiration-reduction and maximum-drought policy | Actual accepted reader ranges, not commented third variant; map stress attribution and root potentials | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |

### MC-NUT01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-NUT-AMEND | Fertilizer/manure applications and volatilisation | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-CROP-WOF81 |
| SW431-NUT-CROP | Demand/supply coupling and nitrogen-limited crop growth | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-CROP-WOF81 |
| SW431-NUT-MINERAL | Owned ammonium/nitrate inventory, sorption capacity and soil-supply limitation | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-CROP-WOF81 |
| SW431-NUT-ORGANIC | Organic matter and organic nitrogen turnover/mineralisation | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-CROP-WOF81 |
| SW431-NUT-RESIDUE | Crop residue transfers to organic soil pools | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-CROP-WOF81 |
| SW431-NUT-DENIT | Nitrate loss controlled by temperature, wetness and organic respiration activity | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-MINERAL, SW431-NUT-ORGANIC |
| SW431-NUT-NFIX | Biological nitrogen fixation as a separately booked crop N input | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-CROP |
| SW431-NUT-NITRIF | Temperature- and water-filled-pore-dependent ammonium-to-nitrate transformation | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-MINERAL |
| SW431-NUT-TRANSPORT | Analytical ammonium/nitrate concentration and outflow balance with sorption, boundary inputs and crop uptake | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-MINERAL |

### MC-ROOT01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-ROOT-OXYGEN-EMP | Empirical anaerobic/Feddes wet stress | Current Feddes process supplies drought-only reduction. Bartholomeus mode2/type1 admission does not admit the separate SWOXYGEN=1 wet-pressure-head reduction. | None |
| SW431-ROOT-OXYGEN-REPRO | Bartholomeus oxygen reproduction-function route | Physical type1 admission does not cover distinct type2 response functions | None |

### MC-SOL01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-AGE-TRACER | Water age tracer with ageing and advective/dispersive transport | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | SW431-SALT-TRANSPORT |
| SW431-SALT-AQUIFER | Mixed aquifer concentration with storage, sorption, decay and surface-water breakthrough | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | SW431-SALT-TRANSPORT |
| SW431-SALT-DECAY | Temperature/moisture/depth modified decomposition | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | SW431-SALT-TRANSPORT |
| SW431-SALT-POND | Ponded solute storage and rain/irrigation/dissolved runoff exchange | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | SW431-SALT-TRANSPORT |
| SW431-SALT-SORPTION | Freundlich nonlinear sorption/storage | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | SW431-SALT-TRANSPORT |

### MC-SUR01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-RUNOFF-NONLINEAR | Nonlinear surface-runoff power law and iterative ponding solution | The current dynamic-top provider explicitly rejects active runoff_exponent /= 1. Legacy power-law/iterative response is a distinct absent production capability. | SW431-PONDING |
| SW431-RUNON | Externally supplied lateral water entering soil surface | Typed dynamic-top process includes runon, but current legacy production task2 reachability rejects swrunon /= 0 and common-forcing ingestion rejects nonzero runon. A qualified process field is not a production application binding. | SW431-PONDING |

### MC-SW01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-SW-MANAGEMENT | Automatic weir adjustment from groundwater/soil-head criteria | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | SW431-SW-FIXED, SW431-SW-EXTERNAL |
| SW431-SW-MULTILEVEL | Multiple external water levels and exchange owners | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | SW431-SW-FIXED, SW431-SW-EXTERNAL |
| SW431-SW-PRIMARY | Primary and secondary surface-water systems | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | SW431-SW-FIXED, SW431-SW-EXTERNAL |
| SW431-SW-QHR2 | Tabulated water-level/discharge rating relation | Admitted fixed-weir power rating does not establish arbitrary legacy QQHTAB/HQHTAB rating. Ribasim replacement must preserve actual rating/storage and exchange semantics. | SW431-SW-FIXED |
| SW431-SW-TOPRUNOFF | Top runoff routed into surface-water storage | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | SW431-SW-FIXED, SW431-SW-EXTERNAL |

### MC-TILL01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-TILL-CONSOL | Post-tillage consolidation history | No typed production tillage owner; exact B1.11 retains only SWAP002 start-date repair; SWAP003/004 remain unadmitted | SW431-HYD-MVG |
| SW431-TILL-EVENT | Tillage events modifying density and hydraulic relations | No typed production tillage owner; exact B1.11 retains only SWAP002 start-date repair; SWAP003/004 remain unadmitted | SW431-HYD-MVG |
| SW431-TILL-REDIST | Water redistribution after changing soil geometry/density | No typed production tillage owner; exact B1.11 retains only SWAP002 start-date repair; SWAP003/004 remain unadmitted | SW431-HYD-MVG |

### PPA-WU05B19

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-FROST-DIVDRA | Trial-start signed spatial redistribution with frost | B18 is an isolated scientific component with no backend import; runtime scalar/nodal/bottom ownership is still open | SW431-FROST-HYD |

## Closure gate

Run `python tools/audits/check_swap431_coverage.py` for structural/source integrity.
Run `python tools/audits/check_swap431_coverage.py --require-closed` for a closure assertion.
The latter intentionally fails while the source denominator is incomplete or any ACTIVE_MIGRATION remains.
Neither command scientifically qualifies a process. Owning source/runtime gates and canonical admission remain required.

No final global rejection has been invented to shrink the queue. No historical research PR is a blocker merely because it is open. The complete paginated snapshot records 114 open PRs and 55 merges since 2026-10-05; migration proposal reconciliation is explicit. The earlier 100-item snapshot is retained as historical evidence.
