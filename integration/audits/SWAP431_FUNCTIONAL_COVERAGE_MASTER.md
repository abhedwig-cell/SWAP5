# SWAP431 functional coverage master: recoverable review

Baseline: `78acf56f931763d2e1d4924b3dea0742f231d2e8`. Status: IN_PROGRESS. **Coverage is not closed; the denominator is not yet declared exhaustive.**

The ledger currently contains 243 entries: 81 bounded ADMITTED, 14 SUPERSEDED, 1 REJECTED, 20 NOT_APPLICABLE, 123 ACTIVE_MIGRATION and 4 QUALIFICATION_ONLY entries across 18 review/migration workunits.

All 123 ACTIVE_MIGRATION entries are currently marked as proven missing production implementation/binding. Four additional entries are QUALIFICATION_ONLY: the required evaluator/runtime code exists, but their source-bound runtime envelope or admission is not yet complete. Neither number is a final exhaustive missing-functionality count. Qualification-only is not admission and still blocks global coverage closure.

Admitted SWAP5 replacement foundations are listed separately and do not count as proof of literal B1.11 branch coverage.

The machine authority is `integration/audits/SWAP431_FUNCTIONAL_COVERAGE_MASTER.json`.
The exact source bundle and input-reader census are in `integration/audits/evidence/`.
The source findings and exclusion reasoning are in `SWAP431_SOURCE_REVIEW.md`.

## Qualification-only queue

The following entries are deliberately excluded from the missing-production-implementation count while remaining unresolved: `SW431-MACRO-SEP1`, `SW431-MACRO-SEP2`, `SW431-CROP-ANNUAL`, and `SW431-CROP-WOF-OTHER`. Their existing implementation and current evidence are retained in the machine ledger; the remaining gates are runtime-envelope/admission gates, not requests for duplicate production physics.

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
| SW431-IRR-FIXED-SPRINK | Fixed scheduled-date sprinkling | MC-IRR01 | None |
| SW431-IRR-FREQ | Stress-triggered irrigation without minimum interval suppression | MC-IRR01 | None |
| SW431-IRR-LIMIT | Minimum/maximum irrigation depth constraints | MC-IRR01 | None |
| SW431-IRR-RATE-CAP | Cap long scheduled irrigation events at one day while preserving depth | MC-IRR01 | None |
| SW431-IRR-RATE-DAILY | Spread scheduled irrigation depth uniformly over one day | MC-IRR01 | None |
| SW431-IRR-SCHED-SURF | Scheduled surface irrigation routing | MC-IRR01 | None |
| SW431-IRR-SSDI | Single-node or depth-interval subsurface drip irrigation | MC-IRR01 | None |
| SW431-IRR-TCS2 | Readily available root-zone water depletion trigger | MC-IRR01 | None |
| SW431-IRR-TCS3 | Total available root-zone water depletion trigger | MC-IRR01 | None |
| SW431-IRR-TCS4 | Absolute root-zone water depletion trigger | MC-IRR01 | None |
| SW431-IRR-TCS6 | Weekly thresholded irrigation trigger | MC-IRR01 | None |
| SW431-IRR-TCS7 | Pressure-head sensor trigger | MC-IRR01 | None |
| SW431-IRR-TCS8 | Water-content sensor trigger | MC-IRR01 | None |
| SW431-ROOT-DENSITY | Adaptive node root-biomass growth/death redistribution | MC-CROP01 | None |
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
| SW431-CROP-ROOTGROW-BIOMASS | Root depth from actual/potential root-biomass table | MC-CROP01 | None |
| SW431-CROP-ROOTGROW-DVS | Prescribed DVS-table root depth with soil-depth cap | MC-CROP01 | None |
| SW431-CROP-ROOTGROW-WATER | Daily root extension scaled by actual/potential transpiration | MC-CROP01 | None |
| SW431-ET-PMDETAIL | Detailed-record Penman-Monteith atmospheric demand | MC-MET01 | None |
| SW431-ET-PMTRAD | Traditional Penman-Monteith reference demand partition | MC-MET01 | None |
| SW431-ET-SOILFACTOR | Soil-factor conversion of potential soil evaporation | MC-MET01 | None |
| SW431-LOW9 | Simultaneously imposed bottom flux and head with forced last-node head/theta/K reset | MC-LOW01 | None |
| SW431-MACRO-ABS2 | Alternative unsaturated absorption route | MC-MACRO01 | None |
| SW431-MACRO-DARCY | Extra unsaturated Darcy exchange | MC-MACRO01 | None |
| SW431-MACRO-EVAP | Stateful evaporation with macropore surface input | MC-MACROSUR01 | None |
| SW431-MACRO-GEOMETRY | Integrated depth-dependent static macropore capacity, IC subdomain topology and polygon diameter | MC-MACRO01 | None |
| SW431-MACRO-KINEMATIC | Kinematic-wave main bypass compartment propagation with exponent NKWT | MC-MACRO01 | None |
| SW431-MACRO-POND | Pond-derived lateral macropore request and shared surface donor debit/return | MC-MACROSUR01 | None |
| SW431-MACRO-SNOW | Daily snow and transactional macropore top input | MC-MACROSUR01 | None |
| SW431-MACRO-SORP1 | Parlange hydraulic diffusivity integration and fitting of sorptivity maximum/exponent | MC-MACRO01 | None |
| SW431-MACRO-SW | Rapid drainage routed into internal fixed-weir surface-water storage | MC-MACROSUR01 | None |
| SW431-MACRO-SW-EXTERNAL | Rapid-drain/macropore interaction with externally prescribed surface-water level | MC-MACROSUR01 | None |
| SW431-MET-RAIN1 | Within-day rainfall intensity distribution from RAINTB | MC-MET01 | None |
| SW431-RUNOFF-NONLINEAR | Nonlinear surface-runoff power law and iterative ponding solution | MC-SUR01 | None |
| SW431-RUNON | Externally supplied lateral water entering soil surface | MC-SUR01 | None |
| SW431-SW-DRAIN-FEEDBACK | Accepted drainage receipt into surface-water storage and updated level back into drainage basis | MC-SW01 | None |
| SW431-SW-MANAGEMENT | Automatic weir adjustment from groundwater/soil-head criteria | MC-SW01 | None |
| SW431-SW-PRIMARY | Prescribed primary versus common secondary head and exchange routing | MC-SW01 | None |
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
| SW431-CROP-CO2 | Time-varying CO2 crop response and forcing | MC-CROP01 | None |
| SW431-CROP-FIXED | Calendar-clock prescribed-LAI/root-biomass crop development and harvest | MC-CROP01 | None |
| SW431-CROP-FIXED-THERMAL | Thermal-sum prescribed-LAI/root-biomass crop development and harvest | MC-CROP01 | None |
| SW431-CROP-GRASS | Grass regrowth, mowing and grazing | MC-CROP01 | None |
| SW431-CROP-ROOTGROW | Accepted daily maximum-rate root-depth extension gated by transpiration and allocated root growth | MC-CROP01 | None |
| SW431-CROP-SOW | Soil-state-dependent preparation, sowing and germination | MC-CROP01 | None |
| SW431-CROP-SOY | Soybean-specific phenology and photoperiod | MC-CROP01 | None |
| SW431-CROP-VERNAL | Temperature/daylength phenology with persistent vernalisation sum and completion flag | MC-CROP01 | None |
| SW431-NUT-MINERAL | Owned ammonium/nitrate inventory, sorption capacity and soil-supply limitation | MC-NUT01 | None |
| SW431-NUT-NFIX | Biological nitrogen fixation as a separately booked crop N input | MC-NUT01 | None |
| SW431-NUT-ORGANIC | Organic matter and organic nitrogen turnover/mineralisation | MC-NUT01 | None |
| SW431-CROP-ATTAINABLE | Selector-controlled RELMF correction of companion potential assimilation | MC-CROP01 | SW431-CROP-ANNUAL |
| SW431-DRAIN-ALLOCATION | Multilevel exchange allocation and drain/channel type | MC-DRAIN01 | SW431-DRAIN-DRAMET3 |
| SW431-DRAIN-DIV-MULTI | Multiple interacting discharge-layer partitions | MC-DRAIN01 | SW431-DRAIN-DIV-SIGNED |
| SW431-DRAIN-INF-LIMIT | Head-difference-limited drain/channel infiltration | MC-DRAIN01 | SW431-DRAIN-DRAMET3 |
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
| SW431-LOW3-EXPLICIT | GWL and saturated-profile dependent explicit aquifer resistance exchange | MC-LOW01 | SW431-GW-PROJECTION |
| SW431-MACRO-POWM | Double convex/concave internal-catchment domain frequency distribution | MC-MACRO01 | SW431-MACRO-GEOMETRY |
| SW431-MACRO-RUNON | External runon composition through the pond-derived macropore donor | MC-MACROSUR01 | SW431-RUNON, SW431-MACRO-POND |
| SW431-SW-MULTILEVEL | Common secondary storage depletion limiter across multiple drain levels | MC-SW01 | SW431-SW-DRAIN-FEEDBACK, SW431-SW-SIGNED |
| SW431-TILL-CONSOL | Rain-forcing-driven post-tillage bulk-density consolidation | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-N1 | Keep n unchanged during density-induced hydraulic material update | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-N2 | Update n using silt/clay ratio and density ratio exponent | MC-TILL01 | SW431-TILL-EVENT |
| SW431-TILL-N3 | Update n with density matching-point slope and floor1.001 | MC-TILL01 | SW431-TILL-EVENT |
| SW431-CROP-ROTATION | Multi-crop start/end/harvest accepted lifecycle | MC-CROP01 | SW431-CROP-ANNUAL |
| SW431-NUT-AMEND | Fertilizer/manure applications and volatilisation | MC-NUT01 | SW431-NUT-MINERAL, SW431-NUT-ORGANIC |
| SW431-NUT-CROP | Demand/supply coupling and nitrogen-limited crop growth | MC-NUT01 | SW431-NUT-MINERAL |
| SW431-NUT-DENIT | Nitrate loss controlled by temperature, wetness and organic respiration activity | MC-NUT01 | SW431-NUT-MINERAL, SW431-NUT-ORGANIC |
| SW431-NUT-NITRIF | Temperature- and water-filled-pore-dependent ammonium-to-nitrate transformation | MC-NUT01 | SW431-NUT-MINERAL |
| SW431-NUT-RESIDUE | Crop residue transfers to organic soil pools | MC-NUT01 | SW431-NUT-ORGANIC |
| SW431-NUT-TRANSPORT | Analytical ammonium/nitrate concentration and outflow balance with sorption, boundary inputs and crop uptake | MC-NUT01 | SW431-NUT-MINERAL |
| SW431-FROST-DIV-MULTI | Multilevel frost spatial redistribution | MC-FROST01 | SW431-DRAIN-DIV-MULTI |
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
| MC-LOW01 | 3 | Source/admission adjudication for the exact IDs below |
| MC-MACRO01 | 8 | Source/admission adjudication for the exact IDs below |
| MC-MACROSUR01 | 6 | Source/admission adjudication for the exact IDs below |
| MC-MET01 | 4 | Source/admission adjudication for the exact IDs below |
| MC-MICRO01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-NUT01 | 9 | Source/admission adjudication for the exact IDs below |
| MC-ROOT01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-SOL01 | 5 | Source/admission adjudication for the exact IDs below |
| MC-SUR01 | 2 | Source/admission adjudication for the exact IDs below |
| MC-SW01 | 7 | Source/admission adjudication for the exact IDs below |
| MC-TILL01 | 7 | Source/admission adjudication for the exact IDs below |

### MC-CROP01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-ROOT-DENSITY | Adaptive node root-biomass growth/death redistribution | Source retains node root biomass and partitions growth/death using FGWRT/FDWRT and current stress. Current admitted typed root inputs are consumers and do not evolve this accepted node inventory. | None |
| SW431-CROP-ROOTGROW-BIOMASS | Root depth from actual/potential root-biomass table | Source RLWTB-to-depth derivation with separate actual/potential root biomass and maximum-depth clipping has no bound typed resolver. | None |
| SW431-CROP-ROOTGROW-DVS | Prescribed DVS-table root depth with soil-depth cap | Source min(AFGEN(RDTB,DVS),RDM) depth derivation has no bound typed resolver. Supplied cumulative-root-fraction input does not provide this mapping. | None |
| SW431-CROP-ROOTGROW-WATER | Daily root extension scaled by actual/potential transpiration | No accepted root-depth owner applies rr*=IQROT/IPTRA with the source extension gates and actual/previous depth. Root uptake itself does not publish root-growth state. | None |
| SW431-CROP-ANNUAL | B1.11 annual-crop assimilation, biomass growth and calendar/thermal phenology | Classic AMAXTB route exists and F-WOF38/39 preservation passes. MC-CROP01 must qualify literal B1.11 actual daily/seasonal crop trajectories and accepted-event/restart state; distinct WOFOST81 donor admission does not supply this classic source gate. Root extension, Soil-N and potential RELMF remain separate capabilities. | None |
| SW431-CROP-CO2 | Time-varying CO2 crop response and forcing | MIGRATE a typed CO2AMAXTB/CO2EFFTB/CO2TRATB response resolver and consistent crop/ET forcing binding. Current assimilation consumes resolved factors and F-WOF43A computes only transpiration response. Caller may supply the selected annual concentration without a legacy file/calendar owner. | None |
| SW431-CROP-FIXED | Calendar-clock prescribed-LAI/root-biomass crop development and harvest | Source IDEV1 advances DVS by 2/LCC, accumulates TSUM, interpolates LAITB, and retains previous root biomass where applicable. Typed canopy/root views are consumers; the current admitted WOFOST81 owner does not implement this fixed-crop state update. | None |
| SW431-CROP-FIXED-THERMAL | Thermal-sum prescribed-LAI/root-biomass crop development and harvest | Source IDEV2 uses max(0,TAV-TBASE), TSUMEA before anthesis and TSUMAM after anthesis to advance DVS, then updates prescribed LAI/root biomass. Current typed views do not supply this independent accepted phenology state/evaluator. | None |
| SW431-CROP-GRASS | Grass regrowth, mowing and grazing | Current crop owner and transaction lack mowing/grazing biomass-removal operators, cutting counters and regrowth-delay state. Daily event receipt retirement is not agro-management. | None |
| SW431-CROP-ROOTGROW | Accepted daily maximum-rate root-depth extension gated by transpiration and allocated root growth | Current crop owner/contracts carry biomass and supplied root-distribution views, not accepted rd/rdpot/rr evolution. Source SWRD2 requires previous depth, maximum daily increment and demand/allocated-root-growth gates. Neither admitted WOFOST81 crop state nor prescribed root-uptake tangent supplies this owner. | None |
| SW431-CROP-SOW | Soil-state-dependent preparation, sowing and germination | Current inactive crop disallows continuation state and no application owner stores preparation/sowing delays or thermal/moisture germination progress. | None |
| SW431-CROP-SOY | Soybean-specific phenology and photoperiod | B1.11 nonlinear short-day soybean temperature and maturity-group/explicit photoperiod dispatcher is absent from the current thermal-sum/linear long-day IDSL0/1 finalizer. | None |
| SW431-CROP-VERNAL | Temperature/daylength phenology with persistent vernalisation sum and completion flag | Current common rate parameters accept IDSL0/1 only and crop owners have no vern accumulation/completion state or vernalisation response operator. Typed daily daylength forcing does not replace this persistent temperature history. | None |
| SW431-CROP-ATTAINABLE | Selector-controlled RELMF correction of companion potential assimilation | Actual RELMF multiplication is implemented. Source SWPOTRELMF2 additionally scales a companion potential assimilation trajectory; current classic owner/result carries actual state/actual_pgass only. The selectable potential-path owner/policy is missing. | SW431-CROP-ANNUAL |
| SW431-ROOT-ANAE-GROW | Anaerobic suppression of root extension | Source oxygen-growth suppression gates actual SWRD2 root extension when IALPWET_DAY<AERATECRIT; it does not gate SWRD1/3. No accepted current root-depth owner applies this daily wet-stress condition. | SW431-CROP-ROOTGROW |
| SW431-ROOT-LRV-CONSTANT | Force root length density from RDCTB using rooted-compartment depth | Production crop/Feddes contracts publish normalized cumulative root fractions, not absolute LRV. B1.11 rootextraction passes LRV_node into both MICRO initialization and uptake. Current canonical MICRO admission supplies only a matric-flux table, with no crop LRV resolver or runtime MICRO consumer binding. | SW431-ROOT-MICRO2 |
| SW431-CROP-ROOTGROW-SUPPLY | Minimum/root-drought-scaled extension limited by allocated root dry matter | No accepted root-depth owner applies the rrimin/extentcrit dry-stress response and grrt_needed supply cap based on deepest-node root biomass. This requires root-density/source growth state before qualification. | SW431-ROOT-DENSITY |
| SW431-CROP-ROTATION | Multi-crop start/end/harvest accepted lifecycle | MIGRATE accepted seasonal crop-parameter/state transitions with preserved soil state. F-WOF39 retires a consumed daily event; it does not initialize the next seasonal crop or own a crop/fallow schedule. Start with prescribed emergence; automatic sowing is separate. | SW431-CROP-ANNUAL |
| SW431-CROP-WOF-OTHER | Annual crop daylength-dependent phenology | IDSL1 algebra exists in the common rate finalizer. MC-CROP01 must extend the source-bound classic annual runtime gate across DLC/DLO and anthesis; IDSL2 is separate persistent history. | SW431-CROP-ANNUAL |

### MC-DRAIN01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-DRAIN-DISLAYER | Absolute or water-level-relative discharge-layer geometry | SWDISLAY1 uses supplied discharge-layer top; SWDISLAY2 derives it from groundwater/drain geometry and FTOPDISLAY. Both truncate and renormalize nodal fluxes. Current production positive DIVDRA parameter type has neither top-depth/fraction nor this redistribution operator. | None |
| SW431-DRAIN-DIV-SIGNED | Ordinary signed conductivity-weighted drainage distribution | B19 now supplies a qualified signed/separate-infiltration runtime, but requires active frost and sensible temperature. The ordinary no-frost runtime still binds positive-only single-level DIVDRA; the B19 configuration validator rejects frost-off. Reuse B19 algebra/ownership contracts for the ordinary successor, without silently extending admission. | None |
| SW431-DRAIN-DIV-TOPINTERFLOW | Separate highest interflow discharge layer and lower-layer exclusion | Source partitions the highest interflow down to its physical drain bottom and starts all lower discharge layers below that boundary. Current ordinary positive DIVDRA has no highest-interflow selector or separate top-layer operator. This is distinct from B15 highest scalar response and from SWDISLAY top truncation. | None |
| SW431-DRAIN-DRAMET3 | Native signed resistance response with time-varying channel head and drain-bottom clamp | Native DRAMET3 resolves OWLTAB at t1900+dt-1, clamps to ZBOTDR and selects DRARES/INFRES by sign. Current admitted normalized response route consumes externally resolved control head; EXTENDED_SIGNED follows another source family and its activation/ponding rules differ. No typed source resolver plus qualified native signed resistance binding is present. | None |
| SW431-DRAIN-ALLOCATION | Multilevel exchange allocation and drain/channel type | SWALLO2 suppresses positive drainage; SWALLO3 suppresses negative infiltration per level. Current response-binding parameters have no direction selector. The one-way linear provider covers only its restricted positive branch; it does not execute the native selectable signed resistance dispatcher. | SW431-DRAIN-DRAMET3 |
| SW431-DRAIN-DIV-MULTI | Multiple interacting discharge-layer partitions | Source DIVDRA orders active drain levels and constructs distinct discharge layers before partitioning each level. Current ordinary runtime allocates exactly one level. Multilevel scalar aggregation with bottom-node lumping does not implement these interacting spatial partitions. | SW431-DRAIN-DIV-SIGNED |
| SW431-DRAIN-INF-LIMIT | Head-difference-limited drain/channel infiltration | MIGRATE the SWLIMINF channel-depth cap within native DRAMET3 negative-head dispatch. Related EXTENDED cap algebra exists but its independent activation seam prevents blanket replacement. Depends on the source DRAMET3 resolver, not new EXTENDED physics. | SW431-DRAIN-DRAMET3 |
| SW431-DRAIN-INF-SPLIT | Separate shallower infiltration spatial distribution | B19 now supplies a qualified signed/separate-infiltration runtime, but requires active frost and sensible temperature. The ordinary no-frost runtime still binds positive-only single-level DIVDRA; the B19 configuration validator rejects frost-off. Reuse B19 algebra/ownership contracts for the ordinary successor, without silently extending admission. | SW431-DRAIN-DIV-SIGNED |

### MC-FROST01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-FROST-EXT-MULTI | Multilevel extended surface-water/drain frost | Current extended/highest frost drain validation explicitly requires exactly one response level; legacy multilevel extended frost remains production-blocked. | None |
| SW431-FROST-GW | Frost with other legacy lower-boundary owners | Current frost admission requires bottom_mode==2. The other source-relevant lower-boundary frost compositions have no admitted runtime route. | None |
| SW431-FROST-ROOTDRAIN | Root uptake composed with frost drainage | Current frost drainage admission explicitly rejects root_extraction_active and root_frost.active. Admitted empirical root frost does not close its composition with ordinary/extended drainage. | None |
| SW431-FROST-SNOW | Snow-insulated sensible temperature driving empirical frost hydraulics | Legacy snow resistance changes the soil-interface temperature consumed by FrozenCond; current frost admission rejects snow_active, and the current numerical thermal owner also rejects snow. This needs the TEMP-SNOW route followed by bounded snow/frost ownership qualification. No ice or latent heat is implied. | SW431-TEMP-SNOW |
| SW431-FROST-DIV-MULTI | Multilevel frost spatial redistribution | B19 admits the single-level runtime foundation. Interacting multilevel DIVDRA and its frost nodal/bottom composition remain unimplemented; scalar multilevel response is not spatial redistribution. | SW431-DRAIN-DIV-MULTI |

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
| SW431-IRR-FIXED-SPRINK | Fixed scheduled-date sprinkling | MIGRATE fixed-event sprinkler-to-interception composition and qualify accepted event progress. Existing fixed process/state and nonintercepting identity binding are present. Missing intercepted binding must reuse them; no new duplicate event cursor is required. | None |
| SW431-IRR-FREQ | Stress-triggered irrigation without minimum interval suppression | F-APP07 requires TCSFIX1 and positive minimum_interval_days; the source TCSFIX0 omits dayfix gating. Qualified TCS7 standalone component has no production binding and cannot close this scheduled no-interval route. | None |
| SW431-IRR-LIMIT | Minimum/maximum irrigation depth constraints | No DCSLIM minimum/maximum selected event depth parameters or postselection clamp. | None |
| SW431-IRR-RATE-CAP | Cap long scheduled irrigation events at one day while preserving depth | Source temporarily raises the rate to depth/day when requested duration exceeds one day. Current admitted TCS1 owner rejects duration>1 and never performs this adaptation. | None |
| SW431-IRR-RATE-DAILY | Spread scheduled irrigation depth uniformly over one day | Source zero-rate fallback selects daily depth as rate. Current admitted TCS1 owner requires strictly positive rate and does not implement this fallback. | None |
| SW431-IRR-SCHED-SURF | Scheduled surface irrigation routing | MIGRATE the explicit nonintercepted scheduled-surface application binding, first for existing TCS1/DCS2. Current scheduled binding always marks Rutter input intercepted; fixed surface identity is not a scheduled lifecycle admission. | None |
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
| SW431-LOW9 | Simultaneously imposed bottom flux and head with forced last-node head/theta/K reset | Source reader accepts independent DATE9A/HBOT9 and DATE9B/QBOT9. BoundBottom sets qbot and overwrites the final cell h/theta/K; HeadCalc solves only numnod-1 and Fluxes deliberately excludes mode9 from qbot reconstruction. No typed production mode9 route is admitted. This is a real state/flux ownership decision, not obsolete parser plumbing. | None |
| SW431-LOW3-EXPLICIT | GWL and saturated-profile dependent explicit aquifer resistance exchange | Source evaluates (deepgw-[hdrain+shape_3*(gwl-hdrain)])/(rimlay+saturated_profile_resistance), plus optional SW4, at the prescribed endpoint. LOW03-A consumes the distinct implicit last-node Cauchy route. No production profile-resistance/SHAPE_3 resolver for the explicit variant exists; retain as a deliberate migration/scope decision, not a numerical-policy replacement. | SW431-GW-PROJECTION |

### MC-MACRO01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-MACRO-ABS2 | Alternative unsaturated absorption route | Source SWABS=2 computes head/theta-dependent Diffusivity and updated absorption; current unsaturated request/evaluator provides only the SWABS=1 empirical sorption-history path, with no diffusivity field/operator. | None |
| SW431-MACRO-DARCY | Extra unsaturated Darcy exchange | The active source extra-Darcy operator uses current K(ic). Current preparation updates matrix theta/heads and sorption history but retains unsaturated conductivity from the immutable configuration; source-faithful dynamic-K binding is absent. Existing qualified fixture explicitly sets that coefficient to zero. | None |
| SW431-MACRO-GEOMETRY | Integrated depth-dependent static macropore capacity, IC subdomain topology and polygon diameter | Current geometry validates supplied static volume/fraction/bottom/diameter arrays. B1.11 depth-curve cell splitting, integration, domain lumping and diameter derivation have no bound typed resolver; reuse existing immutable geometry after adding this parameterization. | None |
| SW431-MACRO-KINEMATIC | Kinematic-wave main bypass compartment propagation with exponent NKWT | Current factory fixes SWMBF1 and valid_for_nodes rejects any other value. SWMBF2 exclusion checks in the sorptivity/derivative components are compatibility guards, not the NKWT per-compartment wave/storage/flux operator; no NKWT carrier or propagation operator exists in this production route. | None |
| SW431-MACRO-SEP1 | Ernst seepage-face exchange with horizontal, vertical and radial resistance | Existing active seepage branch now executes in the real Reference/macropore transaction: positive-K mode2 partial-top-cell smoke passes at O0/O2 with committed-state isolation, positive distinct Ernst/Youngs exchange and closed water mass. Full-top geometry, capacity exhaustion, changed-forcing retry, fresh-process restart and coupled source-trajectory gates remain MC-MACRO01; no new admission. | None |
| SW431-MACRO-SEP2 | Youngs seepage-potential geometry for saturated exchange | Existing active seepage branch now executes in the real Reference/macropore transaction: positive-K mode2 partial-top-cell smoke passes at O0/O2 with committed-state isolation, positive distinct Ernst/Youngs exchange and closed water mass. Full-top geometry, capacity exhaustion, changed-forcing retry, fresh-process restart and coupled source-trajectory gates remain MC-MACRO01; no new admission. | None |
| SW431-MACRO-SORP1 | Parlange hydraulic diffusivity integration and fitting of sorptivity maximum/exponent | B1.11 PARLANGE integrates K/C against theta at initialization, fits Mpow and S0, then supplies the same power-law absorption/event operator used by empirical input. Current factory accepts precomputed maximum/alpha but has no typed hydraulic-query integration/fitting resolver. Missing work is stateless physical parameter derivation, not a new runtime sorptivity/event-history owner. | None |
| SW431-MACRO-POWM | Double convex/concave internal-catchment domain frequency distribution | B1.11 SWPOWM1 changes the lower Ic depth-curve integral exponent to 1/PowM. Current geometry consumes resolved arrays but has no SWPOWM/depth-curve resolver. Migrate this alternative after the base static-geometry resolver. | SW431-MACRO-GEOMETRY |

### MC-MACROSUR01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-MACRO-EVAP | Stateful evaporation with macropore surface input | Current macropore admission explicitly rejects both black_evaporation_active and boesten_evaporation_active, and top ingestion repeats those guards. | None |
| SW431-MACRO-POND | Pond-derived lateral macropore request and shared surface donor debit/return | MIGRATE the source pond-derived lateral request (PndmxMp/KsMpSs, coupled surface head and donor cap) and accepted surface debit/returned-input binding. A9 already partitions supplied lateral input and limits macro capacity; those operators must be reused. | None |
| SW431-MACRO-SNOW | Daily snow and transactional macropore top input | Current macropore admission explicitly rejects snow_active; the macropore top-forcing ingestion also rejects a supplied input composed with snow. | None |
| SW431-MACRO-SW | Rapid drainage routed into internal fixed-weir surface-water storage | Current macropore admission requires fixed_weir_surface_water_active=false and drainage_response_active=false; legacy internal surface-water storage receives QRapDra in WLEVBAL. This owner composition is production-blocked. | None |
| SW431-MACRO-SW-EXTERNAL | Rapid-drain/macropore interaction with externally prescribed surface-water level | MIGRATE an immutable time-varying open-channel rapid-drain basis carrier. Current factory sets a static template drain level; the adapter updates macro water level and volume-under-drain but does not bind a new interval drain basis. Reuse existing static rapid drainage and receipt. | None |
| SW431-MACRO-RUNON | External runon composition through the pond-derived macropore donor | MIGRATE runon into the shared surface donor before pond-derived macro transfer. Source headcalc adds runon to q0 after direct rain/irrigation/melt partition; no independent direct macro runon source is implied. Requires the ordinary runon carrier and pond/macro donor binding. | SW431-RUNON, SW431-MACRO-POND |

### MC-MET01

| Capability | Meaning | Why unresolved | Dependencies |
|---|---|---|---|
| SW431-ET-PMDETAIL | Detailed-record Penman-Monteith atmospheric demand | Current PMdirect weather contract is daily min/max temperature and daily radiation. B1.11 detailed-record Penman-Monteith uses record radiation with n_metdetail scaling in both partitions; detailed interception source-window continuation does not implement this atmospheric demand calculation. | None |
| SW431-ET-PMTRAD | Traditional Penman-Monteith reference demand partition | Current weather-driven evaluator always uses PMdirect cover-scaled aerodynamic resistances and effective LAI. B1.11 traditional SWDIVIDE0 uses unscaled resistances, zero wet-soil resistance and different cover partition/crop-factor postprocessing; no selector/provider implements that branch. | None |
| SW431-ET-SOILFACTOR | Soil-factor conversion of potential soil evaporation | Current reference-ET demand parameters lack CFBS and the evaluator explicitly implements SWCFBS0. B1.11 SWCFBS1 changes only soil evaporation in reference-ET and traditional branches; scaling the common ET forcing would incorrectly also scale transpiration and pond evaporation. PMdirect rsoil resistance is a different physical option. | None |
| SW431-MET-RAIN1 | Within-day rainfall intensity distribution from RAINTB | Source resolves daily depth and seasonal intensity into a midnight-start pulse: duration=min(1,depth/intensity), actual rate=depth/duration. Typed interval rates can carry the resolved pulse, but no current RAINTB/day-of-year pulse resolver is present. Daily total alone does not preserve infiltration intensity. | None |

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
| SW431-NUT-NFIX | Biological nitrogen fixation as a separately booked crop N input | Biological fixation exists in WOFOST81. The B1.11 selectable demand policy with vegetative deficits, DVSNLT cutoff and RELTR gate is missing. Literal O0/O2 witnesses show distinct storage-demand, new-growth and cutoff outcomes; implement a separate policy without altering admitted WOFOST81 semantics. | None |
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
| SW431-SALT-DECAY | Temperature/moisture/depth modified decomposition | Aquifer concentration/storage owner is absent. Literal B1.11 SWBR block also has a reproduced numnod+1 array access after the compartment loop. MC-SOL01 must establish the corrected physical storage/coefficient and substep mass contract under reference-defect policy before implementation. | None |
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
| SW431-SW-PRIMARY | Prescribed primary versus common secondary head and exchange routing | Source levels <=NRPRI use prescribed primary WLP; others use common secondary WLS and alone enter QDRD. Existing per-level response controls and scalar aggregator have no native typed primary/secondary group routing and receipt ownership binding. | None |
| SW431-SW-QHR2 | Tabulated water-level/discharge rating relation | Current fixed-weir parameters contain rating_coefficient/exponent only and rating_rate is a power function. There are no QH discharge knots or current table-rating operator; source SWQHR2 uses fun_qhtab including automatic capacity and level/storage solve. | None |
| SW431-SW-SIGNED | Surface-water storage depletion by signed infiltration into soil | B1.11 permits signed qdrd in storage balance, including falling-dry/supply branches. Current primitive and backend configuration explicitly reject secondary_drainage_rate<0 (held-signed-route). The signed surface-water donor envelope is missing, independent of the already admitted external-head drainage infiltration operator. | None |
| SW431-SW-TOPRUNOFF | Top runoff routed into surface-water storage | Source runots enters the WLEVBAL storage balance. Current surface-water forcing contains only secondary_drainage_rate and supply_capacity_rate; the runtime calls it unchanged from configured forcing, with no accepted Richards runoff receipt binding. | None |
| SW431-SW-MULTILEVEL | Common secondary storage depletion limiter across multiple drain levels | Source multiple secondary drain levels share one storage. Its falling-dry branch scales every secondary-level exchange using net QDRD and available storage+supply. Current scalar aggregator has no common-store limiter; restricted fixed-weir input rejects negative secondary exchange. Native grouped signed feedback/receipts are missing. | SW431-SW-DRAIN-FEEDBACK, SW431-SW-SIGNED |

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

## Closure gate

Run `python tools/audits/check_swap431_coverage.py` for structural/source integrity.
Run `python tools/audits/check_swap431_coverage.py --require-closed` for a closure assertion.
SW431-GW-PROJECTION was qualified on run 37578999251 and admitted into the master-coverage branch through PR #1085. The latter intentionally fails while the source denominator is incomplete or any ACTIVE_MIGRATION remains.
Neither command scientifically qualifies a process. Owning source/runtime gates and canonical admission remain required.

No final global rejection has been invented to shrink the queue. No historical research PR is a blocker merely because it is open. The historical complete paginated snapshot records 114 open PRs and 55 merges since 2026-10-05; migration proposal reconciliation is explicit. The earlier 100-item snapshot is retained as historical evidence.

## Latest resolved-input and owner review

SWRAIN2 WET duration and SWRAIN3 interval amounts are SUPERSEDED as input representations by admitted immutable precipitation spans. No legacy parser or new snow/interception composition is claimed.

Macropore static geometry and SWPOWM, the B1.11 N-demand policy, companion potential RELMF, primary/secondary routing and the common-secondary-store multilevel limiter now have explicit MIGRATE decisions and bounded contracts.

Details: [resolved input and owner review](SWAP431_RESOLVED_INPUT_AND_OWNER_REVIEW.md). The literal rain mapping and N-demand discrimination probes passed O0/O2. Production source remains unchanged.

## Surface, crop and solute follow-up

Eight further owner reviews now have concrete MIGRATE contracts: pond-derived macro input, runon composition, time-varying rapid-drain basis, fixed sprinkler and scheduled surface routing, consistent CO2 response, crop rotation and the ordinary infiltration cap.

The four existing-code entries have explicit source/runtime qualification gates: Ernst, Youngs, classic annual crop and IDSL1. No absent-evaluator claim is made for those entries.

The literal SWBR aquifer block fails bounds checks at numnod+1 in all eight O0/O2 probes. Its intended physical capability remains open with a reference-correction prerequisite. Soil phase-change absence is distinguished from the admitted snow liquid-retention and melting terms.

Details: [surface and crop owner review](SWAP431_SURFACE_AND_CROP_OWNER_REVIEW.md).

## Groundwater source reconciliation

The fixed-interface external groundwater admission does not close every internal CALCGWL branch. MC-LOW01 now separately owns the general candidate profile-to-GWL binding; its explicit mode-3 successor depends on that resolver. The unreachable internal gwlevel option 2 is NOT_APPLICABLE, while PERCH21 retains its bounded perched-zone admission.

Six unchanged-source/current-service comparisons per O0/O2 distinguish the admitted smooth interior service from full saturation, zero-pressure and absent-interior cases. Details: [groundwater source review](SWAP431_GROUNDWATER_SOURCE_REVIEW.md).
