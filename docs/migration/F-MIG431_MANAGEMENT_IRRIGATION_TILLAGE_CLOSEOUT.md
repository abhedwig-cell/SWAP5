# SWAP 4.3.1/B1.11 management, irrigation and tillage closeout matrix

Date: 2026-10-05  
Status: `SOURCE_CENSUS_COMPLETE_MIGRATION_IN_PROGRESS`  
Canonical baseline checked: `integration/f-ci-canonical` at `9605fbb1622d96f4691117f66264f13b6dd3a47b`  
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
| Fixed event list: `irdate`, `irdepth`, `irrate`, `irconc`, `irtype` | Apply a dated gross depth at a bounded rate; route as sprinkler, surface or subsurface input | Next-event index and active-event interval; immutable event table | Typed process qualifies ordered fixed sprinkler, surface and multi-node SSDI events with split rollback and restart; typed bindings route sprinkler through Rutter and SSDI into the SWAP subsurface source. PR #265 admits the exact fixed surface event only | `MIGRATE` for generic routes |
| `schedule=0` | Disable criterion-based scheduling | None | Typed scheduled evaluator has an explicit disabled gate | `ADMITTED` |
| `schedule=1`, crop emergence and `startirr`/`endirr` windows | Allow crop-stage-dependent irrigation only in selected source windows | Crop state, interval window, accepted event progress | F-APP07 covers its qualified application window; WOFOST crop-event runtime provides accepted daily crop-event state but does not own a general calendar scheduler | `MIGRATE` outside the admitted Hupsel window |
| `SWIRGFIL=1`, `IRGFIL`, fixed `IRDATE` table | Read dated events from a separate legacy `.irg` file | File cursor/unit and next-event index | Typed event tables can replace the physical event list; SWAP5 has no reason to retain the legacy file grammar or cursor | `SUPERSEDED` |
| Scheduled `isuas=0` sprinkler, `TCS=1`, `DCS=2`, `TCSFIX=1` | Crop-stage trigger and fixed-depth sprinkling, intercepted before net top input | Crop stage, day counter, irrigation window and gross/net interception receipt | PR #265 canonically admits the exact Hupsel TCS1/DCS2 sprinkling composition through Rutter/dynamic top: 110 active B1.11 intervals, 18 SWINTER=0 and 92 SWINTER=3 | `ADMITTED` within PR #265 envelope |
| Fixed `irtype=1` surface event | Direct fixed-date surface application, not canopy-intercepted | Dated event state and surface boundary receipt | PR #265 admits the exact fixed `SWIRFIX=1` Hupsel surface event. PPA-WU03 separately admits already-resolved surface irrigation input | `ADMITTED` within those bounded routes |
| Generic scheduled `isuas=1` surface irrigation | Criterion-scheduled direct surface application | Criterion state, event state and surface boundary receipt | Typed TCS2/3/4/6/7/8 plus DCS1/2 evaluator can emit the direct surface flux; no admitted production composition | `MIGRATE` |
| Fixed `irtype=0` sprinkler | Surface sprinkler input subject to canopy interception | Event state and gross/net partition | Typed fixed-event output has a Rutter binding that preserves interception; O0/O2 oracle checks split/restart and the F-APP07 regression preserves the exact admitted 110-interval route. Generic fixed-sprinkler production composition is not admitted | `MIGRATE` |
| `isuas` / fixed `irtype`: `2` SSDI | Inject irrigation over a selected subsurface node or interval | Event state, source node interval, distributed source and mass receipt | Fixed-event process distributes over a configured node interval; scheduled process emits at the configured node; typed runtime adapter adds source to the existing SWAP source vector, with restart state. No canonically admitted production composition | `MIGRATE` |
| `TCS=1` | Trigger on daily transpiration reduction from drought and salinity | Crop stage, daily potential/actual transpiration reductions, event gate | PR #265 admits TCS1 paired with DCS2 and TCSFIX=1 for the Hupsel potato route. It does not admit all crops, depth policies or solute-control combinations | `ADMITTED` within PR #265 envelope |
| `TCS=2` | Trigger when root-zone readily available water is depleted below the crop-stage fraction | Hydraulic state, root depth, field-capacity/critical limits, crop stage | Typed evaluator implements B1.11 weighted root-zone `awlh`/`awmh`/`awah` formula using effective compartment thickness; independent formula oracle passes O0/O2. No admitted production composition | `MIGRATE` |
| `TCS=3` | Trigger when root-zone total available water depletion exceeds the crop-stage fraction | Hydraulic state, root depth, wilting/critical limits, crop stage | Typed evaluator implements B1.11 weighted `awlh`/`awah` depletion fraction with partial root-zone compartment support; independent formula oracle passes O0/O2. No admitted production composition | `MIGRATE` |
| `TCS=4` | Trigger after crop-stage-specific absolute depletion amount | Hydraulic state, root depth, crop stage | Typed evaluator compares weighted root-zone FC deficit in cm with AFGEN threshold converted from mm; independent over/under-threshold oracle passes O0/O2. No admitted production composition | `MIGRATE` |
| `TCS=5` | Obsolete combined pressure-head/water-content criterion | None; source rejects it | B1.11 `irrigation` emits an obsolete-option error and directs users to TCS7 or TCS8 | `REJECTED` |
| `TCS=6` | Weekly/fixed-interval opportunity gated by irrigation deficit threshold | `dayfix`, deficit, threshold, event gate | Typed weekly counter now advances transactionally, evaluates the B1.11 `10*cdef > irgthreshold` test on day seven, persists through irrigation restart state, and rolls back on rejected event splits. O0/O2 oracle passes; no admitted production composition | `MIGRATE` |
| `TCS=7` | Trigger when pressure head at `dcrit` is at or below a crop-stage threshold | Sensor-node pressure head, DVS lookup, event state | Typed scheduler and O0/O2 process qualification cover AFGEN threshold/depth, SSDI rate placement, event split/replay and mass closure. A schema-versioned restart record roundtrips active events; a typed runtime adapter adds accepted SSDI rates to the SWAP subsurface source while preserving other sources. No admitted production composition | `MIGRATE` |
| `TCS=8` | Trigger when water content at `dcrit` is at or below a crop-stage threshold | Sensor-node water content, DVS lookup, event state | Typed criterion now has an independent AFGEN and `theta <= theta_crit` process oracle at O0/O2; no admitted production binding | `MIGRATE` |
| `TCSFIX=1`, `irgdayfix` | Require a minimum day interval between scheduled events | Day counter and previous event progress | PR #265 admits the TCSFIX=1 cadence within its TCS1/DCS2 Hupsel route | `ADMITTED` within PR #265 envelope |
| `DCS=1` | Return root-zone water toward field capacity, with crop-stage under/over-depth adjustment and rain subtraction | Hydraulic profile, field capacity, crop stage, rain, event state | Typed evaluator computes weighted FC deficit, adds AFGEN `di` in mm converted to cm, subtracts gross rain only above `raithreshold`, and shares the `DCSLIM` bounds; independent boundary/formula oracle passes O0/O2. No admitted production composition | `MIGRATE` |
| `DCS=2` | Apply prescribed crop-stage-specific fixed depth | Crop-stage lookup and active event/rate state | PR #265 admits DCS2 paired with TCS1/TCSFIX=1 for the Hupsel sprinkling route. The independent TCS7 process check exercises its typed SSDI depth lookup only | `ADMITTED` within PR #265 envelope |
| `DCSLIM=1`, `irgdepmin`/`irgdepmax` | Bound the selected irrigation depth | Selected depth and configured limits | Typed evaluator applies the legacy mm-to-cm min/max bounds after DCS1 or DCS2 selection; boundary oracle passes O0/O2. No admitted generic production route | `MIGRATE` |
| `SWCIRRTHRES`, `cirrthres`, `perirrsurp` | Add over-irrigation when irrigation-water solute concentration exceeds a soil concentration threshold | Soil solute profile, water concentration, event depth | SWAP5 does not admit this coupled solute-control route | `MIGRATE`, dependent on solute/salinity admission |
| `cirr`/`cirrs` | Carry irrigation solute concentration into water/solute accounting | Event concentration and solute state | Surface water routing exists in restricted profiles; no admitted irrigation-solute delivery | `MIGRATE`, dependent on solute admission |
| `irr_rate`, `dt_irr_event`, `gird`, `qssdi` | Convert depth and rate into a bounded event span and source flux | Active event timing and source receipt | Typed fixed/scheduled interval processes calculate duration and flux; runtime application/restart remains incomplete for non-F-APP07 modes | `MIGRATE` for unsupported modes |

## Tillage selector and state census

| Legacy selector / route | Physical meaning | Required state | Current SWAP5 coverage | Disposition |
| --- | --- | --- | --- | --- |
| `SWTILL=0` | No tillage transformation | None | No-op/default behavior | `ADMITTED` |
| `SWTILL=1` and dated event tables | Change bulk density within an event depth according to event type and intensity; continue consolidation between events | Next event index, preceding type parameters, density history, consolidation parameters, layer/horizon mapping | Typed event selection, density, constitutive and water-redistribution formulas pass O0/O2 oracles. Typed event owner has split/retry and schema-versioned restart tests. A hydraulic candidate binder reconstructs pressure head from the new VG curve with water-plus-pond closure; production accepted-state application and compatibility remain open | `MIGRATE` |
| `i_n_model=1` | Keep van Genuchten `n` unchanged as density changes | Hydraulic parameters and density history | Typed constitutive transform preserves `n`, regenerates `m`, and qualifies B1.11 density exponents at O0/O2; no application binding | `MIGRATE` |
| `i_n_model=2` | Derive `n` from silt/clay ratio | Texture, density and hydraulic parameter state | Positive-clay typed formula passes O0/O2; the known `PCLAY=0` divide-by-zero from SWAP-003 fails closed | `MIGRATE` for valid positive-clay inputs; `REJECTED` for the known `PCLAY=0` route |
| `i_n_model=3` | Derive `n` from a configured matching point | Matching water content/head, density and hydraulic parameter state | Typed formula applies a supplied persistent matching-point slope and regenerates `m`; no application binding | `MIGRATE` |
| `iRedist=1` / `2` | Redistribute water state after hydraulic parameter changes using simple / complex method | Full soil-water profile and old/new constitutive state | Typed alternatives conserve thickness-weighted soil water plus pond, including saturation overflow, at O0/O2. A typed binder computes the inverse VG pressure head and verifies roundtrip retention; production accepted-state application remains open. Exact B1.11 redistribution arithmetic is rejected because it mixes water content and water depth | `MIGRATE` for physical redistribution; `REJECTED` for the legacy nonconserving arithmetic |
| `iRedist=0` | Test-only path; production code rejects it outside technical test mode | Test flag | Not a supported physical production selection | `REJECTED` |
| `Date_tillage`, `Z_tillage`, `I_tillage`, `Type_tillage` | Event date, depth, intensity and type select where and how the transition applies | Ordered event table, next-event pointer, horizon/compartment mapping | Typed start selector reproduces corrected SWAP-002 boundary states and rejects duplicate/unexecutable dates. Typed owner persists the next pointer and cumulative accepted rain, rejects event-crossing spans without publishing state, and has O0/O2 restart/replay tests. SWAP-004 type-index/allocation defect remains in reference | `MIGRATE` with typed validation; malformed/sparse legacy type-index mapping is `REJECTED` |
| `Rho_tillage`, `Rho_cons`, `k_R`, `Rho_match`, `N_match` | Target density, consolidation density/rate and optional matching point parameterize hydraulic transition | Per-layer parameter tables and prior density | Typed density event, accepted cumulative net-rain consolidation and constitutive transformation pass O0/O2. Exact source substitution of instantaneous `nraidt` rate for cumulative rain is rejected | `MIGRATE` for physical transition; `REJECTED` for legacy rate-as-amount consolidation |
| Tillage interaction gates (`SWHYST`, `SWSOLU`, `SWMACRO`, `FLKSATEXM`, `SWDISCRVERT`, physical oxygen) | Legacy rejects selected interacting features or configurations | Configuration combination | No general tillage application envelope; combinations must remain explicit and fail closed | `MIGRATE` with bounded compatibility matrix; never inherit legacy global control flow |

## Other management and crop-calendar functions

| Legacy selector / route | Physical meaning | Required state | Current SWAP5 coverage | Disposition |
| --- | --- | --- | --- | --- |
| `SoilManagement`: `smedate`, `iMat`, `Dosagekgha`, `VolatFraction`, material definitions | Apply organic/mineral amendments and update nutrient/carbon pools and outputs | Amendment catalogue, event table, N/P/organic matter pools, volatilization and crop uptake | No SWAP5 admitted biogeochemical management owner; this is nutrient/ANIMO scope, not water irrigation/tillage | `NOT_APPLICABLE` to this hydrologic closeout; transfer to ANIMO/solute coverage |
| `cropstart`/`cropend`, crop rotation sequence and calendar selection | Select active crop and its management window | Ordered crop events, calendar origin, active crop identity | WOFOST81 crop physics and one-day accepted crop-event transaction are admitted; a general crop-calendar scheduler/config route is not admitted | `MIGRATE` as typed event/config orchestration; do not copy legacy parser/cursors |
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
current canonical head `9605fbb1622d96f4691117f66264f13b6dd3a47b` is a
descendant of that merge. `F-APP07_ADMISSION_READY.json` and
`F-APP07_OWNER_COMPOSITION_QUALIFICATION.json` retain a pre-admission
checkpoint; PR #265 and the current canonical ancestry resolve that stale
pending status. PPA-WU03 is separately canonically admitted for already
resolved surface irrigation; F-CI89 is canonically admitted for the bounded
WOFOST81 one-day crop transaction. The typed irrigation process in
`src/process/mod_irrigation_process.f90` is broader than these production
admissions but is not itself end-to-end production admission.

## Local qualification completed in this work unit

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

`tests/tillage/run_mig431_tillage_constitutive.sh` passed at O0 and O2.
It checks the corrected B1.11 start-event pointer, density event interpolation,
cumulative-rain consolidation, the three van Genuchten `n` choices, zero-clay
rejection, both redistribution modes with thickness-weighted soil-plus-pond
closure, and rejection of unsupported mode zero. These are process oracles,
not a production tillage admission: persistent event ownership, inverse head
update, compatibility and accepted-step replay remain open.

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

## Closeout gate

The family is not closed while any `MIGRATE` row lacks either (a) a bounded,
source-backed production admission, or (b) a documented `SUPERSEDED`,
`REJECTED` or `NOT_APPLICABLE` decision supported by the relevant usage and
physics authority. The current census has no unresolved/unknown selector. The
remaining implementation order is: finish TCS7/SSDI application binding; add
the other irrigation criteria and fixed routes in dependency
order; decide a bounded valid tillage envelope after the SWAP-003/004 input
boundary is explicit; then close the typed crop-calendar event adapter and
final cross-route preservation.
