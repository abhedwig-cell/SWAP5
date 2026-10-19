# Kalmthoutse Heide SWAP regional runs

Technical construction and output metadata for the first provisional version

SYMPHONICA technical note | V02 | 19 October 2026

## 1 Purpose and status

We have constructed and executed a first regional SWAP application for the Kalmthoutse Heide and its surroundings. The application covers the existing 16 km by 16 km pilot domain with 4,096 independent soil columns on a 250 m grid. Every column covers 1 January 2024 to 1 October 2026, inclusive, and uses hourly meteorological forcing. V02 adds numerical soil heat transport, WOFOST grass and a WOFOST maize proxy to the locally refined regional baseline. It delivers the requested daily water balance components, gross crop assimilation, groundwater level where available, soil moisture and soil temperature.

This is a technical exercise and a first provisional version. Its purpose is to establish an executable, traceable regional workflow and a usable output structure. The model has not been calibrated to the area or independently validated against observations. Completion checks establish that the stated input files were executed and that the delivered arrays agree with the native output within the declared conversions. They do not establish that the parameter estimates, boundary conditions or regional water balance describe the real system accurately.

We intend to connect this workflow to the standard datasets being collected and made accessible within SYMPHONICA. The current input stack is an exploratory combination of existing forcing, European spatial products, local habitat information and explicit parameter assumptions. Alignment with the project data structures, accepted source versions and delivery conventions remains to be implemented and checked. No claim of conformity to an unseen project schema is made.

The calculations use SWAP 4.3.1. The presence of these files in the SWAP5 repository is an arrangement for version control and recovery. These runs do not constitute SWAP5 solver qualification or canonical admission. No SWAP5 numerical implementation or shared runtime interface is changed by this work.

## 2 Version lineage and delivery identity

The regional V01 baseline contains a WorldCover reference, a European heath refinement and a further local heath refinement. These versions share unchanged columns through relative links. The European refinement selects 156 heath columns. Local habitat information adds 73, giving 229 heath columns in the locally refined baseline. The original reference contains 4,096 native columns and the vegetation changes require 229 additional native executions. The three model views must not be counted as three independent sets of 4,096 executions.

V02 starts from the complete V01 model_local view. It retains its soil assignments, cell geometry, vegetation classification and lower boundary assumptions. It replaces the prescribed grass and agricultural crop routes with dynamic crop models, activates numerical heat in all columns, and expands the daily output. V02 is one full regional model. There is no separately executed V02 European comparator in this delivery. Earlier European and local comparison maps and balances remain V01 results.

The Git starting point for this continuation is commit a06fbf0977be001dee69457ba590685e40bf86bc on research/kalmthout-baseline250-20261018. The V02 work is preserved separately on research/kalmthout-v02-wofost-heat-20261019. The model inputs and numerical results were already complete before this documentation and preservation phase. Their original bytes and receipt identities are retained.

| Item | Identity or value |
| --- | --- |
| Model version | V02_LOCAL_WOFOST_NUMERICAL_HEAT |
| Native model | SWAP 4.3.1 with an explicit GNU output portability correction |
| Period | 2024-01-01 through 2026-10-01 inclusive |
| Daily simulation intervals | 1,005 per cell, 4,116,480 cell days |
| Initial native output record | 2023-12-31, excluded from daily NetCDF intervals |
| Columns with unflagged completion | 2,395 |
| Columns with explicit canopy accounting flags | 1,701 |
| Failed columns in final delivery | 0 |
| Native CSV total | 1,027,758,549 bytes |
| Annual NetCDF total | 270,142,214 bytes |
| V02 recovery archive | 370,141,004 bytes |
| Complete V01 recovery archive | 123,257,020 bytes |

Historical preparation receipts retain their original stage labels, including PREPARED_NOT_YET_EXECUTED. They are not evidence of incomplete current output. Current execution summaries, per-cell V02 run receipts, delivery_validation_v02.json and the complete file manifests establish the final delivered state. A reader should use these authorities rather than infer execution status from a historical preparation field.

## 3 Domain and spatial representation

### 3 1 Extent and coordinate system

The model uses the supplied minimal pilot extent. It includes the surrounding landscape and is not a polygon mask of the nature reserve. Its area is 256 km². The supplied larger extent, 40 km by 41 km, has not been simulated in this regional version.

| Property | Value |
| --- | --- |
| Coordinate reference system | EPSG:32631, WGS 84 UTM zone 31N |
| Western and eastern boundary | 592980 m and 608980 m easting |
| Southern and northern boundary | 5683020 m and 5699020 m northing |
| Grid | 64 columns by 64 rows |
| Cell dimensions and area | 250 m by 250 m, 62,500 m² |
| Cell identifiers | K250_00001 through K250_04096 |
| Ordering | Row major from the southwest, one based |
| Parent grid | 1,024 cells of 500 m, four children per parent |

The original minimal-extent GeoPackage had an undefined CRS tag. The model records EPSG:32631 explicitly from the coordinate range and project context, rather than propagate that tag. This interpretation is retained as provenance in domain.json. The larger supplied GeoPackage already carried the appropriate CRS.

Each cell is an independent vertical soil column. Neighbouring columns exchange neither groundwater nor surface water. Grid spacing specifies the spatial index and parameter sampling support; it does not imply a three-dimensional flow solution or independent observations at 250 m resolution. Atmospheric forcing is shared across the grid.

### 3 2 Land cover and local heath refinement

ESA WorldCover 2021 v200 supplies the initial broad land-cover fractions. A 10 m UTM working grid contributes 625 subpixels per target cell. The dominant terrestrial class selects the soil and vegetation calculation, while the water fraction remains recorded. CORINE Land Cover 2018 class 322 activates the heath prior where its area fraction is at least 50%. The received CORINE extraction contains 237 vector objects and at least 95% map coverage in every target cell. Its source scale and mapping units do not make it an independent contemporary observation for every 250 m cell.

Two BWK and habitat extracts provide 11,811 unique polygons after object-identity checks. Habitat codes 2310, 4010 and 4030 support positive local heath assignments. Fractions are intersected with target cells. Habitat percentages are assumed uniform within their source polygon. Bounds for unresolved code combinations express interpretation uncertainty, not a statistical confidence interval. Absence of a habitat code is not used as evidence that heath is absent. The local analysis identifies 159 majority-heath cells, of which 86 were already selected by CORINE, so 73 assignments are added.

| V02 vegetation class | Code | Cells | Calculation |
| --- | --- | --- | --- |
| Generic forest | 10 | 2,163 | Prescribed vegetation and LAI |
| Heath analogue | 20 | 229 | Prescribed vegetation and LAI |
| Mapped grass | 30 | 802 | SWAP WOFOST grass |
| Mapped agricultural crop | 40 | 503 | SWAP WOFOST maize proxy |
| Built up area | 50 | 396 | Prescribed pervious soil surrogate |
| Herbaceous wetland | 90 | 3 | Prescribed wetland analogue |

Mixed cover occurs in 3,702 cells. There is a positive water fraction in 304 cells and more than 50% water in 24 cells. A terrestrial column in such a cell represents a chosen soil response, not the lake water balance or the area-weighted response of every cover fraction. Likewise, the 396 urban columns contain no impervious fraction runoff, sewer routing or urban storage model. Regional volume estimates must acknowledge these representation gaps. Retaining fractions does not itself implement a fractional hydrological calculation.

## 4 Meteorological forcing and time alignment

The same existing ERA5 reanalysis series drives every column. It was obtained through the archive API used by the research pilot. The representative extraction location is 4.44675648715192° E, 51.359254426505835° N, corresponding to E 600730 m and N 5690770 m. It is the centre of the earlier representative 500 m cell, KAL_0496, rather than the exact geometric centre of the new grid.

The series contains 24,120 consecutive hourly records in UTC. It spans 1 January 2024 at 00:00 through 1 October 2026 at 23:00 as interval starts. Precipitation totals 2,216.6 mm. The records are reanalysis estimates and are not station measurements. Spatial variation in rainfall or meteorological forcing across the 256 km² domain has not been introduced.

The source API labels precipitation and shortwave aggregates by the preceding hour. The alignment script shifts those aggregates to the explicit interval-start convention used in the native forcing. The endpoint record at 2026-10-02T00:00 supplies the last needed aggregate. Instantaneous air temperature, dewpoint and wind remain at their original timestamps. Source, endpoint and aligned file hashes are retained. The script checks hourly continuity and consistency of daily radiation integrals. This temporal convention must be preserved when replacing the forcing.

| Native hourly field | Meaning and conversion |
| --- | --- |
| DATE and RECORD | UTC date and record number 1 to 24 within that date |
| RAD | Shortwave energy per hourly interval, source MJ m⁻² multiplied by 1,000 to kJ m⁻² |
| TEMP | Air temperature in degrees Celsius |
| HUM | Actual vapour pressure in kPa, calculated from source dewpoint |
| WIND | Source wind speed at 10 m in m s⁻¹ |
| RAIN | Precipitation depth per hourly interval in mm |

Actual vapour pressure is calculated as 0.61078 exp[17.27 Td / (Td + 237.3)], with dewpoint Td in degrees Celsius. HUM is therefore not relative humidity in percent. SWMETDETAIL=1 and NMETDETAIL=24 select detailed weather input. SWRAIN=0 in that configuration uses the hourly precipitation in hourly.met. The retained kalmthout.rain file is an unused reference for this configuration, not a second rainfall input.

SWETR=0 and SWDIVIDE=1 use the native Penman-Monteith route with direct partitioning of evaporation and transpiration. The weather location uses LAT=51.3592544265, LONG=4.4467564872 and LONG_TZ=0.0. ALT=25 m is a shared station-elevation assumption, not a spatial terrain model. Wind and humidity reference heights are ALTW=10 m and ALTH=2 m. Angstrom coefficients retain 0.25 and 0.5. Replacing the forcing should include checking its height, radiation, vapour pressure, accumulation and timezone contracts.

## 5 Soil profiles and hydraulic parameters

### 5 1 Source layers and sampling

SoilGrids 2.0 mean sand, silt, clay, bulk density and soil organic carbon supply six depth intervals. Thirty regional WCS extractions, covering five properties at six depths, were actually received and retained. The rasters are sampled at target cell centres. The preparation script checks the recorded raster hashes and domain identity before using them. Raster values are modelled soil estimates, with their own support and uncertainty.

| Layer | Depth below surface | Thickness | Native compartments |
| --- | --- | --- | --- |
| 1 | 0 to 5 cm | 5 cm | 5 compartments of 1 cm |
| 2 | 5 to 15 cm | 10 cm | 10 compartments of 1 cm |
| 3 | 15 to 30 cm | 15 cm | 3 compartments of 5 cm |
| 4 | 30 to 60 cm | 30 cm | 6 compartments of 5 cm |
| 5 | 60 to 100 cm | 40 cm | 8 compartments of 5 cm |
| 6 | 100 to 200 cm | 100 cm | 20 compartments of 5 cm |

Every column therefore has six physical layers and 52 numerical compartments, ending at 200 cm. A fixed two-metre profile is used regardless of unknown bedrock or organic-layer depth. The output depth selection operates on these compartments, as described in Section 10.

Texture is converted from g kg⁻¹ to percent by division by 10 and then normalised to sum to 100%. Bulk density is converted from cg cm⁻³ to g cm⁻³ by division by 100. Organic carbon in dg kg⁻¹ is divided by 100 to obtain mass percent. Original values, the texture total, the normalisation factor and the values ultimately used remain in each cell manifest. Thermal BDENS uses the corresponding native mass-density units, mg cm⁻³.

At least one layer lacks usable source data in 640 cells. Each affected property set is assigned the nearest valid target sample at the same depth within a declared 5 km search distance. The largest distance actually used is 1,118.03399 m. The donor cell and distance are retained. No generic sandy profile was silently inserted. Seven cells carry a flag for extrapolation of a mineral pedotransfer relationship at high organic carbon. These are distinct uncertainties: availability of a donor does not demonstrate that the donor represents the local soil.

### 5 2 Pedotransfer relationship

The hydraulic conversion uses Rosetta 3 through rosetta-soil version 0.3.2, model 3, with texture and bulk density. It predicts residual and saturated water content, alpha, n and saturated hydraulic conductivity for the native Mualem-van Genuchten representation. Geometric estimates are used for the logarithmic parameters. Alpha is in cm⁻¹ and saturated conductivity is in cm d⁻¹. The Mualem exponent is explicitly set to 0.5. The same predicted saturated conductivity is used in the two native conductivity fields. Other Rosetta output and dispersion estimates remain preserved rather than being treated as interchangeable SWAP parameters.

The per-cell layers record raw source values, donor information, the ten-value swap_mvg array, Rosetta version and model, geometric estimates and source dispersion. The executable input is the final authority for which values enter SWAP. The separately collected local profile and groundwater datasets have not replaced SoilGrids hydraulic profiles in V02. Earlier local soil scenarios used a different source selection and Rosetta model 2 when bulk density was unavailable; those are separate experiments and must not be described as the hydraulic method of this regional grid.

No local hydraulic calibration, observation-based conductivity correction or uncertainty ensemble is included. Hysteresis and macropore flow remain disabled. The layer estimates and smoothing implied by gridded products may fail to reproduce shallow restrictive horizons, peat, preferential flow or spatially variable saturated conductivity.

## 6 Vegetation and WOFOST configuration

### 6 1 Prescribed vegetation

Forest, heath, urban soil surrogates and the remaining herbaceous wetland cells retain the V01 prescribed vegetation route. The seasonal LAI curves are NHI analogues, not measured LAI at each cell. Forest uses NHI index 11, heath index 14, and the urban and wetland analogues index 1. The exact source selections and source package identity are retained in the complete V01 recovery archive.

| Vegetation | Root depth cm | Height cm | Minimum resistance s m⁻¹ | Albedo |
| --- | --- | --- | --- | --- |
| Generic forest | 100 | 1,000 | 150 | 0.15 |
| Heath analogue | 50 | 40 | 288.84 | 0.30 |
| Urban pervious soil surrogate | 30 | 10 | 150 | 0.20 |
| Herbaceous wetland analogue | 50 | 70 | 100 | 0.23 |

Prescribed vegetation uses a canopy interception capacity of 0.05 cm per unit LAI. The heath resistance follows the recorded NHI analogy; the other stated resistances, heights and rooting depths are project defaults. The original seasonal curves are compressed to fit native table limits. Some non-heath curves first use 13 annual anchors and linear interpolation. A tolerance for the later compression step must not be reported as the total deviation from the full original curve. Manifest records retain the actual approximation information.

Generic forest does not distinguish coniferous and deciduous stands, although the earlier CORINE analysis identifies 660 predominantly coniferous cells. The prescribed vegetation route does not calculate WOFOST gross assimilation. Its native zero GASST values are converted to missing values in the delivered NetCDF files.

### 6 2 Choice and origin of dynamic crop files

We inspected the dynamic crop parameter files included in the original SWAP 4.3.1 distribution. The available examples include grass, maize, barley, onion, starch potato, consumption potato, sugar beet and wheat. Grass and maize were selected as usable initial examples. The source bank has a Dutch modelling context, but these selected files have not been established as calibrated local varieties or management systems for this domain.

Grass is assigned to all 802 mapped grass cells. Maize represents all 503 agricultural cells as an explicit proxy. This does not assert that every agricultural cell actually contained maize during 2024 to 2026. A crop map and annual rotation have not been inferred from the broad WorldCover crop class.

The two source files come from data/crops/dynamic within the original distribution. Original copies are retained alongside the derived files. Only SWCO2 and SWSALINITY are overridden in the crop files, both to zero. SWCO2 is disabled because the supplied climate correction file contains a historical period followed by an SSP5-8.5 projection. That projection is not substituted for observed recent CO2. Disabling the correction retains the source base response; it does not introduce a reconstructed atmospheric CO2 series. Salinity stress is disabled because the regional configuration has neither a solute simulation nor observed salinity inputs.

### 6 3 Calendars and growth switches

The SWP rotation table uses CROPTYPE=2 for both dynamic models. In SWAP 4.3.1, this is the dynamic crop route; grass is distinguished by SWWOFOST=3 inside its crop file. Maize uses SWWOFOST=1. Setting CROPTYPE=3 for grass would not represent this version's accepted input syntax.

| Setting | Grass | Maize |
| --- | --- | --- |
| Calendar repeated in 2024 2025 2026 | 1 January to 31 December | 1 May to 15 October |
| SWSOW | 0 | 0 |
| SWGERM | 0 | 2, temperature and water response |
| Emergence temperature sum | Not used through SWGERM | TSUMEMEOPT=110 °C days, TBASEM=4 °C |
| Growth start | SWTSUM=1, air temperature sum above 200 °C | Source germination and development settings |
| Development thermal sums | Source grass implementation | TSUMEA=600 and TSUMAM=1,211 °C days |
| Minimum canopy resistance | 79.1 s m⁻¹ | 196.1 s m⁻¹ |
| Initial rooting depth RDI | 20 cm | 10 cm |
| Maximum daily extension RRI | 1.0 cm d⁻¹ | 2.2 cm d⁻¹ |
| Minimum extension RRIMIN | 0.2 cm d⁻¹ | 0.44 cm d⁻¹ |
| Relative management factor RELMF | 0.7 | 1.0 |
| Harvest timing SWHARV | Calendar end | Calendar end |

The 2026 crop calendars extend beyond the simulation stop date; only the interval through 1 October is calculated. A calendar start is not proof of emergence on that date. Maize retains its native germination controls. Grass retains the source biomass-dependent mowing rules rather than an observed mowing calendar. Applying a managed grass file to all mapped grass may misrepresent unmanaged or natural grassland.

Both files retain SWRD=2, SWDMI2RD=2 and SWRDC=1 for their source rooting response, SWDROUGHT=3 for the De Willigen drought response, SWOXYGEN=2 for the Bartholomeus oxygen response, and SWWRTNONOX=1 for aerobic rooting checks. They use SWINTER=3 for Rutter interception and SWPOTRELMF=2 for the source attainable-yield management route. The source interception parameters, partitioning tables, assimilation tables, leaf properties and mowing or harvest rules are preserved in full. The scalar inventory accompanies this note, while the complete CRP files retain the table values and comments. V02 does not claim a locally specified nutrient or fertilisation model.

## 7 Water boundaries and initial conditions

A uniform pressure head of -75 cm is imposed as the initial soil profile. This is a pressure-head profile, not an observed water table at 75 cm below the surface. No hydrological spin-up precedes 2024. The arbitrary initial storage can influence subsequent fluxes, especially in the first year and where deeper stores equilibrate slowly.

Free drainage, SWBOTB=7, applies to 4,090 cells. Six cells retain SWBOTB=5 with a fixed assumed groundwater level 50 cm below the soil surface. At the bottom compartment centre at 197.5 cm depth, the imposed pressure head is 147.5 cm. This assumption came from the V01 wetland classification and is preserved through vegetation reassignment. Three of these six cells are now classified as heath, while three remain herbaceous wetland. It is not a measured head series, a managed polder level or an aquifer model.

The 62 locally identified majority wet-heath cells retain a boundary-review flag. They have not automatically received a locally validated shallow groundwater condition. Grass and agricultural cells similarly retain the need to assess drainage and water management. No blanket peilbeheer assumption is introduced. No lateral exchange, regional groundwater feedback or surface-water network is present. A future regional groundwater model could inform these boundaries, but has not supplied V02 boundary values.

Irrigation and artificial drainage are disabled, SWIRFIX=0 and SWDRA=0. Runon is disabled. A constant surface ponding threshold PONDMX=1 cm permits surface runoff once the relevant native condition is met. Surface runoff is not routed between cells. Snow, frost effects and solute transport remain disabled. Negative simulated temperatures therefore do not imply that frozen-water retention or frost-induced hydraulic reduction was modelled.

## 8 Numerical heat transport

All 4,096 cells activate SWHEA=1 and SWCALT=2, selecting the numerical heat route. Thermal texture fractions are calculated separately for each physical layer from the used sand, silt and clay values, normalised to a unit total. Organic matter mass fraction is estimated as 1.724 times the organic carbon mass fraction. This carbon-to-organic-matter factor is an explicit conversion assumption and may be unsuitable for some local organic materials. Native bulk density comes from the same soil preparation.

SWTOPBHEA=1 uses air temperature for the upper thermal boundary. SWBOTBHEA=1 imposes zero heat flux at the bottom. The initial temperature profile is linear between 7.5125 °C at the surface, the mean air temperature on the first simulation day, and 11.879371584699452 °C at 200 cm, the 2024 annual mean air temperature. Neither endpoint is an observed soil temperature. The deeper endpoint uses information from the simulation year and is an initialisation convenience, not an independent prediction or an operational forecast input.

There is no thermal spin-up, explicit measured deep temperature or site-specific ground-surface energy calibration. Air temperature above a canopy need not equal the effective ground thermal boundary. Soil texture, bulk density, organic matter conversion and boundary assumptions all affect the results. These limitations are particularly relevant when comparing early 2024 temperatures or shaded forest and heath cells with sensors.

## 9 Native executable and execution procedure

### 9 1 Compiler and restricted source correction

The original distribution and SWAP and TTUTIL source archives are retained with SHA-256 identities. GNU Fortran 13.3.0 builds the native executable with -O2, preprocessing for Linux, allowance for legacy argument mismatches and unrestricted fixed and free source line lengths. DEC conditional directives are translated to equivalent preprocessing conditions in the generated build tree. The build comprises 216 objects and links through gcc with libgfortran.so.5, libm and libquadmath. The compiler package URLs and hashes are preserved.

A GNU output portability defect had to be corrected to support the requested vector output. In the tested build, component DATA initialisers for vector metadata were not available as expected when the allocatable derived-type output structure was used. WC was consequently rejected as an unknown output name. A binary-output probe also exposed a local allocatable-buffer lifetime problem between output tasks.

The change is restricted to swap_csv_output.f90. The same 58 vector metadata entries are assigned explicitly during output initialisation. Local ASCII and binary buffers receive SAVE lifetime. The patch does not change water flow, heat transport, crop growth, stress calculations or time integration source. Input changes, rather than hidden physics edits, activate the V02 options.

Targeted ASCII, binary and depth-selection probes completed after the correction. A full archived forest column, K250_00007, was repeated with its unchanged heat-off V01 configuration. All 29 parsed fields over 1,006 rows matched the original executable exactly. An additional urban reference, K250_00001, matched 13 common scalar fields over the same 1,006 rows. This qualifies the stated output correction for those checks. It is not a general Intel/GNU equivalence study, a comprehensive compiler validation or an independent qualification of all heat and WOFOST physics.

### 9 2 Native numerical settings

The regional SWP files retain the existing native numerical controls. The six physical layers are discretised into the 52 compartments described above. DTMIN=0.000001 d and DTMAX=0.04 d bound the adaptive time step. Hourly forcing does not imply a fixed hourly integration step. MAXIT=30 and MAXBACKTR=5 retain the iteration and backtracking limits. CRITDEVH1CP=0.01, CRITDEVH2CP=0.1 cm and CRITDEVPONDDT=0.0001 cm retain their native roles.

Hydraulic conductivity averaging uses SWKMEAN=1, the unweighted arithmetic option, and SWKIMPL=0. CRITDEVBALCP=0.000001 and CRITDEVBALTOT=0.00001 retain the native compartment and total convergence controls. These controls were not relaxed to make the regional audit pass. The output audit described next is a separate check of printed daily quantities and should not be confused with an internal solver convergence tolerance.

### 9 3 Scheduling and identity checks

The local runner uses eight worker threads to schedule separate native processes in independent cell directories. Each process has a 180 second timeout. Native return code 100 and the message “Swap normal completion!” are required for a newly executed case. Return code zero is not substituted for this version's success convention. The runner sets the owner executable permission before launch to handle workspace mode normalisation.

Each cell manifest records hashes for every active native input, including shared forcing targets and its crop file. Before execution, the runner checks those hashes. Reuse requires the accepted prior status, identical input hashes, identical executable hash and identical daily output hash. Even reused output is parsed and audited again. Receipts are written to a temporary path and then renamed.

The full regional scheduling phase took 1,872.8333 seconds, about 31.2 minutes, with eight workers. It reused the 64 already completed qualification-sample cases after identity checking. Those cases had already been calculated using the same final V02 inputs and executable, so all 4,096 delivered cell responses are actual V02 executions. The wall time includes that reuse and is not the cost of 4,096 entirely fresh executions. It is a measurement for this environment, not a portable performance guarantee. No GitHub Actions calculation was used.

## 10 Daily output definitions

### 10 1 Native request and additional audit fields

The daily request contains RAIN, RUNOFF, IRRIG, DRN, BOT, EPOT, EACT, TPOT, TACT, EPD, EIC, DSTOR, BALDEV, GASST and GWL. It also selects WC and T at requested signed depths -10, -20, -40, -80 and -160 cm. The native INLIST_CSV expression uses semicolons inside the vector selections and commas between variables. WTOT, PD_VOL and IC_VOL are added solely to support an independent storage audit. They are day-end water-depth states in cm for soil water, surface pond water and intercepted canopy water respectively. They remain in the native CSV and are used to derive the exported balance diagnostic, but are not delivered as separate NetCDF arrays.

SWCSV=1 writes native ASCII CSV with NUM_DECIMALS=8. Each cell has 1,006 rows: the initial state labelled 2023-12-31, followed by 1,005 daily records. Daily NetCDF files omit the initial record but retain its effect in the first independently calculated storage difference. Printed precision is not proof of eight-decimal physical accuracy.

Native selection chooses the compartment centre containing the requested depth. It does not interpolate soil states to exactly the requested depth. Both the actual and requested coordinates are retained.

| Requested signed depth cm | Actual signed centre cm |
| --- | --- |
| -10.0 | -10.5 |
| -20.0 | -22.5 |
| -40.0 | -42.5 |
| -80.0 | -82.5 |
| -160.0 | -162.5 |

### 10 2 Water and assimilation dictionary

All water flux fields below are interval-integrated water depths in cm in the delivered files. Multiplication by 10 gives mm. They are not rates in cm per second. Daily state fields are instantaneous native states at the day end. Potential fluxes are model demand quantities and do not belong as additional losses in the actual water balance.

| Variable | Definition and interpretation | Unit and temporal support |
| --- | --- | --- |
| RAIN | Native gross precipitation entering the model accounting | cm over the daily interval |
| RUNOFF | Surface runoff leaving the column surface system | cm over the daily interval |
| IRRIG | Irrigation input, disabled in this configuration | cm over the daily interval |
| DRN | Native net drainage term, drainage module disabled | cm over the daily interval |
| BOT | Net bottom boundary exchange, positive into the soil column | cm over the daily interval |
| EPOT | Potential soil evaporation | cm over the daily interval |
| EACT | Actual soil evaporation | cm over the daily interval |
| TPOT | Potential transpiration | cm over the daily interval |
| TACT | Actual transpiration or integrated root water uptake | cm over the daily interval |
| EPD | Evaporation from ponded surface water | cm over the daily interval |
| EIC | Native canopy interception accounting term, including capacity-loss effects | cm over the daily interval |
| DSTOR | Native change in total water storage used in its balance accounting | cm change over the daily interval |
| BALDEV | Native water balance deviation with the native sign | cm over the daily interval |
| GASST | Gross crop assimilation in CH2O equivalents; availability depends on crop route | kg ha⁻¹ over the daily interval |
| GWL | Native groundwater level relative to the soil surface, positive upward | cm, state at day end |
| WC | Volumetric water content at each actual compartment centre | m³ m⁻³, state at day end |
| T | Soil temperature at each actual compartment centre | degrees Celsius, state at day end |

BOT retains its native inward-positive sign. A derived net bottom outflow in mm would equal -10 times BOT. It must not automatically be called validated groundwater recharge. It is the flux through an imposed lower boundary of a two-metre column. EIC must not automatically be interpreted as measured or pure interception evaporation because the native accounting can include canopy-capacity loss.

GASST is native gross carbohydrate assimilation. Its kg ha⁻¹ unit refers to CH2O equivalents, not directly to kg of carbon and not to a fully specified ecosystem gross primary production product. A future conversion would need an explicit substance definition, area and time conversion, and a decision about the desired carbon flux. No such carbon-product conversion is applied in V02.

### 10 3 Missing values and flags

For prescribed vegetation, assimilation is not simulated. Native zero GASST is exported as NaN, with GASST_flag=2. For a dynamic crop, native unavailable GASST values equal to -999.999 are assigned zero only under the documented no-active-crop interpretation, with flag 1. Native simulated values retain flag 0. Consumers should preserve these flags rather than merge all three categories into an undifferentiated zero series.

Across all delivered cell days, GASST_flag has 1,052,480 native-value records, 259,045 no-active-crop records assigned zero, and 2,804,955 records where assimilation is not simulated. These categories account for all 4,116,480 cell days.

Native GWL=999 cm means unavailable and is exported as NaN. It must not be plotted as groundwater 9.99 m above ground. Lack of a valid groundwater state, particularly under free drainage, is not filled from an external aquifer assumption. WC and T remain finite in every delivered cell and day at all five levels.

The independent_balance_residual field has units cm and retains the difference between daily external water exchange and the change in consecutive printed total stores. canopy_reset_flag is 1 where the known crop-calendar accounting discontinuity is identified, and 0 otherwise. Zero flag means this specific issue was not identified; it is not a general certification of model accuracy.

## 11 Water balance audit and retained accounting limitations

The first audit checks the native daily ledger using the printed fluxes, DSTOR and BALDEV:

RAIN + IRRIG + BOT - RUNOFF - EACT - EPD - TACT - EIC - DRN - DSTOR - BALDEV = 0.

The maximum accepted absolute difference for this printed-ledger identity is less than 0.000001 cm. The largest observed difference is 0.0000000200000003 cm. The largest absolute native BALDEV is 0.0035682 cm, or 0.035682 mm. A small residual after subtracting BALDEV must not be reported as zero native balance deviation. The audit also checks exact date order, 1,006 native records, requested fields, finite numbers, the precipitation sum, WC between zero and one, and T between -60 and 70 °C. Those broad bounds identify invalid output; they are not calibrated ecological or thermal plausibility limits.

A separate check calculates total printed storage S as WTOT + PD_VOL + IC_VOL for soil, pond and canopy water. It compares daily net external exchange with S at consecutive output times. The exported independent_balance_residual equals net exchange minus this storage difference. When checking against native BALDEV, the runner examines the additional discrepancy after subtracting BALDEV. This separation prevents a native storage-accounting inconsistency from being hidden by a self-consistent printed DSTOR ledger.

The final delivery contains 1,701 explicitly recognised canopy reset events: 1,198 annual events in grass and urban surrogate cells and 503 harvest events in maize cells. The annual group comprises 802 grass and 396 urban cells. The actual flagged dates are 16 October 2025 for the 503 harvest events and 1 January 2026 for the 1,198 annual events. The largest recognised reset is 0.0356819 mm. These small magnitudes do not convert them into a clean daily physical closure result.

An event is accepted as a known flagged limitation only at the specified annual or maize post-harvest transition and only when the discrepancy either cancels across the two adjacent daily records or agrees with the previous printed canopy storage within the declared rounding tolerance. Other unexplained storage discrepancies fail the audit. The audit does not use a generally widened tolerance to absorb them. The native fluxes, DSTOR and BALDEV are preserved, rather than rewritten to manufacture closure.

In 2024 the NetCDF files contain no flagged cell days. In 2025 there are 503, and in 2026 there are 1,198. Maximum absolute independent residuals are approximately 0.00000030 mm, 0.0356820 mm and 0.0106133 mm for 2024, 2025 and 2026 respectively. These are checks on the printed output and recognised calendar behaviour. They do not measure model error against field observations.

## 12 NetCDF structure and metadata

### 12 1 Files and coordinates

The efficient analysis product is three annual NetCDF4 files. Annual partitioning limits file size and makes complete-year retrieval practical. A single writer receives audited native output in blocks of 64 cells, avoiding concurrent appends by thousands of processes. Native CSV remains the audit source. The export took 1,568.4058 seconds including time waiting for native runs, so that number is not a standalone serial conversion benchmark.

| Year | Days | Cells | Depths | Bytes |
| --- | --- | --- | --- | --- |
| 2024 | 366 | 4,096 | 5 | 96,744,536 |
| 2025 | 365 | 4,096 | 5 | 99,175,314 |
| 2026 | 274 | 4,096 | 5 | 74,222,364 |

The files declare CF-1.10 and contain time, cell, depth and bounds dimensions. This is a declared metadata convention, not the result of an independent comprehensive CF compliance test. time has units days since 1 January of the corresponding year at 00:00 and a proleptic Gregorian calendar. Values are 1 through the number of daily intervals. time_bounds identifies the complete preceding daily interval. simulation_date retains the original native DATE label.

For example, the record whose simulation_date is 2025-01-01 has time at 2025-01-02T00:00 and bounds from 2025-01-01T00:00 to 2025-01-02T00:00 UTC. State variables refer to the upper bound. Flux quantities integrate over those bounds. Consumers should not shift the flux series another day merely because the coordinate is at the upper interval bound.

cell is a string identifier, not a latitude-longitude raster coordinate. easting and northing give each centre in metres. row and col are one-based southwest-origin grid indices, with parent_cell_500m preserving the previous grid relationship. depth is the actual signed compartment centre in cm with positive=up. requested_depth preserves the user's five selections. crs records the transverse Mercator parameters for EPSG:32631: central meridian 3°, latitude of origin 0°, scale 0.9996, false easting 500,000 m, false northing zero, semi-major axis 6,378,137 m and inverse flattening 298.257223563.

### 12 2 Variables and encoding

| Variable group | Dimensions | Storage and interpretation |
| --- | --- | --- |
| Fifteen requested scalar variables | time, cell | float64, daily integrated values except GWL state |
| WC and T | time, cell, depth | float32, native day-end states at actual centres |
| independent_balance_residual | time, cell | float64, independent daily accounting diagnostic |
| GASST_flag and canopy_reset_flag | time, cell | Unsigned byte flags |
| easting northing | cell | float64, projected metres |
| row col vegetation_class | cell | Integer indices or classes |
| water_fraction dominant_land_fraction | cell | float32 fractions |
| crop_model native_model | cell | String model-route descriptions |
| parent_cell_500m landcover_input_flags | cell | String parent identity and retained input flags |

Numeric output arrays use zlib compression level 4 and shuffle. The primary numeric flux and state arrays also use Fletcher32 checksums. Flag arrays use compression and shuffle but do not carry that same Fletcher32 setting. Chunks are 32 days by 64 cells, with all five depths together for depth-dependent fields. Values are not packed to scaled integers. Float32 conversion for WC and T is declared and checked; scalar water and assimilation data retain float64.

The files total about 26.3% of the native CSV byte count, approximately a 3.8-fold size reduction. This comparison includes the declared encoding and representation differences. It does not imply a general compression ratio for every future SWAP dataset. Chunking is a practical starting choice for blocks of cells over daily periods. Different access patterns may benefit from a measured alternative.

Water and assimilation quantities carry time: sum as their cell method; GWL, WC and T carry time: point. GASST has substance CH2O equivalents. BOT and GWL include their sign descriptions. File-level metadata records model scope, time and depth conventions, the assimilation and balance contracts, executable hash, crop assumptions, spatial limitations, full_grid_complete and export_complete. Metadata were finalised after native execution to add the final cell-level flags and model descriptions. Final hashes refer to those completed files.

The complete machine-readable netcdf_schema.json records every dimension, variable, dtype, chunk setting, compression filter and attribute actually read from the delivered files. It complements this explanatory note. The parameter_inventory.json records scalar assignments from the representative forest SWP and both dynamic crop files. It does not replace per-cell input manifests or native table values.

### 12 3 Completion and integrity checks

The exporter writes .nc.partial files and renames them only after completion. full_grid_complete distinguishes the full 4,096-cell product from the earlier five-cell prototype. export_complete marks a completed export. Consumers should require both completion fields and verify the supplied checksums when assembling files from Git parts.

The final validation reads complete requested arrays in all three annual files. It checks shapes, spatial metadata joins, finite soil states, missing-value interpretation and flag counts. Nine selected cells are compared with their native CSV series for every requested scalar and every depth in all three years. Scalars match exactly after the documented missing-value interpretation. WC and T match exactly after conversion to float32. A separate five-cell prototype exercised the same three-year round trip before full export. Xarray also opened a complete annual file and extracted a cell temperature series with 365 by 5 values for 2025.

The actual exported temperature ranges are -1.98778 to 25.00813 °C in 2024, -0.72106 to 27.02534 °C in 2025, and -0.87706 to 27.50898 °C in 2026. These ranges demonstrate nonconstant computed heat output within the checked broad bounds. They provide no substitute for comparison with measured soil temperatures.

## 13 Provenance and recovery

### 13 1 Artifact identities

The complete file identities below refer to reassembled bytes, before extraction. SHA-256 of each individual Git part is also recorded in artifact_manifest.json. Reassembly must use that manifest's ordered list, rather than a directory wildcard that could accidentally include unrelated files.

| Artifact | SHA256 |
| --- | --- |
| SYMPHONICA_BASELINE250_COMPLETE_20261018.tar.xz | 46f985153d9b2213c1003d77373b55ca261c500ce37c28d8f4da513c7b7ab746 |
| SYMPHONICA_Kalmthout_V02_model_20261019.tar.xz | d64f0394681d2ecad2492be1e750f234c96ad929e4db1aa5facbae1110de3149 |
| Kalmthout_SW431_V02_daily_2024.nc | 1b30cd007e572c9b364794223c13df536a06fd1dd7b592ff00fe76c967add84d |
| Kalmthout_SW431_V02_daily_2025.nc | e49a220af4ccaf290846649b0f555422e218e5c56fc653bb76e36479a15f23c7 |
| Kalmthout_SW431_V02_daily_2026.nc | 97a23bfc7227650ef1c529737bf7590a65b3f776bdec484249a5cd29e6a65e00 |

| Source or executable | SHA256 |
| --- | --- |
| Original SWAP 4.3.1 distribution | 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360 |
| Original SWAP source ZIP | 1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151 |
| Original TTUTIL source ZIP | ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193 |
| Original GNU V01 executable | 34850f3148c8a312308e2b86d04fa76df9085699548a59164c03bf01aee4e37c |
| Corrected GNU V02 executable | f4a13596f4725f72d73856f7b4a07d9f35c06a0435736af37503f6d68dd31386 |

### 13 2 Archive scope and historical checkpoint distinction

The complete V01 archive is included because it contains the actual regional source rasters, local source geometry, forcing lineage, previous preparation scripts and native baseline needed for recovery. The older two-part SYMPHONICA_BASELINE250_V01 archive already present in Git is only a historical 69-case execution checkpoint, despite its broad filename. It is 14,243,388 bytes and has hash 3b53f4ebd68aef4163d4e3ea549bf1295cdb36c67795d73196882217d82a57a3. It must not be substituted for the complete 123,257,020-byte archive supplied with V02. The final V01 status record describes completion, while that earlier archive manifest correctly describes its older incomplete execution stage.

The V02 recovery archive contains all 4,096 native SWP inputs, active crop files, shared forcing, manifests, run receipts, native daily CSV output, end-condition output and logs. It also contains the corrected executable, the original distribution, original source archives, the corrected source module, patch, compiler identities and executable preparation, run, export and validation scripts. The archive contains 67,893 entries and 9,497 relative internal links. Its executable header explicitly retains mode 0755. Native parser caches ending in .tmp are omitted. The three annual NetCDF files are supplied separately and can be regenerated from the retained CSV output.

The large original WorldCover tile and full NHI toolkit are not duplicated in the complete V01 archive. The regional bytes, selected NHI input and source identities actually needed for this model are preserved. This is a closure for the stated regional reconstruction, not a claim to have mirrored every upstream distribution. Original downloads remain subject to their source licences and attribution requirements. SWAP distribution licence material is retained with the original archive.

### 13 3 Practical recovery procedure

The versioned assemble_artifacts.py script reads artifact_manifest.json, verifies every part and assembles each original file. It verifies the complete SHA-256 before renaming the .partial file. The documented destination should have room for both the archives and extracted native output. It is preferable to use an empty recovery location so that old parser caches or receipts cannot be mistaken for current evidence.

```sh
python3 research/kalmthout_pilot/v02/scripts/assemble_artifacts.py /absolute/path/assembled
mkdir -p /absolute/path/BASELINE /absolute/path/V02
# Extract the complete baseline into BASELINE and the V02 model into V02.
tar -xJf /absolute/path/assembled/SYMPHONICA_BASELINE250_COMPLETE_20261018.tar.xz \
  -C /absolute/path/BASELINE
tar -xJf /absolute/path/assembled/SYMPHONICA_Kalmthout_V02_model_20261019.tar.xz \
  -C /absolute/path/V02
```

Install the retained Python requirements in an isolated environment. The executed V02 environment records numpy 2.3.5, netCDF4 1.7.5 and xarray 2026.9.0. Reconstructing the original regional soil and GIS preparation also needs the broader baseline dependency list, including Rosetta and spatial libraries. The source archive and compiler package records support a native rebuild, but a different compiler or library environment is not promised to produce a byte-identical executable. Requalification is needed if that dependency surface changes.

Existing results can be re-audited and reused without recalculating the physics when their identities match. The V02 archive is self-contained for reading and auditing its native results. The complete V01 archive supplies the baseline needed if the regional V02 inputs themselves are to be regenerated.

```sh
python3 /absolute/path/V02/scripts/run_v02.py /absolute/path/V02 \
  /absolute/path/V02/native/swap_gnu_output_fixed --workers 8
python3 /absolute/path/V02/scripts/export_v02_netcdf.py /absolute/path/V02 \
  /absolute/path/V02/daily_netcdf
python3 /absolute/path/V02/scripts/finalize_v02_metadata.py /absolute/path/V02
python3 /absolute/path/V02/scripts/validate_v02_delivery.py /absolute/path/V02
```

The rebuild_v02.py helper extracts the retained original sources, replaces only the corrected output module and calls build_work.py. The preparation script accepts an explicit baseline location and the extracted original distribution. These commands use explicit paths to make the relationship between source, run root and output clear. Before launching a changed run, preserve its input and executable identities separately from this delivered baseline. Do not overwrite the historical result and still call it the same V02 delivery.

### 13 4 Per cell and per file metadata

cell_manifest.json records cell geometry, land-cover class and fractions, boundary type, flags, six-layer source and hydraulic information, vegetation route, numerical heat assumptions and active input hashes. v02_run_receipt.json records the cell ID, native status, crop route, return code, elapsed time, reuse decision, input hashes, executable hash, output hash and audit details. It is the direct link between an executed column and the daily CSV used in export.

Flags whose names contain V01 can remain in V02 as inherited provenance and limitations. They do not imply that the V02 executable or heat route was absent. The final model_version, crop_model and heat records establish the active configuration.

cell_register.csv provides a compact join between the geometry, model route, quality flags and final execution status. grid_250m.geojson preserves the full grid and final V02 descriptions. netcdf_export_receipt.json records the files, years, dimensions, true and requested depths, export timing and output identities. delivery_identity.json provides the executable identity, ordered cell identity digest and archive contract. delivery_validation_v02.json records the complete final delivery checks. artifact_manifest.json adds the independently verifiable Git packaging layer. These records have different roles; none alone establishes field accuracy.

## 14 Reading and using the provisional results

Use the complete annual files for analysis and keep cell identifiers, actual depths and flags with any extracted series. Select on simulation_date when referring to the labelled simulation day, and use time_bounds for integration. A state at the end of 1 January belongs at midnight starting 2 January in the time coordinate. The 2026 file is a partial year, with 274 days through 1 October, and must not be compared with complete-year totals without an explicit adjustment of the comparison period.

Sum daily interval depths for water totals. Do not sum daily GWL, WC or T to obtain a meaningful annual state. Calculate end states or clearly defined averages, retaining missingness and the actual temporal support. Potential and actual transpiration can support a model stress diagnostic, but division by a near-zero potential demand requires its own rule. Do not treat a ratio as an independent observation of stress.

A water depth over a 62,500 m² cell corresponds to 625 m³ for 1 cm or 62.5 m³ for 1 mm. Such conversion does not resolve the dominant terrestrial representation in mixed water or urban cells. Area aggregation for the real landscape needs a documented treatment of fractions and absent process classes. Nor does summing independent lower-boundary outflow create a coupled regional groundwater budget.

GASST should only be analysed where the dynamic crop route and availability flag support the interpretation. Missing forest and heath assimilation is a model capability gap, not zero ecosystem production. Similarly, NaN groundwater levels do not imply dry or absent groundwater in reality. The imposed lower-boundary type and its assumptions should accompany any groundwater or recharge interpretation.

The delivered values may be used to test data ingestion, spatial joins, time aggregation, plotting and comparison workflows. Scientific comparisons should describe the assumptions and should not rank the provisional setup as validated based on numerical completion. The known canopy events should remain visible in daily budget plots and derived diagnostics. Native source files remain available if an interpretation requires checking the exact executed configuration.

## 15 Improvements and recommended sequence

The following improvements are proposed rather than already implemented. The priorities reflect their likely effect on physical interpretation and reproducibility, not a quantified sensitivity ranking. Several can proceed together once the corresponding source data and contracts are available.

1. Improve the relationship with the surrounding hydrological system. Establish observed groundwater dynamics, hydraulic gradients, lateral exchange, aquifer properties and surface-water connectivity. Replace the largely free-drainage lower boundary where it is unsuitable. Review the 62 wet-heath cells first and investigate the six shallow-head assumptions. Use local terrain, monitoring well metadata and consistent vertical datums to distinguish water level, pressure head and depth below the actual cell surface. An external groundwater model or a coupled calculation could supply more defensible boundary histories, but its scale, datum and feedback assumptions must be checked.

2. Identify drainage and water management. Map ditches, drains, controlled levels, irrigation and seasonal operations in agricultural and grassland areas. Represent these processes only where supported by data. A generic managed-level condition across an entire class could be as misleading as universal free drainage. Relate drain levels and resistance to observed groundwater responses, while preserving clear ownership of lateral and lower-boundary fluxes.

3. Connect to the standard SYMPHONICA datasets. Replace exploratory source selection with the agreed project datasets as they are collected and made accessible. Define a mapping for dataset version, source identity, cell or feature identifiers, CRS, vertical datum, depth support, units, timestamps, accumulation intervals, missing values and quality codes. Retain raw source and derived input versions so that a standard-data update can be traced to changed model output. Agree the output schema and ingestion tests with the project data service. This connection is planned and has not yet been demonstrated.

4. Improve local soil and hydraulic representation. Use measured profiles and hydraulic properties where available, including restrictive layers, organic horizons, conductivity and effective profile depth. Reconcile differences between mapped soil classes and point observations before transferring profiles. Review the 640 imputed columns and seven high-carbon PTF extrapolation flags. Estimate uncertainty jointly across hydraulic parameters rather than independently perturb correlated parameters into unrealistic combinations. Compare alternative pedotransfer approaches under a declared applicability domain.

5. Introduce hydrological and thermal spin-up. Test repeated meteorological cycles or a preceding forcing period until initial-state influence is small for the variables of interest. Assess water and temperature convergence separately. Replace the uniform pressure-head and assumed linear thermal profiles where observations support better initial conditions. Record the spin-up forcing, duration and acceptance criterion, and quantify how much the first simulated year changes.

6. Use actual crops and management. Add annual crop maps and rotations, cultivar information, establishment dates, harvest dates, irrigation, mowing and grazing where available. Separate managed grass from natural grassland. Check whether the supplied WOFOST management and resistance parameters transfer to this area. Add an observed or otherwise appropriate CO2 series if correction is required, with an explicit base response and scenario policy. Do not silently use a future scenario for historical years.

7. Refine forest and heath vegetation. Distinguish coniferous and deciduous stands, seasonal canopy behaviour, rooting and drought response. Separate wet and dry heath and review the NHI analogy against local vegetation information. Satellite LAI or canopy observations can constrain seasonal variation, but require scale matching and attention to mixed pixels. A suitable physiological model is needed if gross assimilation is required for forest and heath; the missing GASST values cannot be repaired by assigning crop-like zeros.

8. Improve meteorology and spatial variability. Compare the shared reanalysis series with stations and radar precipitation. Evaluate precipitation bias, storm timing, radiation, humidity and wind height. Introduce spatial variation when justified by source support. Retain the source accumulation convention and UTC interval alignment. A finer grid of repeated forcing values does not add meteorological information.

9. Refine heat and surface energy assumptions. Compare the air-temperature upper boundary with ground-surface temperatures under forest, heath and grass. Review thermal properties, organic matter conversion, deep thermal conditions, snow and freezing where relevant. Activating heat alone does not implement frost hydraulics. Any new freezing option needs its own energy and water accounting checks and validation against observations.

10. Represent water and impervious subgrid fractions. Introduce separate response units or explicit fractional accounting for soil, open water and sealed surfaces. Route surface water only through a defined network and storage model. Establish how area-weighted fluxes, states and missing capabilities are aggregated. The existing fraction fields provide inputs for this improvement but do not implement it.

11. Resolve native canopy reset accounting. Investigate the precise state and flux treatment at annual and harvest transitions. Correct or explicitly reformulate the physical accounting only with a versioned source change and focused conservation tests. Preserve this V02 delivery as the reference for comparison. The current flags retain the limitation; they do not remove it.

12. Validate against independent observations. Match soil moisture and temperature sensors to actual model depth support, compare evapotranspiration with suitable observations, and assess groundwater against correctly referenced monitoring series. Separate calibration and evaluation periods and quantify observation uncertainty. Comparisons with other models can expose discrepancies but do not establish accuracy when the models share forcing or parameter assumptions.

13. Quantify sensitivity and uncertainty. Screen boundary conditions, hydraulic parameters, vegetation, meteorology and initial states before choosing targeted ensembles. Track parameter correlations and structural alternatives. Report ranges for variables and periods that matter to the project rather than attach a generic uncertainty label to a single deterministic realisation. Use the results to decide where new observations would reduce uncertainty most effectively.

14. Improve output semantics and portability. Add fuller variable long names and project-agreed standard names where applicable, run a comprehensive conventions checker and document any remaining CF deviations. Benchmark chunk layouts for the actual project access pattern. A supported native binary reader or direct scientific-data writer could reduce temporary CSV volume, but must retain exact definitions, missing-value rules, independent conservation checks and recovery. Rebuild checks should cover the compilers and runtime systems that the project will actually use.

15. Strengthen operational reproducibility. Make input preparation, execution, validation and publication a single versioned workflow with explicit configuration. Retain dataset and executable identity at every stage, atomic completion markers and resource measurements. Use focused local tests and small representative reruns for changes, reserving full regional recomputation for changes that affect the delivered science. Add restart-equivalence checks before claiming that saved end-condition files support exact continuation. V02 retains those files but does not demonstrate such equivalence.

The immediate scientific sequence is to establish the hydrological surroundings and data alignment, then assess initialisation, local soils and vegetation with observations. Numerical completion and efficient storage are already demonstrated within the stated scope. Their value is that subsequent improvements can now be introduced as identifiable changes with reproducible comparisons against a fixed provisional baseline.

## 16 Evidence sources and scope of the record

This note is based on the actual native inputs, executed receipts, completed annual files and source records preserved with the model. The complete metadata files listed in Section 13 are the machine-readable evidence. The report is an explanatory technical record and does not supersede those exact input and output bytes.

The following source locations identify the upstream products and method documentation. Their URLs are provided for provenance and further reading. Source versions and actual downloaded bytes are established by the retained manifests, not by whatever content a website serves after the run date.

| Source | Reference location |
| --- | --- |
| SWAP distribution and documentation | https://swap.wur.nl/downloads.html and https://swap.wur.nl/manual/ |
| SoilGrids WCS access | https://docs.isric.org/globaldata/soilgrids/wcs.html |
| SoilGrids properties and units | https://docs.isric.org/globaldata/soilgrids/soilgrids_layers.html |
| Rosetta implementation and method references | https://github.com/usda-ars-ussl/rosetta-soil |
| ESA WorldCover | https://esa-worldcover.org/en/data-access |
| CORINE Land Cover 2018 | https://land.copernicus.eu/en/products/corine-land-cover/clc2018 |
| Actual CORINE vector service | https://image.discomap.eea.europa.eu/arcgis/rest/services/Corine/CLC2018_LAEA/MapServer/0 |
| Local habitat interpretation | https://natura2000.vlaanderen.be/gebied/kalmthoutse-heide |
| NHI vegetation resistance source | https://nhi.nu/tooling/gewasweerstanden-tool/ |
| Source weather API time convention | https://open-meteo.com/en/docs/historical-weather-api |

The previous local soil and wet-heath investigations remain useful context and potential sources for refinement. They are not silently incorporated as regional parameter estimates or as validation of V02. This boundary between collected evidence, implemented assumptions and tested output should remain explicit when the next model version is constructed.
