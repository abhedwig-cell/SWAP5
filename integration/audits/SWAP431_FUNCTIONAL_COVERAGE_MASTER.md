# SWAP431 functional coverage master: recoverable review

Baseline: `e5eab995ef04fc813dd644025fb0f32e4f5050a1`. Status: IN_PROGRESS. **Coverage is not closed; the denominator is not yet declared exhaustive.**

The ledger currently contains 241 entries: 79 bounded ADMITTED, 12 SUPERSEDED, 1 REJECTED, 19 NOT_APPLICABLE and 130 ACTIVE_MIGRATION entries across 19 review/migration workunits.

Only 106 entries are currently marked as proven missing production implementation/binding. The other 24 are unresolved source/admission/replacement reviews. Neither number is a final exhaustive missing-functionality count. Review registration is not implementation or admission.

Admitted SWAP5 replacement foundations are listed separately and do not count as proof of literal B1.11 branch coverage.

The machine authority is `integration/audits/SWAP431_FUNCTIONAL_COVERAGE_MASTER.json`.
The exact source bundle and input-reader census are in `integration/audits/evidence/`.
The source findings and exclusion reasoning are in `SWAP431_SOURCE_REVIEW.md`.

## Confirmed production gaps traced so far

| Capability | Meaning | Workunit | Dependencies |
|---|---|---|---|
| SW431-DRAIN-DISLAYER | Absolute or water-level-relative discharge-layer geometry | MC-DRAIN01 | None |
| SW431-DRAIN-DIV-SIGNED | Ordinary signed conductivity-weighted drainage distribution | MC-DRAIN01 | None |
| SW431-DRAIN-DIV-TOPINTERFLOW | Separate highest interflow discharge layer and lower-layer exclusion | MC-DRAIN01 | None |
| SW431-DRAIN-DRAMET3 | Native signed resistance response with time-varying channel head and drain-bottom clamp | MC-DRAIN01 | None |
| SW431-HYD-LINEAR-TABLE | Explicit piecewise linear hydraulic input tables | MC-HYD01 | None |
| SW431-IRR-AVAIL | External irrigation-availability scaling of selected event | MC-IRR01 | None |
| SW431-IRR-DCS1 | Refill-to-field-capacity with under/over depth and rainfall deduction | MC-IRR01 | None |
| SW431-IRR-FREQ | Stress-triggered irrigation without minimum interval suppression | MC-IRR01 | None |
| SW431-IRR-LIMIT | Minimum/maximum irrigation depth constraints | MC-IRR01 | None |
| SW431-IRR-RATE-CAP | Cap long scheduled irrigation events at one day while preserving depth | MC-IRR01 | None |
| SW431-IRR-RATE-DAILY | Spread scheduled irrigation depth uniformly over one day | MC-IRR01 | None |
| SW431-IRR-SSDI | Single-node or depth-interval subsurface drip irrigation | MC-IRR01 | None |
| SW431-IRR-TCS2 | Readily available root-zone water depletion trigger | MC-IRR01 | None |
| SW431-IRR-TCS3 | Total available root-zone water depletion trigger | MC-IRR01 | None |
| SW431-IRR-TCS4 | Absolute root-zone water depletion trigger | MC-IRR01 | None |
| SW431-IRR-TCS6 | Weekly thresholded irrigation trigger | MC-IRR01 | None |
| SW431-IRR-TCS7 | Pressure-head sensor trigger | MC-IRR01 | None |
| SW431-IRR-TCS8 | Water-content sensor trigger | MC-IRR01 | None |
| SW431-ROOT-DENSITY | Adaptive node root-biomass growth/death redistribution | MC-CROP01 | None |
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
| SW431-ROOT-OXYGEN-REPRO | Bartholomeus oxygen reproduction-function route | MC-ROOT01 | None |
| SW431-CROP-ROOTGROW-WATER | Daily root extension scaled by actual/potential transpiration | MC-CROP01 | None |
| SW431-ET-PMDETAIL | Detailed-record Penman-Monteith atmospheric demand | MC-MET01 | None |
| SW431-ET-PMTRAD | Traditional Penman-Monteith reference demand partition | MC-MET01 | None |
| SW431-ET-SOILFACTOR | Soil-factor conversion of potential soil evaporation | MC-MET01 | None |
| SW431-LOW3-EXPLICIT | GWL and saturated-profile dependent explicit aquifer resistance exchange | MC-LOW01 | None |
| SW431-LOW9 | Simultaneously imposed bottom flux and head with forced last-node head/theta/K reset | MC-LOW01 | None |
| SW431-MACRO-ABS2 | Alternative unsaturated absorption route | MC-MACRO01 | None |
| SW431-MACRO-DARCY | Extra unsaturated Darcy exchange | MC-MACRO01 | None |
| SW431-MACRO-EVAP | Stateful evaporation with macropore surface input | MC-MACROSUR01 | None |
| SW431-MACRO-KINEMATIC | Kinematic-wave main bypass compartment propagation with exponent NKWT | MC-MACRO01 | None |
| SW431-MACRO-SNOW | Daily snow and transactional macropore top input | MC-MACROSUR01 | None |
| SW431-MACRO-SORP1 | Parlange hydraulic diffusivity integration and fitting of sorptivity maximum/exponent | MC-MACRO01 | None |
| SW431-MACRO-SW | Rapid drainage routed into internal fixed-weir surface-water storage | MC-MACROSUR01 | None |
| SW431-MET-RAIN1 | Within-day rainfall intensity distribution from RAINTB | MC-MET01 | None |
| SW431-MET-RAIN2 | Daily rainfall duration WET forcing | MC-MET01 | None |
| SW431-RUNOFF-NONLINEAR | Nonlinear surface-runoff power law and iterative ponding solution | MC-SUR01 | None |
| SW431-RUNON | Externally supplied lateral water entering soil surface | MC-SUR01 | None |
| SW431-SW-DRAIN-FEEDBACK | Accepted drainage receipt into surface-water storage and updated level back into drainage basis | MC-SW01 | None |
| SW431-SW-MANAGEMENT | Automatic weir adjustment from groundwater/soil-head criteria | MC-SW01 | None |
| SW431-SW-QHR2 | Tabulated water-level/discharge rating relation | MC-SW01 | None |
| SW431-SW-SIGNED | Surface-water storage depletion by signed infiltration into soil | MC-SW01 | None |
| SW431-SW-TOPRUNOFF | Top runoff routed into surface-water storage | MC-SW01 | None |
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
| SW431-CROP-ROOTGROW | Accepted daily maximum-rate root-depth extension gated by transpiration and allocated root growth | MC-CROP01 | None |
| SW431-CROP-VERNAL | Temperature/daylength phenology with persistent vernalisation sum and completion flag | MC-CROP01 | None |
| SW431-NUT-MINERAL | Owned ammonium/nitrate inventory, sorption capacity and soil-supply limitation | MC-NUT01 | None |
| SW431-NUT-ORGANIC | Organic matter and organic nitrogen turnover/mineralisation | MC-NUT01 | None |
| SW431-DRAIN-ALLOCATION | Multilevel exchange allocation and drain/channel type | MC-DRAIN01 | SW431-DRAIN-DRAMET3 |
| SW431-DRAIN-DIV-MULTI | Multiple interacting discharge-layer partitions | MC-DRAIN01 | SW431-DRAIN-DIV-SIGNED |
| SW431-DRAIN-INF-SPLIT | Separate shallower infiltration spatial distribution | MC-DRAIN01 | SW431-DRAIN-DIV-SIGNED |
| SW431-IRR-SALTEXCESS | Sensor salt-threshold excess irrigation | MC-IRR01 | SW431-IRR-TCS7, SW431-IRR-TCS8 |
| SW431-ROOT-ANAE-GROW | Anaerobic suppression of root extension | MC-CROP01 | SW431-CROP-ROOTGROW |
| SW431-ROOT-LRV-CONSTANT | Force root length density from RDCTB using rooted-compartment depth | MC-CROP01 | SW431-ROOT-MICRO2 |
| SW431-FROST-SNOW | Snow-insulated sensible temperature driving empirical frost hydraulics | MC-FROST01 | SW431-TEMP-SNOW |
| SW431-HYD-RIA-VAPOR | RIA vapour/temperature-dependent conductivity and fitted dry-end relation | MC-HYD01 | SW431-HYD-MODEL12 |
| SW431-HYD-VAPOR | PDI vapour contribution to unsaturated conductivity | MC-HYD01 | SW431-HYD-MODEL8, SW431-HYD-MODEL9, SW431-HYD-MODEL10, SW431-HYD-MODEL11 |
| SW431-ROOT-MICRO-LIFT | Microscopic hydraulic lift/redistribution | MC-MICRO01 | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |
| SW431-ROOT-MICRO-STRESS | Microscopic oxygen/salinity reduction and stress attribution | MC-MICRO01 | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |
| SW431-ROOT-MICRO-TRED | MICRO transpiration-reduction and maximum-drought policy | MC-MICRO01 | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |
| SW431-CROP-ROOTGROW-SUPPLY | Minimum/root-drought-scaled extension limited by allocated root dry matter | MC-CROP01 | SW431-ROOT-DENSITY |
| SW431-TILL-CONSOL | Rain-forcing-driven post-tillage bulk-density consolidation | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-N1 | Keep n unchanged during density-induced hydraulic material update | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-N2 | Update n using silt/clay ratio and density ratio exponent | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-N3 | Update n with density matching-point slope and floor1.001 | MC-TILL01 | SW431-TILL-EVENT |
| SW431-NUT-AMEND | Fertilizer/manure applications and volatilisation | MC-NUT01 | SW431-NUT-MINERAL, SW431-NUT-ORGANIC |
| SW431-NUT-CROP | Demand/supply coupling and nitrogen-limited crop growth | MC-NUT01 | SW431-NUT-MINERAL |
| SW431-NUT-DENIT | Nitrate loss controlled by temperature, wetness and organic respiration activity | MC-NUT01 | SW431-NUT-MINERAL, SW431-NUT-ORGANIC |
| SW431-NUT-NITRIF | Temperature- and water-filled-pore-dependent ammonium-to-nitrate transformation | MC-NUT01 | SW431-NUT-MINERAL |
| SW431-NUT-RESIDUE | Crop residue transfers to organic soil pools | MC-NUT01 | SW431-NUT-ORGANIC |
| SW431-NUT-TRANSPORT | Analytical ammonium/nitrate concentration and outflow balance with sorption, boundary inputs and crop uptake | MC-NUT01 | SW431-NUT-MINERAL |
| SW431-FROST-DIV-MULTI | Multilevel frost spatial redistribution | MC-FROST01 | SW431-DRAIN-DIV-MULTI, SW431-FROST-DIVDRA |
| SW431-TILL-REDIST | Retain pressure head then redistribute weighted water after material change | MC-TILL01 | SW431-TILL-EVENT, SW431-TILL-N1, SW431-TILL-N2, SW431-TILL-N3 |
| SW431-TILL-REDIST1 | Keep water content with excess-to-pond redistribution after material change | MC-TILL01 | SW431-TILL-N1, SW431-TILL-N2, SW431-TILL-N3 |

## Registered review queue

These are individual capability decisions, not admitted implementation plans. Dependency depth orders prerequisites first; independent qualification reviews can reduce the queue before new physics work.

| Workunit | Open entries | Next action |
|---|---:|---|
| MC-CROP01 | 19 | Source/admission adjudication for the exact IDs below |
| MC-DRAIN01 | 8 | Source/admission adjudication for the exact IDs below |
| MC-FROST01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-HEAT01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-HYD01 | 15 | Source/admission adjudication for the exact IDs below |
| MC-HYST01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-IRR01 | 16 | Source/admission adjudication for the exact IDs below |
| MC-LOW01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-MACRO01 | 8 | Source/admission adjudication for the exact IDs below |
| MC-MACROSUR01 | 6 | Source/admission adjudication for the exact IDs below |
| MC-MET01 | 6 | Source/admission adjudication for the exact IDs below |
| MC-MICRO01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-NUT01 | 9 | Source/admission adjudication for the exact IDs below |
| MC-ROOT01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-SOL01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-SUR01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-SW01 | 7 | Source/admission adjudication for the exact IDs below |
| MC-TILL01 | 7 | Source/admission adjudication for the exact IDs below |
| PPA-WU05B19 | 1 | Source/admission adjudication for the exact IDs below |

### MC-CROP01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-CROP-ATTAINABLE | Attainable versus theoretical potential growth correction | RELFMF parameter and selector not established by ten-case crop-equivalence denominator | None |
| SW431-ROOT-DENSITY | Adaptive node root-biomass growth/death redistribution | Source retains node root biomass and partitions growth/death using FGWRT/FDWRT and current stress. Current admitted typed root inputs are consumers and do not evolve this accepted node inventory. | None |
| SW431-CROP-ROOTGROW-BIOMASS | Root depth from actual/potential root-biomass table | Source computes depth from WRTPOT/WRT and applies rdm. Typed WOFOST81 has root biomass but lacks an admitted biomass-to-depth/profile resolver. Functional replacement/source qualification must be adjudicated separately from a history-dependent extension owner. | None |
| SW431-CROP-ROOTGROW-DVS | Prescribed DVS-table root depth with soil-depth cap | Source rd=rdpot=min(AFGEN(RDTB,DVS),rdm) is stateless at update. Determine a qualified typed resolved root-profile replacement; do not infer its table/cap mapping from a root-distribution consumer alone. | None |
| SW431-CROP-ROOTGROW-WATER | Daily root extension scaled by actual/potential transpiration | No accepted root-depth owner applies rr*=IQROT/IPTRA with the source extension gates and actual/previous depth. Root uptake itself does not publish root-growth state. | None |
| SW431-CROP-ANNUAL | B1.11 annual-crop assimilation, biomass growth and calendar/thermal phenology | WOFOST81 is admitted against a separately modified 13B donor, not the bundled literal B1.11 crop equations. B1.11 uses DVS-dependent AMAXTB and older N/stress contracts; current81 uses leaf-N assimilation. Decide and demonstrate functional replacement, or qualify a separate source annual-crop envelope. Do not infer literal coverage from the shared SWAP431 label. | None |
| SW431-CROP-CO2 | Time-varying CO2 crop response and forcing | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-FIXED | Calendar-clock prescribed-LAI/root-biomass crop development and harvest | Source IDEV1 advances DVS by 2/LCC, accumulates TSUM, interpolates LAITB, and retains previous root biomass where applicable. Typed canopy/root views are consumers; the current admitted WOFOST81 owner does not implement this fixed-crop state update. | None |
| SW431-CROP-FIXED-THERMAL | Thermal-sum prescribed-LAI/root-biomass crop development and harvest | Source IDEV2 uses max(0,TAV-TBASE), TSUMEA before anthesis and TSUMAM after anthesis to advance DVS, then updates prescribed LAI/root biomass. Current typed views do not supply this independent accepted phenology state/evaluator. | None |
| SW431-CROP-GRASS | Grass regrowth, mowing and grazing | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-ROOTGROW | Accepted daily maximum-rate root-depth extension gated by transpiration and allocated root growth | Current crop owner/contracts carry biomass and supplied root-distribution views, not accepted rd/rdpot/rr evolution. Source SWRD2 requires previous depth, maximum daily increment and demand/allocated-root-growth gates. Neither admitted WOFOST81 crop state nor prescribed root-uptake tangent supplies this owner. | None |
| SW431-CROP-ROTATION | Multi-crop start/end/harvest accepted lifecycle | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-SOW | Soil-state-dependent preparation, sowing and germination | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-SOY | Soybean-specific phenology and photoperiod | Spring-barley potential-production crop-owned trajectories and event runtime do not qualify this whole source option; map exact supported replacement before final disposition | None |
| SW431-CROP-VERNAL | Temperature/daylength phenology with persistent vernalisation sum and completion flag | Current common rate parameters accept IDSL0/1 only and crop owners have no vern accumulation/completion state or vernalisation response operator. Typed daily daylength forcing does not replace this persistent temperature history. | None |
| SW431-CROP-WOF-OTHER | Annual crop daylength-dependent phenology | IDSL1 daylength algebra is implemented by the common crop parameter/finalizer route. Bounded classic-crop source/admission reconciliation remains; IDSL2 persistent vernalisation is a separate confirmed gap. | None |
| SW431-ROOT-ANAE-GROW | Anaerobic suppression of root extension | Source oxygen-growth suppression gates actual SWRD2 root extension when IALPWET_DAY<AERATECRIT; it does not gate SWRD1/3. No accepted current root-depth owner applies this daily wet-stress condition. | SW431-CROP-ROOTGROW |
| SW431-ROOT-LRV-CONSTANT | Force root length density from RDCTB using rooted-compartment depth | Production crop/Feddes contracts publish normalized cumulative root fractions, not absolute LRV. B1.11 rootextraction passes LRV_node into both MICRO initialization and uptake. Current canonical MICRO admission supplies only a matric-flux table, with no crop LRV resolver or runtime MICRO consumer binding. | SW431-ROOT-MICRO2 |
| SW431-CROP-ROOTGROW-SUPPLY | Minimum/root-drought-scaled extension limited by allocated root dry matter | No accepted root-depth owner applies the rrimin/extentcrit dry-stress response and grrt_needed supply cap based on deepest-node root biomass. This requires root-density/source growth state before qualification. | SW431-ROOT-DENSITY |

### MC-DRAIN01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-DRAIN-DISLAYER | Absolute or water-level-relative discharge-layer geometry | SWDISLAY1 uses supplied discharge-layer top; SWDISLAY2 derives it from groundwater/drain geometry and FTOPDISLAY. Both truncate and renormalize nodal fluxes. Current production positive DIVDRA parameter type has neither top-depth/fraction nor this redistribution operator. | None |
| SW431-DRAIN-DIV-SIGNED | Ordinary signed conductivity-weighted drainage distribution | Source default DIVDRA partitions negative as well as positive active level transfers; the admitted ordinary scalar-to-node runtime rejects negative transfers. B18 isolated signed frost component does not constitute ordinary runtime admission. | None |
| SW431-DRAIN-DIV-TOPINTERFLOW | Separate highest interflow discharge layer and lower-layer exclusion | Source partitions the highest interflow down to its physical drain bottom and starts all lower discharge layers below that boundary. Current ordinary positive DIVDRA has no highest-interflow selector or separate top-layer operator. This is distinct from B15 highest scalar response and from SWDISLAY top truncation. | None |
| SW431-DRAIN-DRAMET3 | Native signed resistance response with time-varying channel head and drain-bottom clamp | Native DRAMET3 resolves OWLTAB at t1900+dt-1, clamps to ZBOTDR and selects DRARES/INFRES by sign. Current admitted normalized response route consumes externally resolved control head; EXTENDED_SIGNED follows another source family and its activation/ponding rules differ. No typed source resolver plus qualified native signed resistance binding is present. | None |
| SW431-DRAIN-ALLOCATION | Multilevel exchange allocation and drain/channel type | SWALLO2 suppresses positive drainage; SWALLO3 suppresses negative infiltration per level. Current response-binding parameters have no direction selector. The one-way linear provider covers only its restricted positive branch; it does not execute the native selectable signed resistance dispatcher. | SW431-DRAIN-DRAMET3 |
| SW431-DRAIN-DIV-MULTI | Multiple interacting discharge-layer partitions | Source DIVDRA orders active drain levels and constructs distinct discharge layers before partitioning each level. Current ordinary runtime allocates exactly one level. Multilevel scalar aggregation with bottom-node lumping does not implement these interacting spatial partitions. | SW431-DRAIN-DIV-SIGNED |
| SW431-DRAIN-INF-LIMIT | Head-difference-limited drain/channel infiltration | SWLIMINF1 clips the negative DRAMET3 head difference at channel depth before dividing by INFRES. EXTENDED has a related GWLINF cap but also distinct 0.001cm activation, pond suppression and wet-perimeter rules; no source-bound mapping of this ordinary dispatcher is qualified. This is a resolver/envelope gap, not proof that capped infiltration algebra is absent. | SW431-DRAIN-DRAMET3 |
| SW431-DRAIN-INF-SPLIT | Separate shallower infiltration spatial distribution | Separate DRAMET3 infiltration partition uses unsaturated/saturated transmissivity and FACDPTHINF. The ordinary runtime binds positive single-level DIVDRA only; B18 contains a bounded signed scientific component but has no canonical runtime import. B19 is rootless frost runtime work and cannot silently close ordinary/general separate infiltration. | SW431-DRAIN-DIV-SIGNED |

### MC-FROST01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-FROST-EXT-MULTI | Multilevel extended surface-water/drain frost | Current extended/highest frost drain validation explicitly requires exactly one response level; legacy multilevel extended frost remains production-blocked. | None |
| SW431-FROST-GW | Frost with other legacy lower-boundary owners | Current frost admission requires bottom_mode==2. The other source-relevant lower-boundary frost compositions have no admitted runtime route. | None |
| SW431-FROST-ROOTDRAIN | Root uptake composed with frost drainage | Current frost drainage admission explicitly rejects root_extraction_active and root_frost.active. Admitted empirical root frost does not close its composition with ordinary/extended drainage. | None |
| SW431-FROST-SNOW | Snow-insulated sensible temperature driving empirical frost hydraulics | Legacy snow resistance changes the soil-interface temperature consumed by FrozenCond; current frost admission rejects snow_active, and the current numerical thermal owner also rejects snow. This needs the TEMP-SNOW route followed by bounded snow/frost ownership qualification. No ice or latent heat is implied. | SW431-TEMP-SNOW |
| SW431-FROST-DIV-MULTI | Multilevel frost spatial redistribution | The single-level B18 DIVDRA component is not backend-bound, so the source multilevel DIVDRA frost composition lacks both the prerequisite single-level runtime and multilevel owner binding. | SW431-DRAIN-DIV-MULTI, SW431-FROST-DIVDRA |

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
| SW431-IRR-AVAIL | External irrigation-availability scaling of selected event | No external F_IRR_AVAIL postselection scaling request or candidate event-duration update. Supplied gross irrigation forcing alone does not implement management availability. | None |
| SW431-IRR-DCS1 | Refill-to-field-capacity with under/over depth and rainfall deduction | No field-capacity deficit, DITAB under/over depth and conditional rainfall deduction request/evaluator. | None |
| SW431-IRR-FIXED-SPRINK | Fixed scheduled-date sprinkling | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | None |
| SW431-IRR-FREQ | Stress-triggered irrigation without minimum interval suppression | F-APP07 requires TCSFIX1 and positive minimum_interval_days; the source TCSFIX0 omits dayfix gating. Qualified TCS7 standalone component has no production binding and cannot close this scheduled no-interval route. | None |
| SW431-IRR-LIMIT | Minimum/maximum irrigation depth constraints | No DCSLIM minimum/maximum selected event depth parameters or postselection clamp. | None |
| SW431-IRR-RATE-CAP | Cap long scheduled irrigation events at one day while preserving depth | Source temporarily raises the rate to depth/day when requested duration exceeds one day. Current admitted TCS1 owner rejects duration>1 and never performs this adaptation. | None |
| SW431-IRR-RATE-DAILY | Spread scheduled irrigation depth uniformly over one day | Source zero-rate fallback selects daily depth as rate. Current admitted TCS1 owner requires strictly positive rate and does not implement this fallback. | None |
| SW431-IRR-SCHED-SURF | Scheduled surface irrigation routing | Requires source-bound typed event/cursor state and accepted water ownership beyond restricted F-APP07 | None |
| SW431-IRR-SSDI | Single-node or depth-interval subsurface drip irrigation | Restricted process exists and is independently qualified; production runtime binding is absent at the audited canonical head. | None |
| SW431-IRR-TCS2 | Readily available root-zone water depletion trigger | No RAWTAB or root-zone readily available water/depletion evaluator in current scheduling contracts. | None |
| SW431-IRR-TCS3 | Total available root-zone water depletion trigger | No TAWTAB or total available root-zone water/depletion evaluator in current scheduling contracts. | None |
| SW431-IRR-TCS4 | Absolute root-zone water depletion trigger | No DWATAB or absolute root-zone depletion evaluator in current scheduling contracts. | None |
| SW431-IRR-TCS6 | Weekly thresholded irrigation trigger | No weekly seven-day deficit clock and IRGTHRESHOLD evaluator in current scheduling contracts; minimum event interval is a different rule. | None |
| SW431-IRR-TCS7 | Pressure-head sensor trigger | Restricted process exists and is independently qualified; production runtime binding is absent at the audited canonical head. | None |
| SW431-IRR-TCS8 | Water-content sensor trigger | The scheduled component evaluates a pressure-head threshold (TCS7), not a theta sensor threshold TCRITAB. | None |
| SW431-IRR-SALTEXCESS | Sensor salt-threshold excess irrigation | No concentration-threshold sensor request or PERIRRSURP postselection depth increment. | SW431-IRR-TCS7, SW431-IRR-TCS8 |

### MC-LOW01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-LOW3-EXPLICIT | GWL and saturated-profile dependent explicit aquifer resistance exchange | Source evaluates (deepgw-[hdrain+shape_3*(gwl-hdrain)])/(rimlay+saturated_profile_resistance), plus optional SW4, at the prescribed endpoint. LOW03-A consumes the distinct implicit last-node Cauchy route. No production profile-resistance/SHAPE_3 resolver for the explicit variant exists; retain as a deliberate migration/scope decision, not a numerical-policy replacement. | None |
| SW431-LOW9 | Simultaneously imposed bottom flux and head with forced last-node head/theta/K reset | Source reader accepts independent DATE9A/HBOT9 and DATE9B/QBOT9. BoundBottom sets qbot and overwrites the final cell h/theta/K; HeadCalc solves only numnod-1 and Fluxes deliberately excludes mode9 from qbot reconstruction. No typed production mode9 route is admitted. This is a real state/flux ownership decision, not obsolete parser plumbing. | None |

### MC-MACRO01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-MACRO-ABS2 | Alternative unsaturated absorption route | Source SWABS=2 computes head/theta-dependent Diffusivity and updated absorption; current unsaturated request/evaluator provides only the SWABS=1 empirical sorption-history path, with no diffusivity field/operator. | None |
| SW431-MACRO-DARCY | Extra unsaturated Darcy exchange | The active source extra-Darcy operator uses current K(ic). Current preparation updates matrix theta/heads and sorption history but retains unsaturated conductivity from the immutable configuration; source-faithful dynamic-K binding is absent. Existing qualified fixture explicitly sets that coefficient to zero. | None |
| SW431-MACRO-GEOMETRY | Integrated depth-dependent static macropore capacity, IC subdomain topology and polygon diameter | The generic typed immutable geometry carries the resulting volumes, fractions, bottoms and diameter, with later covering/shrinkage admissions. The literal initialization integrates depth curves, splits cells at shape boundaries, lumps domains by endpoint and derives polygon diameter. Source-bound resolver/replacement qualification remains to establish whether this entire intended parameterization is functionally supplied. | None |
| SW431-MACRO-KINEMATIC | Kinematic-wave main bypass compartment propagation with exponent NKWT | Current factory fixes SWMBF1 and valid_for_nodes rejects any other value. SWMBF2 exclusion checks in the sorptivity/derivative components are compatibility guards, not the NKWT per-compartment wave/storage/flux operator; no NKWT carrier or propagation operator exists in this production route. | None |
| SW431-MACRO-SEP1 | Ernst seepage-face exchange with horizontal, vertical and radial resistance | Typed factory accepts SWSEP and positive horizontal conductivity; standard adapter reaches the saturated exchange component. Literal active seepage-face algebra passes 48 bounded cases at O0/O2. Existing A8 fixture uses SWSEP0 and zero horizontal conductivity, so it does not qualify active Ernst/Youngs branches. Production admission for this envelope remains unresolved, not proven absent algebra. | None |
| SW431-MACRO-SEP2 | Youngs seepage-potential geometry for saturated exchange | Typed factory accepts SWSEP and positive horizontal conductivity; standard adapter reaches the saturated exchange component. Literal active seepage-face algebra passes 48 bounded cases at O0/O2. Existing A8 fixture uses SWSEP0 and zero horizontal conductivity, so it does not qualify active Ernst/Youngs branches. Production admission for this envelope remains unresolved, not proven absent algebra. | None |
| SW431-MACRO-SORP1 | Parlange hydraulic diffusivity integration and fitting of sorptivity maximum/exponent | B1.11 PARLANGE integrates K/C against theta at initialization, fits Mpow and S0, then supplies the same power-law absorption/event operator used by empirical input. Current factory accepts precomputed maximum/alpha but has no typed hydraulic-query integration/fitting resolver. Missing work is stateless physical parameter derivation, not a new runtime sorptivity/event-history owner. | None |
| SW431-MACRO-POWM | Double convex/concave internal-catchment domain frequency distribution | SWPOWM changes only the static IC-frequency integral exponent Pm=1/PowM below SPoint, not a rate dispatcher. The runtime accepts resolved static_volume_cp/domain_fraction/potential_bottom_domain, but equivalence of the full source depth-curve mapping and topology must be demonstrated; accepting generic arrays alone does not establish that mapping. | SW431-MACRO-GEOMETRY |

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
| SW431-ET-PMDETAIL | Detailed-record Penman-Monteith atmospheric demand | Current PMdirect weather contract is daily min/max temperature and daily radiation. B1.11 detailed-record Penman-Monteith uses record radiation with n_metdetail scaling in both partitions; detailed interception source-window continuation does not implement this atmospheric demand calculation. | None |
| SW431-ET-PMTRAD | Traditional Penman-Monteith reference demand partition | Current weather-driven evaluator always uses PMdirect cover-scaled aerodynamic resistances and effective LAI. B1.11 traditional SWDIVIDE0 uses unscaled resistances, zero wet-soil resistance and different cover partition/crop-factor postprocessing; no selector/provider implements that branch. | None |
| SW431-ET-SOILFACTOR | Soil-factor conversion of potential soil evaporation | Current reference-ET demand parameters lack CFBS and the evaluator explicitly implements SWCFBS0. B1.11 SWCFBS1 changes only soil evaporation in reference-ET and traditional branches; scaling the common ET forcing would incorrectly also scale transpiration and pond evaporation. PMdirect rsoil resistance is a different physical option. | None |
| SW431-MET-RAIN1 | Within-day rainfall intensity distribution from RAINTB | Source resolves daily depth and seasonal intensity into a midnight-start pulse: duration=min(1,depth/intensity), actual rate=depth/duration. Typed interval rates can carry the resolved pulse, but no current RAINTB/day-of-year pulse resolver is present. Daily total alone does not preserve infiltration intensity. | None |
| SW431-MET-RAIN2 | Daily rainfall duration WET forcing | Source uses supplied daily WET duration and rate=depth/WET, with a rain-end time-step event and zero-rain intervals. Typed intervals can carry the result, but the native depth/duration resolver and its admitted forcing lifecycle are absent. | None |
| SW431-MET-RAIN3 | Separate detailed .rain rainfall forcing | Source converts interval rain amounts at ordered timestamps to piecewise constant rates, reconstructs daily totals, and clips hydraulic steps to rain events. Generic typed spans support resolved rates; source-equivalent mapping of end-stamped amounts, start clipping and daily interception/snow composition still needs qualification. | None |

### MC-MICRO01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-ROOT-MICRO2 | de Jong van Lier microscopic soil-root hydraulic extraction | Independent nonlinear MFLP/root-interface/xylem/leaf solver; not equivalent to Feddes or externally compensated MICRO; source-derived candidate/scratch/restart contract required | None |
| SW431-ROOT-MICRO3 | de Willigen microscopic soil-root hydraulic extraction | Independent nonlinear MFLP/root-interface/xylem/leaf solver; not equivalent to Feddes or externally compensated MICRO; source-derived candidate/scratch/restart contract required | None |
| SW431-ROOT-MICRO-LIFT | Microscopic hydraulic lift/redistribution | Canonical MICRO production support ends at the matric-flux table; there is no bound microscopic sink/soil-root potential owner, hence no signed-node hydraulic redistribution route. External net transpiration and internal water redistribution must be booked separately by one sink owner. | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |
| SW431-ROOT-MICRO-STRESS | Microscopic oxygen/salinity reduction and stress attribution | No canonical microscopic sink binding consumes the source SWO2ECT/SWALPTOT stress dispatch/attribution. The admitted macroscopic Feddes/Bartholomeus/salinity composition is not the source microscopic root-density/potential stress mechanism. | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |
| SW431-ROOT-MICRO-TRED | MICRO transpiration-reduction and maximum-drought policy | No canonical microscopic sink binding carries source SWTYPETRED1/2 and maximum-drought policy; the table component has neither transpiration-reduction dispatch nor root-potential sink evaluation. | SW431-ROOT-MICRO2, SW431-ROOT-MICRO3 |

### MC-NUT01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-NUT-MINERAL | Owned ammonium/nitrate inventory, sorption capacity and soil-supply limitation | No production Soil-N inventory/rate owner or accepted supply binding exists for this source capability. The admitted WOFOST81 transaction explicitly passes its complete nitrogen_request.soil_request as supply, preserving N-unlimited behavior; crop N algebra is present, but it does not execute this soil process or limited exchange. | None |
| SW431-NUT-NFIX | Biological nitrogen fixation as a separately booked crop N input | WOFOST81 fixation code and persistent nfix_total are present and component-tested, but the literal B1.11 wofostnut demand uses only vegetative deficits and DVS<DVSNLT plus RELTR>.01. WOFOST81 request includes new-growth/storage demand and lacks that old cutoff. Nonzero runtime qualification alone cannot establish source equivalence; explicit functional replacement/adjudication of these gates is required. | None |
| SW431-NUT-ORGANIC | Organic matter and organic nitrogen turnover/mineralisation | No production Soil-N inventory/rate owner or accepted supply binding exists for this source capability. The admitted WOFOST81 transaction explicitly passes its complete nitrogen_request.soil_request as supply, preserving N-unlimited behavior; crop N algebra is present, but it does not execute this soil process or limited exchange. | None |
| SW431-NUT-AMEND | Fertilizer/manure applications and volatilisation | No production Soil-N inventory/rate owner or accepted supply binding exists for this source capability. The admitted WOFOST81 transaction explicitly passes its complete nitrogen_request.soil_request as supply, preserving N-unlimited behavior; crop N algebra is present, but it does not execute this soil process or limited exchange. | SW431-NUT-MINERAL, SW431-NUT-ORGANIC |
| SW431-NUT-CROP | Demand/supply coupling and nitrogen-limited crop growth | No production Soil-N inventory/rate owner or accepted supply binding exists for this source capability. The admitted WOFOST81 transaction explicitly passes its complete nitrogen_request.soil_request as supply, preserving N-unlimited behavior; crop N algebra is present, but it does not execute this soil process or limited exchange. | SW431-NUT-MINERAL |
| SW431-NUT-DENIT | Nitrate loss controlled by temperature, wetness and organic respiration activity | No production Soil-N inventory/rate owner or accepted supply binding exists for this source capability. The admitted WOFOST81 transaction explicitly passes its complete nitrogen_request.soil_request as supply, preserving N-unlimited behavior; crop N algebra is present, but it does not execute this soil process or limited exchange. | SW431-NUT-MINERAL, SW431-NUT-ORGANIC |
| SW431-NUT-NITRIF | Temperature- and water-filled-pore-dependent ammonium-to-nitrate transformation | No production Soil-N inventory/rate owner or accepted supply binding exists for this source capability. The admitted WOFOST81 transaction explicitly passes its complete nitrogen_request.soil_request as supply, preserving N-unlimited behavior; crop N algebra is present, but it does not execute this soil process or limited exchange. | SW431-NUT-MINERAL |
| SW431-NUT-RESIDUE | Crop residue transfers to organic soil pools | No production Soil-N inventory/rate owner or accepted supply binding exists for this source capability. The admitted WOFOST81 transaction explicitly passes its complete nitrogen_request.soil_request as supply, preserving N-unlimited behavior; crop N algebra is present, but it does not execute this soil process or limited exchange. | SW431-NUT-ORGANIC |
| SW431-NUT-TRANSPORT | Analytical ammonium/nitrate concentration and outflow balance with sorption, boundary inputs and crop uptake | No production Soil-N inventory/rate owner or accepted supply binding exists for this source capability. The admitted WOFOST81 transaction explicitly passes its complete nitrogen_request.soil_request as supply, preserving N-unlimited behavior; crop N algebra is present, but it does not execute this soil process or limited exchange. | SW431-NUT-MINERAL |

### MC-ROOT01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-ROOT-OXYGEN-EMP | Empirical anaerobic/Feddes wet stress | Current Feddes process supplies drought-only reduction. Bartholomeus mode2/type1 admission does not admit the separate SWOXYGEN=1 wet-pressure-head reduction. | None |
| SW431-ROOT-OXYGEN-REPRO | Bartholomeus oxygen reproduction-function route | Actual FMR activation accepts oxygen_mode2 only with oxygen_type1; type2 reproduction functions have no production route. Existing physical Bartholomeus factors do not implement that separately selected response family. | None |

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
| SW431-SW-DRAIN-FEEDBACK | Accepted drainage receipt into surface-water storage and updated level back into drainage basis | The existing restricted surface-water primitive consumes configured nonnegative secondary_drainage_rate. Its actual runtime call does not derive that carrier from the accepted solver drainage receipt or return updated storage level as the next native drainage basis. Primitive admission is preserved; the native shared-carrier feedback binding is missing. | None |
| SW431-SW-MANAGEMENT | Automatic weir adjustment from groundwater/soil-head criteria | Source automatic-weir target depends on groundwater/air-volume/sensor phases, accepted adjustment periods and maximum drop rate using previous wlstar. Current restricted owner persists storage only and has fixed weir_head; no automatic-target state/dispatcher exists. | None |
| SW431-SW-MULTILEVEL | Multiple external water levels and exchange owners | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | None |
| SW431-SW-PRIMARY | Primary and secondary surface-water systems | Restricted fixed-weir and single-level Ribasim profile do not prove the complete legacy option; same-store replacement must demonstrate physical semantics | None |
| SW431-SW-QHR2 | Tabulated water-level/discharge rating relation | Current fixed-weir parameters contain rating_coefficient/exponent only and rating_rate is a power function. There are no QH discharge knots or current table-rating operator; source SWQHR2 uses fun_qhtab including automatic capacity and level/storage solve. | None |
| SW431-SW-SIGNED | Surface-water storage depletion by signed infiltration into soil | B1.11 permits signed qdrd in storage balance, including falling-dry/supply branches. Current primitive and backend configuration explicitly reject secondary_drainage_rate<0 (held-signed-route). The signed surface-water donor envelope is missing, independent of the already admitted external-head drainage infiltration operator. | None |
| SW431-SW-TOPRUNOFF | Top runoff routed into surface-water storage | Source runots enters the WLEVBAL storage balance. Current surface-water forcing contains only secondary_drainage_rate and supply_capacity_rate; the runtime calls it unchanged from configured forcing, with no accepted Richards runoff receipt binding. | None |

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
