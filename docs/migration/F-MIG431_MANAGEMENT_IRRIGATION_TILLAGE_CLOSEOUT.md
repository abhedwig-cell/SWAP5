# SWAP 4.3.1/B1.11 management, irrigation and tillage closeout matrix

Date: 2026-10-05  
Status: `SOURCE_CENSUS_COMPLETE_MIGRATION_IN_PROGRESS`  
Canonical baseline checked: `integration/f-ci-canonical` at `c1322db6e5551e95dcb4f86d707d22a6316f86e6`
Work branch: `work/f-mig431-management-irrigation-tillage-closeout`

This is the authoritative selector-level census for the management, irrigation,
tillage and crop-calendar family. It records physical capability, required
state, current SWAP5 coverage and a closed disposition for every source selector
found in the corrected B1.11 authority. It is designed to be incorporated into
the total SWAP431 functional-coverage closeout.

`ADMITTED` means the named bounded SWAP5 route is canonically admitted. It does
not imply that every combination of neighboring selectors is admitted.
`MIGRATE` means relevant functionality remains outside the admitted production
route. Existing process fragments are recorded as coverage, not mistaken for
production admission. `SUPERSEDED` means an admitted SWAP5 mechanism replaces
the legacy physical role. `REJECTED` identifies an obsolete or known-defective
input route that SWAP5 must fail closed on. `NOT_APPLICABLE` identifies a
legacy function outside the SWAP5 water-management boundary, with its owner
named below.

## Irrigation selector census

| Legacy selector / route | Physical meaning | Required state | Current SWAP5 coverage | Disposition |
| --- | --- | --- | --- | --- |
| `irrigevent=0` | No irrigation during the interval | None | Default inactive typed event | `ADMITTED` |
| `SWIRFIX=0/1` | Disable or enable the dated fixed-event list | Explicit event enable flag and accepted next-event pointer | Disabled default is a no-op; the exact Hupsel fixed surface event is admitted in PR #265, while generic fixed sprinkler/SSDI events remain process-qualified only | `ADMITTED` for disabled and bounded Hupsel surface route; `MIGRATE` for generic enabled fixed events |
| Fixed event list: `irdate`, `irdepth`, `irrate`, `irconc`, `irtype` | Apply a dated gross depth at a bounded rate; route as sprinkler, surface or subsurface input | Next-event index and active-event interval; immutable event table | Typed process qualifies ordered fixed sprinkler, surface and multi-node SSDI events with split rollback and restart; a typed three-route forcing composition selects intercepted Rutter, direct top or subsurface source and checks source mass at O0/O2. PR #265 admits the exact fixed surface event only | `MIGRATE` for generic production routes |
| `schedule=0` | Disable criterion-based scheduling | None | Typed scheduled evaluator has an explicit disabled gate | `ADMITTED` |
| `schedule=1`, crop emergence and `startirr`/`endirr` windows | Allow crop-stage-dependent irrigation only in selected source windows | Crop state, interval window, accepted event progress | F-APP07 covers its qualified application window; WOFOST crop-event runtime provides accepted daily crop-event state but does not own a general calendar scheduler | `MIGRATE` outside the admitted Hupsel window |
| `SWIRGFIL=1`, `IRGFIL`, fixed `IRDATE` table | Read dated events from a separate legacy `.irg` file | File cursor/unit and next-event index | Typed event tables can replace the physical event list; SWAP5 has no reason to retain the legacy file grammar or cursor | `SUPERSEDED` |
| Missing fixed-event `IRRATE` | Legacy derives a 24-hour application rate from the supplied depth | Depth and date | Typed fixed events require explicit depth and rate; a binder proves the B1.11 `IRDEPTH/24` mm/h fallback equals `depth_cm` per day at O0/O2 | `SUPERSEDED` by the equivalent explicit typed rate |
| Scheduled `isuas=0` sprinkler, `TCS=1`, `DCS=2`, `TCSFIX=1` | Crop-stage trigger and fixed-depth sprinkling, intercepted before net top input | Crop stage, day counter, irrigation window and gross/net interception receipt | PR #265 canonically admits the exact Hupsel TCS1/DCS2 sprinkling composition through Rutter/dynamic top: 110 active B1.11 intervals, 18 SWINTER=0 and 92 SWINTER=3 | `ADMITTED` within PR #265 envelope |
| Fixed `irtype=1` surface event | Direct fixed-date surface application, not canopy-intercepted | Dated event state and surface boundary receipt | PR #265 admits the exact fixed `SWIRFIX=1` Hupsel surface event. PPA-WU03 separately admits already-resolved surface irrigation input | `ADMITTED` within those bounded routes |
| Generic scheduled `isuas=1` surface irrigation | Criterion-scheduled direct surface application | Criterion state, event state and surface boundary receipt | Typed TCS2/3/4/6/7/8 plus DCS1/2 evaluator emits direct surface flux and the generic forcing composer selects dynamic top; no admitted accepted application trial | `MIGRATE` |
| Fixed `irtype=0` sprinkler | Surface sprinkler input subject to canopy interception | Event state and gross/net partition | Typed fixed-event output has a Rutter binding that preserves interception; three-route composer selects Rutter, and F-APP07 regression preserves the exact admitted 110-interval route. Generic fixed-sprinkler application trial is not admitted | `MIGRATE` |
| `isuas` / fixed `irtype`: `2` SSDI | Inject irrigation over a selected subsurface node or interval | Event state, source node interval, distributed source and mass receipt | Fixed-event process distributes over a configured node interval; scheduled process emits at the configured node; typed forcing composer preserves the existing subsurface source and checks mass, with restart state. A bounded O0/O2 real Reference dispatch/restart probe feeds a dated fixed SSDI event from the typed evaluator into the Reference source, publishes its pointer only after a matching accepted mass receipt, and removes the source at event end. An atomic joint restart wrapper validates irrigation records before restoring any physical or management state; corruption rolls back both and reversed runtime order restores by column ID. The fixture balances added drainage against SSDI for an analytically stationary profile; hard interval mass and endpoint identity pass. Nonstationary irrigation response and broader production orchestration remain open. RossFast D3R rejects nonzero SSDI | `MIGRATE` |
| `ss_irr_z` / fixed `ir_z` single depth or two-depth interval | Locate SSDI in one compartment or a consecutive subsurface node span | Ordered compartment-bottom depths and selected node indices | Typed scheduled node and fixed node-span fields carry the same physical placement; depth-to-node binder reproduces the B1.11 compartment-bottom tolerance and rejects out-of-profile/reversed depths at O0/O2. Production configuration binding remains open | `MIGRATE` for physical placement; `SUPERSEDED` for legacy scalar/array input grammar |
| `TCS=1` | Trigger on daily transpiration reduction from drought and salinity | Crop stage, daily potential/actual transpiration reductions, event gate | PR #265 admits TCS1 paired with DCS2 and TCSFIX=1 for the Hupsel potato route. It does not admit all crops, depth policies or solute-control combinations | `ADMITTED` within PR #265 envelope |
| `TREL` crop-stage table | Supply the critical transpiration-reduction fraction for TCS1 | DVS and admitted daily transpiration-reduction receipt | PR #265 uses the admitted Hupsel TCS1 threshold table with the exact daily oracle | `ADMITTED` within PR #265 envelope |
| `TCS=2` | Trigger when root-zone readily available water is depleted below the crop-stage fraction | Hydraulic state, root depth, field-capacity/critical limits, crop stage | Typed evaluator implements B1.11 weighted root-zone `awlh`/`awmh`/`awah` formula using effective compartment thickness; independent formula oracle passes O0/O2. No admitted production composition | `MIGRATE` |
| `TCS=3` | Trigger when root-zone total available water depletion exceeds the crop-stage fraction | Hydraulic state, root depth, wilting/critical limits, crop stage | Typed evaluator implements B1.11 weighted `awlh`/`awah` depletion fraction with partial root-zone compartment support; independent formula oracle passes O0/O2. No admitted production composition | `MIGRATE` |
| `TCS=4` | Trigger after crop-stage-specific absolute depletion amount | Hydraulic state, root depth, crop stage | Typed evaluator compares weighted root-zone FC deficit in cm with AFGEN threshold converted from mm; independent over/under-threshold oracle passes O0/O2. No admitted production composition | `MIGRATE` |
| `RAW`, `TAW`, `DWA` crop-stage tables | Set TCS2 readily available, TCS3 total available and TCS4 absolute depletion thresholds | DVS lookup and root-zone water amounts | Typed AFGEN tables and weighted depletion oracles pass O0/O2 with the respective criteria | `MIGRATE` with TCS2/3/4 production binding |
| `TCS=5` | Obsolete combined pressure-head/water-content criterion | None; source rejects it | B1.11 `irrigation` emits an obsolete-option error and directs users to TCS7 or TCS8 | `REJECTED` |
| `TCS=6` | Weekly/fixed-interval opportunity gated by irrigation deficit threshold | `dayfix`, deficit, threshold, event gate | Typed weekly counter now advances transactionally, evaluates the B1.11 `10*cdef > irgthreshold` test on day seven, persists through irrigation restart state, and rolls back on rejected event splits. O0/O2 oracle passes; no admitted production composition | `MIGRATE` |
| `TCS=7` | Trigger when pressure head at `dcrit` is at or below a crop-stage threshold | Sensor-node pressure head, DVS lookup, event state | Typed scheduler and O0/O2 process qualification cover AFGEN threshold/depth, SSDI rate placement, event split/replay and mass closure. A schema-versioned restart record roundtrips active events; a typed runtime adapter adds accepted SSDI rates to the SWAP subsurface source while preserving other sources. No admitted production composition | `MIGRATE` |
| `TCS=8` | Trigger when water content at `dcrit` is at or below a crop-stage threshold | Sensor-node water content, DVS lookup, event state | Typed criterion now has an independent AFGEN and `theta <= theta_crit` process oracle at O0/O2; no admitted production binding | `MIGRATE` |
| `VALUE_TC7`, `VALUE_TC8`, `dcrit` | Select the crop-stage pressure-head or water-content threshold and sensing depth | AFGEN table and hydraulic sensor-node binding | Typed TCS7/8 tables and node observation oracles pass O0/O2; depth-to-node configuration binding remains open | `MIGRATE` with TCS7/8 production binding |
| `TCSFIX=1`, `irgdayfix` | Require a minimum day interval between scheduled events | Day counter and previous event progress | PR #265 admits the TCSFIX=1 cadence within its TCS1/DCS2 Hupsel route | `ADMITTED` within PR #265 envelope |
| `TCSFIX=0` | Do not impose the optional fixed-day cadence on another timing criterion | Selected timing criterion and accepted event state | Typed TCS2/3/4/6/7/8 process owns its own selection opportunity and event lifecycle; no generic production admission | `MIGRATE` with the selected generic criterion |
| `DCS=1` | Return root-zone water toward field capacity, with crop-stage under/over-depth adjustment and rain subtraction | Hydraulic profile, field capacity, crop stage, rain, event state | Typed evaluator computes weighted FC deficit, adds AFGEN `di` in mm converted to cm, subtracts gross rain only above `raithreshold`, and shares the `DCSLIM` bounds; independent boundary/formula oracle passes O0/O2. No admitted production composition | `MIGRATE` |
| `PHFIELDCAPACITY`, `HLIM3H`, `HLIM3L`, `HLIM4` | Define field-capacity, medium and wilting pressure heads used to derive TCS2/3/4 and DCS1 soil-water limits | Constitutive retention at each layer and root-zone mapping | Typed binder samples the constitutive VG curve at each layer-bottom representative node and fans the three water limits across that layer; O0/O2 oracle validates the source mapping. Production configuration composition remains open | `MIGRATE` for configured physical limits |
| `DI`, `RAITHRESHOLD` | Apply crop-stage DCS1 correction and suppress a rain reduction below a gross-rain threshold | DVS table and current rainfall | Typed DCS1 oracle covers the signed mm adjustment and strict rain threshold at O0/O2 | `MIGRATE` with DCS1 production binding |
| `DCS=2` | Apply prescribed crop-stage-specific fixed depth | Crop-stage lookup and active event/rate state | PR #265 admits DCS2 paired with TCS1/TCSFIX=1 for the Hupsel sprinkling route. The independent TCS7 process check exercises its typed SSDI depth lookup only | `ADMITTED` within PR #265 envelope |
| `FID` crop-stage table | Supply the DCS2 fixed irrigation depth | DVS lookup | Admitted Hupsel DCS2 table is preserved by PR #265; typed scheduled evaluator also qualifies its depth interpolation O0/O2 | `ADMITTED` within PR #265 envelope |
| `DCSLIM=1`, `irgdepmin`/`irgdepmax` | Bound the selected irrigation depth | Selected depth and configured limits | Typed evaluator applies the legacy mm-to-cm min/max bounds after DCS1 or DCS2 selection; boundary oracle passes O0/O2. No admitted generic production route | `MIGRATE` |
| `SWCIRRTHRES`, `cirrthres`, `perirrsurp` | Increase scheduled irrigation depth when soil concentration at the sensor exceeds its threshold | Soil solute profile at `nodsen`, event depth, threshold and surplus percentage | A typed pure evaluator qualifies the source's strict `cml(nodsen) > cirrthres` and post-DCSLIM percentage formula at O0/O2. It has no admitted solute-profile input or coupled application | `MIGRATE`, dependent on solute/salinity admission |
| `TASK=4`, external `f_irr_avail` | Bound a requested irrigation amount by external water availability | Accepted allocation fraction, selected event and delivered-water receipt | A typed selector derives delivered depth, rate and duration with `rate × duration = available depth` at O0/O2. No admitted allocation arbitration. B1.11 scales surface rate and duration together but only SSDI duration, yielding inconsistent actual amounts | `MIGRATE` for allocation-limited physical delivery; `REJECTED` for the inconsistent legacy scaling |
| `cirr`/`cirrs` | Carry irrigation solute concentration into water/solute accounting | Event concentration and solute state | Surface water routing exists in restricted profiles; no admitted irrigation-solute delivery | `MIGRATE`, dependent on solute admission |
| `irr_rate`, `dt_irr_event`, `gird`, `qssdi` | Convert depth and rate into a bounded event span and source flux | Active event timing, effective rate and source receipt | Typed fixed/scheduled interval processes calculate duration and flux; scheduled rate below depth/day is adapted to one day and missing rate uses depth/day as B1.11 does. Effective rate persists across split/restart with O0/O2 mass closure. Production application remains open outside F-APP07 | `MIGRATE` for unsupported production modes |
| Irrigation `TASK=2` former-day `.END` crop reading | Recover legacy standalone crop state before scheduling | File cursor and historical crop record | SWAP5's accepted crop-state/event owner supplies the physical DVS and emergence observations; the old `.END` cursor has no independent physics | `SUPERSEDED` by typed accepted crop observations |
| Irrigation `TASK=9` event-end reset | Clear `irrigevent`, rates and SSDI source at an event boundary | Active event end and accepted event state | Typed fixed/scheduled evaluators clear active event identity and rate at the exact accepted boundary; the next interval starts with a fresh zero flux | `SUPERSEDED` by transactional event lifecycle |

## Tillage selector and state census

| Legacy selector / route | Physical meaning | Required state | Current SWAP5 coverage | Disposition |
| --- | --- | --- | --- | --- |
| `SWTILL=0` | No tillage transformation | None | No-op/default behavior | `ADMITTED` |
| `SWTILL=1` and dated event tables | Change bulk density within an event depth according to event type and intensity; continue consolidation between events | Next event index, preceding type parameters, density history, consolidation parameters, layer/horizon mapping | Typed event and inter-event consolidation transactions compose pointer, cumulative accepted rain, density, VG transform, redistribution and inverse head in an unpublished candidate; O0/O2 full-profile restart/continuation passes. Production solver-state application remains open | `MIGRATE` |
| `i_n_model=1` | Keep van Genuchten `n` unchanged as density changes | Hydraulic parameters and density history | Typed constitutive transform preserves `n`, regenerates `m`, and qualifies B1.11 density exponents at O0/O2; no application binding | `MIGRATE` |
| `i_n_model=2` | Derive `n` from silt/clay ratio | Texture, density and hydraulic parameter state | Positive-clay typed formula passes O0/O2; the known `PCLAY=0` divide-by-zero from SWAP-003 fails closed | `MIGRATE` for valid positive-clay inputs; `REJECTED` for the known `PCLAY=0` route |
| `i_n_model=3` | Derive `n` from a configured matching density and `n` point | `Rho_match`, `N_match`, consolidation density and prior `n` | Typed binder derives the B1.11 matching slope, rejects coincident densities before division, and the VG transform applies it at O0/O2; production material binding remains open | `MIGRATE` for valid matching parameters; `REJECTED` for the source's zero-denominator route |
| `iRedist=1` / `2` | Redistribute water state after hydraulic parameter changes using simple / complex method | Full soil-water profile and old/new constitutive state | Typed alternatives conserve thickness-weighted soil water plus pond, including saturation overflow, at O0/O2. A typed binder computes the inverse VG pressure head and verifies roundtrip retention; production accepted-state application remains open. Exact B1.11 redistribution arithmetic is rejected because it mixes water content and water depth | `MIGRATE` for physical redistribution; `REJECTED` for the legacy nonconserving arithmetic |
| `iRedist=0` | Test-only path; production code rejects it outside technical test mode | Test flag | Not a supported physical production selection | `REJECTED` |
| `Date_tillage`, `Z_tillage`, `I_tillage`, `Type_tillage` | Event date, depth, intensity and type select where and how the transition applies | Ordered event table, next-event pointer, horizon/compartment mapping | Corrected SWAP-002 event pointer, typed restart and a `Z_tillage` horizon-bottom depth binder produce the transaction mask with O0/O2 tests; non-boundary depths fail closed. SWAP-004 type-index/allocation defect remains in reference | `MIGRATE` with typed validation; the defective legacy ordinal-index mapping is `REJECTED` |
| `iType_tillage` material-type table | Map each event's type to consecutive layer-specific density and consolidation parameter rows | Explicit type IDs, row spans and affected layer counts | Typed mapper accepts sparse but explicit type IDs, rejects missing/interleaved or layer-count-mismatched blocks at O0/O2, and never indexes by legacy event ordinal | `MIGRATE` for material mapping; `REJECTED` for the B1.11 SWAP-004 unsafe ordinal-index route |
| `Rho_tillage`, `Rho_cons`, `k_R`, `Rho_match`, `N_match` | Target density, consolidation density/rate and optional matching point parameterize hydraulic transition | Per-layer parameter tables and prior density | Typed event and inter-event transactions apply the accepted cumulative net-rain density formula and transform the VG profile at O0/O2. Exact source substitution of instantaneous `nraidt` rate for cumulative rain is rejected | `MIGRATE` for physical transition; `REJECTED` for legacy rate-as-amount consolidation |
| Tillage interaction gates (`SWHYST`, `SWSOLU`, `SWMACRO`, `FLKSATEXM`, `SWDISCRVERT`, `SWCROPSNM` physical oxygen) | Legacy rejects selected interacting features or configurations | Configuration combination | The typed event transaction fails closed on all six B1.11 exclusions; macropore rejection is exercised O0/O2. Broader combinations have no admitted tillage application envelope | `MIGRATE` for validated compatible envelope; `REJECTED` for these incompatible combinations |

## Other management and crop-calendar functions

| Legacy selector / route | Physical meaning | Required state | Current SWAP5 coverage | Disposition |
| --- | --- | --- | --- | --- |
| `SoilManagement`: `smedate`, `iMat`, `Dosagekgha`, `VolatFraction`, material definitions | Apply organic/mineral amendments and update nutrient/carbon pools and outputs | Amendment catalogue, event table, N/P/organic matter pools, volatilization and crop uptake | No SWAP5 admitted biogeochemical management owner; this is nutrient/ANIMO scope, not water irrigation/tillage | `NOT_APPLICABLE` to this hydrologic closeout; transfer to ANIMO/solute coverage |
| `SoilManagement`: `FOM1_t`–`FOM8_t`, `Bio_t`, `Hum_t`, `cNH4_t`, `cNO3_t`, nitrification/denitrification and crop N-uptake controls | Initialize and evolve nutrient/organic-matter pools and exchanges | Biogeochemical state, amendment receipts, solute fluxes and crop N demand | These fields do not control the admitted SWAP5 irrigation or tillage water balance; they belong to the separate ANIMO/solute functional census | `NOT_APPLICABLE` to this hydrologic family; transfer explicitly to ANIMO/solute coverage |
| `SoilManagement` `flCropExt`, `_crop_ext.csv`, `_nut.csv`, `_nut.end` | Standalone output and restart-file formatting of crop/nutrient results | Legacy file units and record cursor | No distinct water-management physics; typed nutrient owner must define its own outputs | `SUPERSEDED` for standalone file-output mechanics; nutrient content is `NOT_APPLICABLE` here |
| `cropstart`/`cropend`, crop rotation sequence and calendar selection | Select active crop and its management window | Ordered crop events, calendar origin, active crop identity | WOFOST81 crop physics and one-day accepted crop-event transaction are admitted; typed rotation selector validates nonoverlap and protects the terminal next-crop boundary at O0/O2 as corrected by SWAP-005. Production calendar orchestration is open | `MIGRATE` as typed event/config orchestration; do not copy legacy parser/cursors |
| `SWPREP=0/1`, `zPrep`, `hPrep`, `maxprepdelay` | Start crop preparation immediately or delay it while average soil head is too wet, up to the maximum delay | Crop-start event, monitored depth/head and accepted delay counter | Explicit accepted crop events cover the immediate WOFOST81 route; typed accepted-day gate qualifies wetness and maximum delay at O0/O2. A bounded typed profile observer now computes the source's depth-weighted pF/head at O0/O2; accepted production profile and crop-event publication remain open | `SUPERSEDED` for the immediate accepted-event route; `MIGRATE` for wetness-delayed preparation |
| `SWSOW=0/1`, `zSow`, `hSow`, `zTempSow`, `TempSow`, `maxsowdelay` | Sow immediately or delay while soil is too wet or too cold, with a maximum delay | Crop preparation receipt, soil head and heat at the monitoring node, accepted delay counter | Explicit WOFOST81 crop-event route covers immediate sowing; typed gate qualifies wet/cold tests and maximum delay. Typed profile observer selects the source compartment-bottom soil temperature and weighted pF/head at O0/O2; production soil-heat owner and `SWHEA=1` compatibility remain open | `SUPERSEDED` for the immediate accepted-event route; `MIGRATE` for conditional sowing |
| `SWGERM=0/1/2`, `tsumemeopt`, `tbasem`, `teffmx`, `hdrygerm`, `hwetgerm`, `zgerm`, `agerm` | Immediate emergence, temperature-sum emergence, or hydrology-adjusted thermal emergence | Daily temperature, average head, accumulated heat, emergence state | WOFOST81 owns growth after an accepted emergence event; typed daily evaluator qualifies temperature-sum and dry/wet head response at O0/O2, and a versioned crop-identity restart roundtrips the accepted sum. Typed profile observer computes the source's depth-weighted pF/head; production observation and event publication remain open | `SUPERSEDED` for immediate accepted emergence; `MIGRATE` for thermal and hydraulic delay modes |
| Legacy `bgerm`, `cgerm` input | Former user coefficients for hydrology-adjusted germination | None: B1.11 derives them from the other germination parameters | B1.11 explicitly warns they are no longer inputs | `REJECTED` as user selectors |
| Legacy `preparation`, `sowing`, `germination`, thermal/moisture sowing rules | Select and initialize emergence from crop-calendar and soil/temperature conditions | Sowing opportunity, soil heat/moisture, thermal accumulation, crop state | WOFOST81 runtime covers bounded crop physics after explicit accepted crop events; legacy sowing/calendar selection is not established as covered | `MIGRATE` only where needed by the target application; retain WOFOST81 as crop-physics owner |
| Legacy crop-growth state (`DVS`, canopy, biomass, root extension/distribution) on a WOFOST crop route | Evolve crop physiology, canopy and root profile | WOFOST continuation plus accepted crop-event identity | Admitted WOFOST81 process replaces the equivalent legacy SWAP crop-growth calculation for the admitted WOFOST81 profile | `SUPERSEDED` on WOFOST81 profiles |
| Legacy file parsing, `rdinit` cursors, saved module globals, output-only management files | Standalone executable input/output control | File-unit and global cursor state | SWAP5 accepts typed application events and transactional process state; no corresponding physics role | `SUPERSEDED` |

## Source and evidence basis

The corrected source authority is the repository's immutable B0 archive plus
the ordered B1.11 patches, not an inferred historical file copy. Its archive
identity is `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`,
with 63 expanded members and manifest identity
`d923ac9aa474e9ef78cd8c5c51a9ca6ce6b4fb549a61180461da04ce1af4922f`. The
available 63-member expanded tree matched every B0 member hash and size. The
relevant B1.11 derivations were independently reconstructed and matched their
snapshot hashes:

| B1.11 source | Corrected SHA-256 | Governing record |
| --- | --- | --- |
| `SWAP/irrigation.f90` | `65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1` | Unchanged B0 member; `snapshots/B1.11.yml` |
| `SWAP/tillage.f90` | `eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3` | SWAP-002 correction to `set_iTill`; SWAP-003/004 remain outside B1.11 |
| `SWAP/MOD_cropdevelopment.f90` | `aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210` | SWAP-005 crop-rotation sequence bounds correction |
| `SWAP/management_soil.f90` | `0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b` | Unchanged B0 member; `snapshots/B1.11.yml` |
| `SWAP/readswap.f90` | `e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c` | SWAP-013 ordered input-validation correction |

Source selectors were read from `irrigation.f90`, `tillage.f90`,
`management_soil.f90`, `MOD_cropdevelopment.f90` and `readswap.f90`; physical
irrigation routing was cross-checked in `MOD_meteo.f90`. The relevant B1 fixes
are explicit: SWAP-002's corrected tillage start-event pointer is retained;
the known SWAP-003 and SWAP-004 tillage defects are not reintroduced. SWAP-005
guards crop-rotation indexing by checking the next crop only when one exists.

Current SWAP5 admission authority includes PR #265, merged at
`2fee154ca4a043842d8970c93ccbe820dc90c673`, for the exact Hupsel TCS1/DCS2/
TCSFIX=1 sprinkling plus fixed SWIRFIX=1 surface event composition. The
canonical ancestor `9605fbb1622d96f4691117f66264f13b6dd3a47b` is a
descendant of that merge. `F-APP07_ADMISSION_READY.json` and
`F-APP07_OWNER_COMPOSITION_QUALIFICATION.json` retain a pre-admission
checkpoint; PR #265 and the current canonical ancestry resolve that stale
pending status. PPA-WU03 is separately canonically admitted for already
resolved surface irrigation; F-CI89 is canonically admitted for the bounded
WOFOST81 one-day crop transaction. The typed irrigation process in
`src/process/mod_irrigation_process.f90` is broader than these production
admissions but is not itself end-to-end production admission.

The canonical advance from `9605fbb` to `c1322db` consists of the bounded
MIGMAC02 macropore admission and closeout (three commits). Its changed
Reference backend calls, soil-water solver contract and legacy headcalc
macropore iteration policy are on this work unit's compile dependency
surface, even though this unit's bounded irrigation probe disables
macropores. The work branch was merged with `c1322db` at `d6e9a441`; all ten
changed canonical production blobs were materialized locally and checked
against their GitHub blob SHAs. The managed Reference SSDI O0/O2 dispatch,
restart and mass probe, all 13 narrow irrigation/tillage/calendar gates, and
F-APP07's exact 110-interval composition passed on that combined production
postimage. This is local preservation, not a new canonical admission of the
broader MIGRATE routes.

## Local qualification completed in this work unit

`tests/irrigation/run_mig431_reference_binding.sh` passes O0/O2 against the
locally materialized `c1322db` production blobs. It composes a real fixed
SSDI event on `[t0,tm]` into the Reference FMR19 batch, proves accepted
publication by column/time/mass receipt, removes the event source on
`[tm,t1]`, and compares continuous with restarted endpoints, revisions and
mass. `mod_fmr_irrigation_joint_restart` wraps the physical and irrigation
records in one typed bundle. It validates every management record and
restores the physical bundle into unpublished candidates before committing
both arrays together; a corrupt record preserves the uninitialized physical
targets and initial management pointers. The extra drainage exactly cancels
the tiny SSDI input, so this gate does not establish a nonstationary water
response or a general production event orchestrator.

A local falsification variant removed the compensating drainage while
retaining the tiny `1e-10 cm/day` event source and the FMR19 hard mass gate.
Even with 24 rather than 8 nonlinear iterations and a looser head tolerance,
the first interval was rejected as `CANONICAL_STATUS_TRANSACTION_FAILED`;
no state was committed. That negative result is specific to the stationary
FMR19 fixture and cannot be presented as a general SSDI impossibility.
Nonstationary SSDI needs a dedicated admitted hydraulic setup and diagnostic
receipt, rather than extrapolation from the compensated fixture.
A separate diagnostic run widened only the trial mass gate from `1e-12` to
`1e-8 cm`; it still failed the transaction before any mass receipt. The
admitted hard gate was not changed in production or qualification tests.

`tests/irrigation/run_mig431_tcs7_ssdi_process.sh` passed at O0 and O2. Its
independent oracle checks dated fixed sprinkler/surface/multi-node SSDI events,
split rollback, restart and source mass; B1.11 TCS2/3/4 weighted root-zone depletion formulas,
the TCS6 seven-day counter, threshold, restart and split rollback, DCS1 crop-stage
adjustment/rain cutoff/DCSLIM bounds, TCS7 threshold interpolation and `h <= hcrit`,
trigger direction, DCS2 depth interpolation, SSDI node placement, source-rate
mass closure, event-end splitting, rejected-span nonpublication, and deterministic
retry/replay from the same committed state. It also exports and restores a
mid-event state using `mod_fmr_irrigation_restart`, rejects unsupported schema,
and verifies identical continuation mass. This qualifies the process and
state-record slice only. It does not qualify a production application binding
or canonical admission. For that reason TCS7/SSDI remain `MIGRATE` in the
matrix.

The scheduled-rate oracle also covers B1.11's one-day adaptation when
`IRR_RATE` is too low, and day-wide supply when it is absent. The effective
rate is part of irrigation restart schema 2; a partial SSDI event resumes
after restart with the same rate and exact prescribed total depth. F-APP07
still preserves its 110 exact intervals and zero composition error.

`tests/tillage/run_mig431_tillage_constitutive.sh` passed at O0 and O2.
It checks the corrected B1.11 start-event pointer, density event interpolation,
cumulative-rain consolidation, the three van Genuchten `n` choices, zero-clay
rejection, both redistribution modes with thickness-weighted soil-plus-pond
closure, and rejection of unsupported mode zero. These are process oracles;
the later event, binding and restart checks below do not establish a
production tillage admission without accepted solver-state application.

The `i_n_model=3` oracle also derives `(n-N_match)/(Rho_cons-Rho_match)`
from source parameters and rejects coincident densities, another explicit
division-by-zero risk in the B1.11 source.

`tests/tillage/run_mig431_tillage_owner.sh` passed at O0 and O2. It verifies
event-boundary splitting leaves committed state unchanged, applies the event
exactly at its start, resets cumulative accepted rain, and resumes the next
event pointer and rain after a schema-versioned restart. This still needs a
hydraulic-state application transaction before tillage can be admitted.

`tests/tillage/run_mig431_tillage_binding.sh` passed at O0 and O2. It
checks water-plus-pond closure and roundtrips the resulting water content
through the inverse van Genuchten pressure head, including a saturated node
and invalid-parameter rejection. It qualifies a typed candidate, not an
accepted solver-state mutation.

`tests/tillage/run_mig431_tillage_transaction.sh` passed at O0 and O2. An
event at the exact interval start yields one candidate containing the next
event pointer, intensity-adjusted density, VG parameters, redistributed
water/pond and inverse head. A span crossing the event and an unsupported
redistribution mode publish no hydraulic candidate; the committed owner
remains unchanged until the caller accepts it. Inter-event density
solver-state application remains outside this check. A schema-versioned
profile record validates event count, compartment count and VG retention
consistency, then reproduces the inter-event candidate after restart. An inter-event step
uses only rain accepted since the latest event to consolidate density and
reconstruct hydraulics with closed water mass. The transaction rejects the
six B1.11 tillage interaction exclusions before constructing a candidate.

`tests/irrigation/run_mig431_solute_depth.sh` passed at O0 and O2. It
checks the B1.11 strict concentration threshold, the surplus percentage
applied after base-depth selection, a disabled gate, and invalid percentage
rejection. No solute concentration can be inferred from hydraulic state;
coupled input and solute mass accounting remain separate admissions.

`tests/irrigation/run_mig431_depth_binding.sh` passed at O0 and O2. It
checks the B1.11 single-depth and consecutive-compartment placement from
ordered compartment bottoms with the source tolerance, and rejects a
reversed or out-of-profile interval.
The same O0/O2 test proves that missing fixed-event `IRRATE` gives exactly
one day at the typed rate, and checks explicit mm/hour to cm/day conversion.

The F-APP07 composition runner also passes the typed three-route forcing
oracle at O0/O2. It selects Rutter for gross sprinkler input, dynamic top
for direct surface input, and an additive subsurface source for SSDI; a
source-mass mismatch publishes no forcing. Its original Hupsel 110-interval
composition still has zero error. Actual solver-trial publication and
management-state acceptance remain open for the generic routes.

`tests/irrigation/run_mig431_water_limits.sh` passed at O0 and O2. It
checks the source's layer-bottom retention sampling for field-capacity,
medium and wilting limits, including a distinct upper-node curve that must
not replace the representative layer-bottom curve.

`tests/irrigation/run_mig431_availability.sh` passed at O0 and O2. It
selects the externally available fraction before event publication and
checks delivered depth equals effective rate times duration, including a
zero-availability and missing-rate case. The legacy `TASK=4` surface/SSDI
scaling discrepancy is not used as a mass-accounting authority.

`tests/tillage/run_mig431_tillage_types.sh` passed at O0 and O2. It
maps a sparse explicit material-type table to exact per-event row spans and
rejects missing, interleaved and layer-count-mismatched blocks. The unsafe
B1.11 event-ordinal indexing is not reused.

`tests/tillage/run_mig431_tillage_depth.sh` passed at O0 and O2. It maps
positive event depth and compartment thickness to a horizon-bottom mask,
rejecting a depth that cuts across a horizon. The event-transaction test
constructs its affected nodes through this binder.

`tests/management/run_mig431_crop_calendar.sh` passed at O0 and O2. It
checks the B1.11 preparation/sowing wetness and temperature thresholds,
accepted-day maximum delays, thermal accumulation, dry-head reduction,
immediate emergence and invalid-mode rejection. Its proposed state is
immutable until accepted. A schema-versioned restart roundtrips the accepted
temperature sum and counters under an exact crop-event identity and rejects
an identity mismatch. Production crop-event orchestration and observation
binding remain open.

The same script now qualifies a bounded profile observation binder at O0/O2:
source `h_average` uses a thickness-weighted mean of `log10(max(1,-h))`
through a partially intersected compartment and converts back to head;
the sowing temperature samples the first compartment whose bottom reaches
`zTempSow`. Out-of-profile depths fail closed. A separate Reference-state
adapter reads the physical pressure profile and private, initialized soil
temperature continuation through its typed export API, rejecting absent
heat activation; its O0/O2 contract passes. A guarded committed-state
snapshot checks a complete result's column, revision and endpoint before
reading this profile, with mismatched provenance rejected in a synthetic
receipt test. A real accepted heat-enabled endpoint trial, daily crop-event
publication and crop/calendar restart coupling remain open.

`tests/management/run_mig431_crop_rotation.sh` passed at O0 and O2. It
checks before, within, and after crop windows, the terminal crop without a
next-index read, and overlap rejection, reflecting the SWAP-005 correction.

## Closeout gate

The family is not closed while any `MIGRATE` row lacks either (a) a bounded,
source-backed production admission, or (b) a documented `SUPERSEDED`,
`REJECTED` or `NOT_APPLICABLE` decision supported by the relevant usage and
physics authority. The current census has no unresolved/unknown selector. The
remaining implementation order is: extend the bounded accepted fixed SSDI
trial to a nonstationary response and connect scheduled and generic
sprinkler/surface composition, including rain/solute receipts and the
production state owner; connect the bounded
compatible tillage transaction to accepted hydraulic solver state and its
profile restart; connect the typed crop observation adapter to the live
accepted soil/heat endpoint and crop-event publication; then run the
affected cross-route preservation and persisted
admission gates. Coupled solute irrigation requires a separate solute mass
owner. These process and runtime candidates are deliberately not labeled
canonically admitted before those boundaries are proven.

The tillage application boundary also changes the constitutive `cofgen`
table, which currently belongs to the immutable
`fmr_b110_physical_parameters_t` and its parameter-set identity, while
pressure head, water content and pond belong to the committed physical
state. A production transaction must publish the new material identity and
the redistributed state together, and restore both together. Copying the
typed water candidate into a committed state while retaining the old
constitutive parameter set would make the next Richards step physically
inconsistent. This is the remaining tillage architecture dependency; the
qualified pure event transition is not a substitute for that publication.
