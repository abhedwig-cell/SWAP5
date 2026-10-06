# SWAP431 functional coverage master: recoverable review

Baseline: `e5eab995ef04fc813dd644025fb0f32e4f5050a1`. Status: IN_PROGRESS. **Coverage is not closed; the denominator is not yet declared exhaustive.**

The ledger currently contains 227 entries: 79 bounded ADMITTED, 12 SUPERSEDED, 1 REJECTED, 18 NOT_APPLICABLE and 117 ACTIVE_MIGRATION entries across 19 review/migration workunits.

Only 57 entries are currently marked as proven missing production implementation/binding. The other 60 are unresolved source/admission/replacement reviews. Neither number is a final exhaustive missing-functionality count. Review registration is not implementation or admission.

The machine authority is `integration/audits/SWAP431_FUNCTIONAL_COVERAGE_MASTER.json`.
The exact source bundle and input-reader census are in `integration/audits/evidence/`.
The source findings and exclusion reasoning are in `SWAP431_SOURCE_REVIEW.md`.

## Confirmed production gaps traced so far

| Capability | Meaning | Workunit | Dependencies |
|---|---|---|---|
| SW431-HYD-LINEAR-TABLE | Explicit piecewise linear hydraulic input tables | MC-HYD01 | None |
| SW431-IRR-FREQ | Stress-triggered irrigation without minimum interval suppression | MC-IRR01 | None |
| SW431-IRR-RATE-CAP | Cap long scheduled irrigation events at one day while preserving depth | MC-IRR01 | None |
| SW431-IRR-RATE-DAILY | Spread scheduled irrigation depth uniformly over one day | MC-IRR01 | None |
| SW431-IRR-SSDI | Single-node or depth-interval subsurface drip irrigation | MC-IRR01 | None |
| SW431-IRR-TCS7 | Pressure-head sensor trigger | MC-IRR01 | None |
| SW431-FROST-DIVDRA | Trial-start signed spatial redistribution with frost | PPA-WU05B19 | None |
| SW431-FROST-EXT-MULTI | Multilevel extended surface-water/drain frost | MC-FROST01 | None |
| SW431-FROST-GW | Frost with other legacy lower-boundary owners | MC-FROST01 | None |
| SW431-FROST-ROOTDRAIN | Root uptake composed with frost drainage | MC-FROST01 | None |
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
| SW431-HYST1 | Scanning retention history with initial wetting branch | MC-HYST01 | None |
| SW431-HYST2 | Scanning retention history with initial drying branch | MC-HYST01 | None |
| SW431-ROOT-MICRO2 | de Jong van Lier microscopic soil-root hydraulic extraction | MC-MICRO01 | None |
| SW431-ROOT-MICRO3 | de Willigen microscopic soil-root hydraulic extraction | MC-MICRO01 | None |
| SW431-ROOT-OXYGEN-EMP | Empirical anaerobic/Feddes wet stress | MC-ROOT01 | None |
| SW431-MACRO-ABS2 | Alternative unsaturated absorption route | MC-MACRO01 | None |
| SW431-MACRO-DARCY | Extra unsaturated Darcy exchange | MC-MACRO01 | None |
| SW431-MACRO-EVAP | Stateful evaporation with macropore surface input | MC-MACROSUR01 | None |
| SW431-MACRO-SNOW | Daily snow and transactional macropore top input | MC-MACROSUR01 | None |
| SW431-MACRO-SW | Rapid drainage routed into internal fixed-weir surface-water storage | MC-MACROSUR01 | None |
| SW431-RUNOFF-NONLINEAR | Nonlinear surface-runoff power law and iterative ponding solution | MC-SUR01 | None |
| SW431-RUNON | Externally supplied lateral water entering soil surface | MC-SUR01 | None |
| SW431-TEMP-ANALYTIC | Analytical harmonic soil temperature | MC-HEAT01 | None |
| SW431-TEMP-BC3 | Specified thermal flux boundary | MC-HEAT01 | None |
| SW431-TEMP-BC4 | Surface temperature with heat-flux correction | MC-HEAT01 | None |
| SW431-TEMP-BOTTOM2 | Prescribed bottom temperature | MC-HEAT01 | None |
| SW431-TEMP-SNOW | Snow thermal resistance coupled to sensible heat | MC-HEAT01 | None |
| SW431-TILL-EVENT | Tillage events modifying density and hydraulic relations | MC-TILL01 | None |
| SW431-AGE-TRACER | Water age tracer with ageing and advective/dispersive transport | MC-SOL01 | None |
| SW431-SALT-AQUIFER | Mixed aquifer concentration with storage, sorption, decay and surface-water breakthrough | MC-SOL01 | None |
| SW431-SALT-DECAY | Temperature/moisture/depth modified decomposition | MC-SOL01 | None |
| SW431-SALT-POND | Ponded solute storage and rain/irrigation/dissolved runoff exchange | MC-SOL01 | None |
| SW431-SALT-SORPTION | Freundlich nonlinear sorption/storage | MC-SOL01 | None |
| SW431-CROP-FIXED | Calendar-clock prescribed-LAI/root-biomass crop development and harvest | MC-CROP01 | None |
| SW431-CROP-FIXED-THERMAL | Thermal-sum prescribed-LAI/root-biomass crop development and harvest | MC-CROP01 | None |
| SW431-FROST-DIV-MULTI | Multilevel frost spatial redistribution | MC-FROST01 | SW431-FROST-DIVDRA |
| SW431-FROST-SNOW | Snow-insulated sensible temperature driving empirical frost hydraulics | MC-FROST01 | SW431-TEMP-SNOW |
| SW431-HYD-RIA-VAPOR | RIA vapour/temperature-dependent conductivity and fitted dry-end relation | MC-HYD01 | SW431-HYD-MODEL12 |
| SW431-HYD-VAPOR | PDI vapour contribution to unsaturated conductivity | MC-HYD01 | SW431-HYD-MODEL8, SW431-HYD-MODEL9, SW431-HYD-MODEL10, SW431-HYD-MODEL11 |
| SW431-TILL-CONSOL | Rain-forcing-driven post-tillage bulk-density consolidation | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-N1 | Keep n unchanged during density-induced hydraulic material update | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-N2 | Update n using silt/clay ratio and density ratio exponent | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-N3 | Update n with density matching-point slope and floor1.001 | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-REDIST | Retain pressure head then redistribute weighted water after material change | MC-TILL01 | SW431-TILL-EVENT, SW431-TILL-N1, SW431-TILL-N2, SW431-TILL-N3 |
| SW431-TILL-REDIST1 | Keep water content with excess-to-pond redistribution after material change | MC-TILL01 | SW431-TILL-N1, SW431-TILL-N2, SW431-TILL-N3 |

## Registered review queue

These are individual capability decisions, not admitted implementation plans. Dependency depth orders prerequisites first; independent qualification reviews can reduce the queue before new physics work.

| Workunit | Open entries | Next action |
|---|---:|---|
| MC-CROP01 | 12 | Source/admission adjudication for the exact IDs below |
| MC-DRAIN01 | 4 | Source/admission adjudication for the exact IDs below |
| MC-FROST01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-HEAT01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-HYD01 | 15 | Source/admission adjudication for the exact IDs below |
| MC-HYST01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-IRR01 | 16 | Source/admission adjudication for the exact IDs below |
| MC-LOW01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-MACRO01 | 7 | Source/admission adjudication for the exact IDs below |
| MC-MACROSUR01 | 6 | Source/admission adjudication for the exact IDs below |
| MC-MET01 | 7 | Source/admission adjudication for the exact IDs below |
| MC-MICRO01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-NUT01 | 9 | Source/admission adjudication for the exact IDs below |
| MC-ROOT01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-SOL01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-SUR01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-SW01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-TILL01 | 7 | Source/admission adjudication for the exact IDs below |
| PPA-WU05B19 | 1 | Source/admission adjudication for the exact IDs below |

### MC-CROP01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-CROP-ATTAINABLE | Attainable versus theoretical potential growth correction | RELFMF parameter and selector not established by ten-case crop-equivalence denominator | None |
| SW431-CROP-CO2 | Time-varying CO2 crop response and forcing | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-FIXED | Calendar-clock prescribed-LAI/root-biomass crop development and harvest | Source IDEV1 advances DVS by 2/LCC, accumulates TSUM, interpolates LAITB, and retains previous root biomass where applicable. Typed canopy/root views are consumers; the current admitted WOFOST81 owner does not implement this fixed-crop state update. | None |
| SW431-CROP-FIXED-THERMAL | Thermal-sum prescribed-LAI/root-biomass crop development and harvest | Source IDEV2 uses max(0,TAV-TBASE), TSUMEA before anthesis and TSUMAM after anthesis to advance DVS, then updates prescribed LAI/root biomass. Current typed views do not supply this independent accepted phenology state/evaluator. | None |
| SW431-CROP-GRASS | Grass regrowth, mowing and grazing | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-ROOTGROW | Root-depth/distribution development and hydrological feedback | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-ROTATION | Multi-crop start/end/harvest accepted lifecycle | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-SOW | Soil-state-dependent preparation, sowing and germination | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-SOY | Soybean-specific phenology and photoperiod | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-WOF-OTHER | Non-barley/daylength/vernalisation crop envelope | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-ROOT-ANAE-GROW | Anaerobic suppression of root extension | Empirical/physical uptake oxygen admissions do not establish oxygen-controlled root growth | SW431-CROP-ROOTGROW |
| SW431-ROOT-DENSITY | Adaptive root density and constant volumetric root length options | Separate root-biomass distribution lifecycle; needs typed crop/root state ownership | SW431-CROP-ROOTGROW |

### MC-DRAIN01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-DRAIN-ALLOCATION | Multilevel exchange allocation and drain/channel type | Trace dynamically named SWALLO(level) fields, not just scalar DRAMET response presence | None |
| SW431-DRAIN-DISLAYER | Absolute or water-level-relative discharge-layer geometry | Individual source spatial allocation and preparation options must be reconciled with admitted typed distribution | None |
| SW431-DRAIN-INF-LIMIT | Head-difference-limited drain/channel infiltration | Source option changes signed exchange, not parser behaviour | None |
| SW431-DRAIN-INF-SPLIT | Separate shallower infiltration spatial distribution | DRAMET3-only ordinary route needs current runtime and preparation qualification evidence | None |

### MC-FROST01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-FROST-EXT-MULTI | Multilevel extended surface-water/drain frost | Current extended/highest frost drain validation explicitly requires exactly one response level; legacy multilevel extended frost remains production-blocked. | None |
| SW431-FROST-GW | Frost with other legacy lower-boundary owners | Current frost admission requires bottom_mode==2. The other source-relevant lower-boundary frost compositions have no admitted runtime route. | None |
| SW431-FROST-ROOTDRAIN | Root uptake composed with frost drainage | Current frost drainage admission explicitly rejects root_extraction_active and root_frost.active. Admitted empirical root frost does not close its composition with ordinary/extended drainage. | None |
| SW431-FROST-DIV-MULTI | Multilevel frost spatial redistribution | The single-level B18 DIVDRA component is not backend-bound, so the source multilevel DIVDRA frost composition lacks both the prerequisite single-level runtime and multilevel owner binding. | SW431-FROST-DIVDRA |
| SW431-FROST-SNOW | Snow-insulated sensible temperature driving empirical frost hydraulics | Legacy snow resistance changes the soil-interface temperature consumed by FrozenCond; current frost admission rejects snow_active, and the current numerical thermal owner also rejects snow. This needs the TEMP-SNOW route followed by bounded snow/frost ownership qualification. No ice or latent heat is implied. | SW431-TEMP-SNOW |

### MC-HEAT01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-TEMP-ANALYTIC | Analytical harmonic soil temperature | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | None |
| SW431-TEMP-BC3 | Specified thermal flux boundary | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | None |
| SW431-TEMP-BC4 | Surface temperature with heat-flux correction | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | None |
| SW431-TEMP-BOTTOM2 | Prescribed bottom temperature | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | None |
| SW431-TEMP-SNOW | Snow thermal resistance coupled to sensible heat | The current thermal forcing carries only prescribed_surface_temperature_c; the solver assembles Dirichlet top and zero-flux bottom, with no analytic harmonic, prescribed flux/mixed boundary, prescribed bottom temperature or snow-resistance route. | None |

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
| SW431-HYST1 | Scanning retention history with initial wetting branch | Persist nodewise INDEKS, FHYST, DELP and accepted head/theta; reversal mutates curve, head and capacity; no admitted typed history owner | None |
| SW431-HYST2 | Scanning retention history with initial drying branch | Persist nodewise INDEKS, FHYST, DELP and accepted head/theta; reversal mutates curve, head and capacity; no admitted typed history owner | None |

### MC-IRR01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-IRR-AVAIL | External irrigation-availability scaling of selected event | Legacy TASK4 scales both gird and, for positive configured rate, dt_irr_event: event volume scales quadratically. Trace actual MultiSWAP callers and intended allocation semantics before migration/replacement; this is physical availability logic rather than obsolete TASK dispatch. | None |
| SW431-IRR-DCS1 | Refill-to-field-capacity with under/over depth and rainfall deduction | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | None |
| SW431-IRR-FIXED-SPRINK | Fixed scheduled-date sprinkling | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | None |
| SW431-IRR-FREQ | Stress-triggered irrigation without minimum interval suppression | F-APP07 requires TCSFIX1 and positive minimum_interval_days; the source TCSFIX0 omits dayfix gating. Qualified TCS7 standalone component has no production binding and cannot close this scheduled no-interval route. | None |
| SW431-IRR-LIMIT | Minimum/maximum irrigation depth constraints | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | None |
| SW431-IRR-RATE-CAP | Cap long scheduled irrigation events at one day while preserving depth | Source temporarily raises the rate to depth/day when requested duration exceeds one day. Current admitted TCS1 owner rejects duration>1 and never performs this adaptation. | None |
| SW431-IRR-RATE-DAILY | Spread scheduled irrigation depth uniformly over one day | Source zero-rate fallback selects daily depth as rate. Current admitted TCS1 owner requires strictly positive rate and does not implement this fallback. | None |
| SW431-IRR-SCHED-SURF | Scheduled surface irrigation routing | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | None |
| SW431-IRR-SSDI | Single-node or depth-interval subsurface drip irrigation | Restricted process exists and is independently qualified; production runtime binding is absent at the audited canonical head. | None |
| SW431-IRR-TCS2 | Readily available root-zone water depletion trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-TCS3 | Total available root-zone water depletion trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-TCS4 | Absolute root-zone water depletion trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-TCS6 | Weekly thresholded irrigation trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-TCS7 | Pressure-head sensor trigger | Restricted process exists and is independently qualified; production runtime binding is absent at the audited canonical head. | None |
| SW431-IRR-TCS8 | Water-content sensor trigger | Actual source option not covered by TCS1+DCS2 admission; TCS7 uses pressure head, TCS8 water content | None |
| SW431-IRR-SALTEXCESS | Sensor salt-threshold excess irrigation | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | SW431-IRR-TCS7, SW431-IRR-TCS8 |

### MC-LOW01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-LOW3-EXPLICIT | GWL and saturated-profile dependent explicit aquifer resistance exchange | LOW03-A explicitly leaves this route open; profile resistance and GWL reconciliation differ from the bounded implicit provider. Numerical policy alone cannot establish replacement | None |
| SW431-LOW9 | Simultaneously imposed bottom flux and head with forced last-node head/theta/K reset | Parser accepts 9; internal/special label alone does not prove nonapplicability; resolve exact call/state consumers | None |

### MC-MACRO01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-MACRO-ABS2 | Alternative unsaturated absorption route | Source SWABS=2 computes head/theta-dependent Diffusivity and updated absorption; current unsaturated request/evaluator provides only the SWABS=1 empirical sorption-history path, with no diffusivity field/operator. | None |
| SW431-MACRO-DARCY | Extra unsaturated Darcy exchange | The active source extra-Darcy operator uses current K(ic). Current preparation updates matrix theta/heads and sorption history but retains unsaturated conductivity from the immutable configuration; source-faithful dynamic-K binding is absent. Existing qualified fixture explicitly sets that coefficient to zero. | None |
| SW431-MACRO-KINEMATIC | Kinematic-wave main bypass domain with exponent NKWT | Standard bounded route/isolated component presence does not establish this selector production envelope | None |
| SW431-MACRO-POWM | Double convex/concave internal-catchment domain frequency distribution | Standard bounded route/isolated component presence does not establish this selector production envelope | None |
| SW431-MACRO-SEP1 | Ernst seepage-face exchange with horizontal, vertical and radial resistance | The source Ernst branch and the corresponding typed SWSEP1 algebra exist, but the A8 fixture sets horizontal conductivity/CDarcy to zero. Active source branch qualification and current runtime envelope must be traced separately from SWSEP2 Youngs geometry. | None |
| SW431-MACRO-SEP2 | Youngs seepage-potential geometry for saturated exchange | Standard bounded route/isolated component presence does not establish this selector production envelope | None |
| SW431-MACRO-SORP1 | Parlange sorptivity | Trace actual standard macro typed sorptivity preparation before assuming both source relations covered | None |

### MC-MACROSUR01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-MACRO-EVAP | Stateful evaporation with macropore surface input | Current macropore admission explicitly rejects both black_evaporation_active and boesten_evaporation_active, and top ingestion repeats those guards. | None |
| SW431-MACRO-POND | Explicit ponding macropore donor and returned surface water | Explicit additional owner composition is excluded from current A9/MIGMAC09 runtime admissions | None |
| SW431-MACRO-SNOW | Daily snow and transactional macropore top input | Current macropore admission explicitly rejects snow_active; the macropore top-forcing ingestion also rejects a supplied input composed with snow. | None |
| SW431-MACRO-SW | Rapid drainage routed into internal fixed-weir surface-water storage | Current macropore admission requires fixed_weir_surface_water_active=false and drainage_response_active=false; legacy internal surface-water storage receives QRapDra in WLEVBAL. This owner composition is production-blocked. | None |
| SW431-MACRO-SW-EXTERNAL | Rapid-drain/macropore interaction with externally prescribed surface-water level | Trace externally prescribed level, effective rapid-drain basis, immutable forcing and signed receipt semantics independently of internal fixed-weir storage; existing static rapid-drain admission alone is not proof of this full time-varying route. | None |
| SW431-MACRO-RUNON | Runon/excess lateral macropore donor | Explicit additional owner composition is excluded from current A9/MIGMAC09 runtime admissions | SW431-RUNON |

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
| SW431-ROOT-MICRO2 | de Jong van Lier microscopic soil-root hydraulic extraction | Independent nonlinear MFLP/root-interface/xylem/leaf solver; not equivalent to Feddes or externally compensated MICRO; source-derived candidate/scratch/restart contract required | None |
| SW431-ROOT-MICRO3 | de Willigen microscopic soil-root hydraulic extraction | Independent nonlinear MFLP/root-interface/xylem/leaf solver; not equivalent to Feddes or externally compensated MICRO; source-derived candidate/scratch/restart contract required | None |
| SW431-ROOT-MICRO-LIFT | Microscopic hydraulic lift/redistribution | Signed node extraction and shared soil-root potential need one qualified water owner; no extra external sink | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |
| SW431-ROOT-MICRO-STRESS | Microscopic oxygen/salinity reduction and stress attribution | Trace real root dispatcher stress envelope; frost explicitly errors; root-density/rate reductions are separate MICRO options | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |
| SW431-ROOT-MICRO-TRED | MICRO transpiration-reduction and maximum-drought policy | Actual accepted reader ranges, not commented third variant; map stress attribution and root potentials | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |

### MC-NUT01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-NUT-MINERAL | Owned ammonium/nitrate inventory, sorption capacity and soil-supply limitation | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | None |
| SW431-NUT-ORGANIC | Organic matter and organic nitrogen turnover/mineralisation | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | None |
| SW431-NUT-AMEND | Fertilizer/manure applications and volatilisation | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-MINERAL, SW431-NUT-ORGANIC |
| SW431-NUT-CROP | Demand/supply coupling and nitrogen-limited crop growth | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-MINERAL |
| SW431-NUT-DENIT | Nitrate loss controlled by temperature, wetness and organic respiration activity | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-MINERAL, SW431-NUT-ORGANIC |
| SW431-NUT-NITRIF | Temperature- and water-filled-pore-dependent ammonium-to-nitrate transformation | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-MINERAL |
| SW431-NUT-RESIDUE | Crop residue transfers to organic soil pools | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-ORGANIC |
| SW431-NUT-TRANSPORT | Analytical ammonium/nitrate concentration and outflow balance with sorption, boundary inputs and crop uptake | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-MINERAL |
| SW431-NUT-NFIX | Biological nitrogen fixation as a separately booked crop N input | SWAP431 executable calls SoilManagement and WOFOST Soil-N; N-unlimited crop admission is not a replacement; separate migrate/ANIMO replacement/rejection authority needed | SW431-NUT-CROP |

### MC-ROOT01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-ROOT-OXYGEN-EMP | Empirical anaerobic/Feddes wet stress | Current Feddes process supplies drought-only reduction. Bartholomeus mode2/type1 admission does not admit the separate SWOXYGEN=1 wet-pressure-head reduction. | None |
| SW431-ROOT-OXYGEN-REPRO | Bartholomeus oxygen reproduction-function route | Physical type1 admission does not cover distinct type2 response functions | None |

### MC-SOL01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-AGE-TRACER | Water age tracer with ageing and advective/dispersive transport | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-SALT-AQUIFER | Mixed aquifer concentration with storage, sorption, decay and surface-water breakthrough | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-SALT-DECAY | Temperature/moisture/depth modified decomposition | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-SALT-POND | Ponded solute storage and rain/irrigation/dissolved runoff exchange | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |
| SW431-SALT-SORPTION | Freundlich nonlinear sorption/storage | Current production provider/state inventory does not supply this source capability; legacy/reference presence is not admission. | None |

### MC-SUR01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-RUNOFF-NONLINEAR | Nonlinear surface-runoff power law and iterative ponding solution | The current dynamic-top provider explicitly rejects active runoff_exponent /= 1. Legacy power-law/iterative response is a distinct absent production capability. | None |
| SW431-RUNON | Externally supplied lateral water entering soil surface | Typed dynamic-top process includes runon, but current legacy production task2 reachability rejects swrunon /= 0 and common-forcing ingestion rejects nonzero runon. A qualified process field is not a production application binding. | None |

### MC-SW01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-SW-MANAGEMENT | Automatic weir adjustment from groundwater/soil-head criteria | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | None |
| SW431-SW-MULTILEVEL | Multiple external water levels and exchange owners | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | None |
| SW431-SW-PRIMARY | Primary and secondary surface-water systems | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | None |
| SW431-SW-QHR2 | Tabulated water-level/discharge rating relation | Admitted fixed-weir power rating does not establish arbitrary legacy QQHTAB/HQHTAB rating. Ribasim replacement must preserve actual rating/storage and exchange semantics. | None |
| SW431-SW-TOPRUNOFF | Top runoff routed into surface-water storage | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | None |

### MC-TILL01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-TILL-EVENT | Tillage events modifying density and hydraulic relations | No typed production tillage owner; exact B1.11 retains only SWAP002 start-date repair; SWAP003/004 remain unadmitted | None |
| SW431-TILL-CONSOL | Rain-forcing-driven post-tillage bulk-density consolidation | No production tillage material owner. Source consolidation uses exp(-K_R_cons*nraidt*10), not a time clock and not I_N_MODEL1..3. Source comment itself questions nraidt; forcing rate/amount and accepted interval semantics require reference review. | SW431-TILL-EVENT |
| SW431-TILL-N1 | Keep n unchanged during density-induced hydraulic material update | No accepted typed tillage material update owner implements this source n law and the shared density-induced theta_r/theta_s/Ksat/alpha update. Candidate material and water must publish atomically. | SW431-TILL-EVENT |
| SW431-TILL-N2 | Update n using silt/clay ratio and density ratio exponent | No accepted typed tillage material update owner implements this source n law and the shared density-induced theta_r/theta_s/Ksat/alpha update. Candidate material and water must publish atomically. | SW431-TILL-EVENT |
| SW431-TILL-N3 | Update n with density matching-point slope and floor1.001 | No accepted typed tillage material update owner implements this source n law and the shared density-induced theta_r/theta_s/Ksat/alpha update. Candidate material and water must publish atomically. | SW431-TILL-EVENT |
| SW431-TILL-REDIST | Retain pressure head then redistribute weighted water after material change | No production tillage water owner. Literal source selects redistribution direction with unweighted theta sums but computes weighted inventory; equal sums skip state updates. Bounded O0/O2 probe exposes inverse inconsistency. Conservative replacement/reference-defect adjudication is required before admission. | SW431-TILL-EVENT, SW431-TILL-N1, SW431-TILL-N2, SW431-TILL-N3 |
| SW431-TILL-REDIST1 | Keep water content with excess-to-pond redistribution after material change | No production tillage water owner. Literal source sums (theta_s-theta)*dz for oversaturation and assigns the negative result to pond. Probe starts with3cm and ends with1cm including pond=-1cm at O0/O2. Exact defective semantics must be adjudicated through reference policy, with conservative intended functionality retained in migration scope. | SW431-TILL-N1, SW431-TILL-N2, SW431-TILL-N3 |

### PPA-WU05B19

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-FROST-DIVDRA | Trial-start signed spatial redistribution with frost | B18 is an isolated scientific component with no backend import; runtime scalar/nodal/bottom ownership is still open | None |

## Closure gate

Run `python tools/audits/check_swap431_coverage.py` for structural/source integrity.
Run `python tools/audits/check_swap431_coverage.py --require-closed` for a closure assertion.
The latter intentionally fails while the source denominator is incomplete or any ACTIVE_MIGRATION remains.
Neither command scientifically qualifies a process. Owning source/runtime gates and canonical admission remain required.

No final global rejection has been invented to shrink the queue. No historical research PR is a blocker merely because it is open. The complete paginated snapshot records 114 open PRs and 55 merges since 2026-10-05; migration proposal reconciliation is explicit. The earlier 100-item snapshot is retained as historical evidence.
