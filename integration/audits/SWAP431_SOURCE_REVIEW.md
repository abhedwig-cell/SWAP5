# SWAP431 master coverage source review

Status: IN_PROGRESS_SOURCE_CENSUS. Baseline: integration/f-ci-canonical
`ca856e88e582d468a6f40971ce1f2a75e5089c40`, 2026-10-06.

This record is a recoverable census, not a declaration of full functional
coverage. The master JSON records bounded admissions and registered source
review/migration tasks separately. ACTIVE_MIGRATION can mean that replacement
or envelope evidence still needs adjudication; it does not prove that no code
exists. No new physics has been admitted by this audit.

## Source identity

The original distribution was recovered and checked through the repository's
ordered B0 to B1.11 reconstruction. All 63 B1.11 members, 1,886,519 bytes,
match manifest SHA256
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.
The evidence directory retains a deterministic compressed exact-byte source
bundle, every member hash, B0 member hashes and the changed-member list.
The integer-reader inventory is reproducible navigation; it is not alone an
exhaustive execution-path denominator. Real and logical controls and
source-reachable combinations also matter.

## Source exclusions established directly

- `MOD_cropdevelopment.f90`, read_stressors: compensation with SWDROUGHT > 1
  resets compensation to zero and raises swap_error. RootExtraction dispatches
  drought 1 to MACRO, 2/3 to MICRO. External Jarvis/Walsum after MICRO is not a
  source capability. MICRO itself is independent missing coverage.
- The salinity reader admits SWSALINITY 0..1. Osmotic-head option 2 is only
  mentioned in a comment, not an executable selected capability.
- MICRO explicitly errors for SWFROST. The main reader prohibits simultaneous
  SWFROST and SWMACRO. These combinations are not legacy migration gaps.
- `read_macropore` explicitly errors for SWSOLU > 0. Macropore solute is not an
  executable B1.11 capability. Future solute research does not change that fact.
- Macropore initialization iterates rapid drainage over `ir=1,1`. The rate
  routine uses one selected NumLevRapDra. This does not supply simultaneous
  multiple rapid-drain levels; ordinary multilevel drainage is separate.
- SWBMA selects yearly BMA balance output, not additional exchange physics.
- TCS5 raises an error and directs callers to the executable TCS7/8 routes.
- Frost modifies hydraulic conductivity/derivative, empirical root extraction
  and FrozenBounds drain/bottom heuristics. There is no ice/liquid partition or
  latent-heat state/equation in the recovered source. Phase change is outside
  this denominator.

## Independent persistent or stateful physics

Hysteresis is real hydraulic history. `hysteresis.f90` updates INDEKS, FHYST and
DELP, reversals, head and capacity. Initial wetting/drying is selected by
SWHYST 1/2. Default MvG and crack shrinkage history do not replace this.

MICRO supplies nonlinear MFLP soil/root-interface/xylem/leaf potentials, separate
Jong van Lier and de Willigen formulations, root density, saturated uptake,
stress attribution and optional hydraulic lift. Its Upw is the water sink;
UpwPot is potential/diagnostic. Saved arrays must be traced for cross-call
physical history versus reconstructible solver workspace before a candidate,
commit and restart contract can be approved. Feddes does not supply these
potential-network semantics.

The solute family includes nonlinear sorption, decomposition, aquifer salt
storage and breakthrough, pond solute and a water-age tracer. The admitted
mobile matrix salt plus Maas-Hoffman/Jarvis/Walsum/root-frost chain does not
close those distinct states and equations.

Tillage changes bulk density, hydraulic parameters, consolidation history and
water redistribution. Soil-N management contains organic turnover, mineral
transport, nitrification/denitrification, amendments, residues and N-limited
crop coupling. Potential-production Spring Barley does not replace soil N.

## Canonical reconciliation

INT13/Rutter, INT12-D/Gash and INT12-E detailed continuation are admitted within
their recorded envelopes. D2/D3, EXACT01, matrix salt, WALSAL01 and SALFRO01
are admitted. MIGMAC01..09 and PERCH21 supersede older standard-macro gap
labels. A26 is bounded live RFM admitted, but is not proof of the legacy
SWMBF2 kinematic-wave equation. SWMBF2 and the nondefault SWABS/SWSEP/SWPOWM/
SWDARCY source paths need individual review.

Frost B1..B15 admissions cover the enumerated bounded runtime profiles. B16/17
repair reference authority; B18 admits a scientific component, not backend
runtime. B19's selected runtime slice remains unimplemented and needs its
source-bound contract. Isolated B18 qualification cannot close runtime DIVDRA.

LOW03-A explicitly leaves explicit SWBOTB3 open. Its GWL/saturated-profile
resistance semantics must not be written off as merely numerical policy.
SWBOTB9 imposes both head and flux and resets last-node head/theta/K; it is
accepted by the reader and is not automatically executable plumbing.

## Decision boundaries

Historical open PRs do not reopen later canonical admissions. The retained
open-PR snapshot is bounded to the first 100 updated results and is navigation,
not an exhaustive PR inventory. No family-level rejection is made solely to
reduce the queue. The ledger's review tasks must be resolved before a final
missing-functionality count or CLOSED declaration is defensible.

## Live canonical delta

Canonical advanced to `e5eab995ef04fc813dd644025fb0f32e4f5050a1` while this review was running. All ten commits and the 18-file delta were reconciled locally. MICRO01 is a canonically admitted isolated corrected matric-flux table component; its own status explicitly sets runtime_admitted=false. It does not close either microscopic uptake formulation or hydraulic lift.

The MICRO initialization guard at RWU_micro.f90 line 232 rejects SWDOSATREL=1. Reader acceptance is not execution reachability; this selector is explicitly NOT_APPLICABLE. The internal optimal-root diagnostic has its own reachable saturated-allocation logic and remains inside MICRO stress adjudication.

### Irrigation runtime and hydraulic dispatcher refinement

Current src searches find only definitions of evaluate_fixed_irrigation_interval and evaluate_scheduled_irrigation_interval, no runtime callers. F-CI19 independently records qualified F-VQ18/F-VQ20 fixed/TCS7/DCS2 single-node SSDI process semantics and absent higher composition. TCS7 and SSDI therefore have proven missing production binding, despite existing process code. This must not erase the later separate F-APP07 TCS1/DCS2 sprinkling application admission.

Hydraulic model 4 is unscaled unimodal MvG; 5 is its finite dry-end normalized form; 6/7 are unscaled/normalized bimodal MvG. PDI is 8/9 unimodal and 10/11 bimodal, with normalization in 9/11. The source reader's broad PDI label is insufficient authority for those distinctions. Model 4's physical capability is replaced by the admitted default MvG provider as explained in the disposition decisions and bounded local curve evidence.

### Meteo and runon source/runtime reconciliation

MOD_meteo lines 1917–2001 has distinct traditional SWDIVIDE=0 and PMdirect=1 energy/resistance partitions. Detailed-record atmospheric demand also changes the temporal radiation term. F-APP03's daily PMdirect admission explicitly excludes detailed meteorology and SWCF=2; the existence of a crop-height branch in the process does not qualify that envelope. SWCFBS=1 is also absent from the restricted reference-ET process, whose source comment specifies SWCFBS=0. Detailed interception continuation is a different admitted capability and does not settle these atmospheric-demand options.

SWRAIN1 derives a day-start pulse duration min(1, daily rain / seasonal RAINTB intensity). SWRAIN2 instead uses the supplied WET duration. SWRAIN3 derives rates from successive cumulative-record endpoint times and record amounts; it is not an independent rainfall generator. Generic typed forcing covers already-resolved interval rates, but the exact preprocessing/first-record/source-window semantics still need a bounded replacement decision. The .rain file grammar itself belongs to legacy I/O.

MOD_runon performs the same kind of external time/amount preparation; it contains no general routing model. Boundtop adds runon after the macropore partition of rain/irrigation/melt. The typed dynamic-top provider includes this term, while current mod_b110_production_soil_water_task2 rejects swrunon /= 0 (line339), and PPA-WU03 rejects nonzero runon in its input boundary. This is a proven production-binding restriction, not absent flux algebra.

### Input-reader navigation closeout

All 238 integer/boolean input-reader calls now have a source-bound navigation target, including computed per-level swallo/swdtyp names and computed restart readers. The 68 previously unmapped calls were parameters, dates, discretization, reporting controls or named subcontrols of existing families; their explicit source_input_names are stored in the master ledger. In particular numnodNew belongs to output regridding, flCropExt only enables a crop-residue CSV, and maximum iteration/time controls are numerical executable policy. This is navigation completeness, not a claim that every associated physical selector or execution path is admitted. Global denominator completeness remains false until routine/branch and composition adjudication is complete.

### Thermal gap-record corrections after direct code inspection

The earlier caller-supplied-constant-property hypothesis was wrong. mod_restricted_soil_temperature calls evaluate_devries using mean interval-start/end theta and immutable quartz/clay/organic fractions. F-CI43 explicitly qualified the De Vries oracle and F-CI45P records canonical runtime composition, whose current backend calls trial_restricted_soil_temperature. SW431-TEMP-DEVries is therefore ADMITTED within the existing thermal envelope.

SWTOPBHEA2 supplies a prescribed surface temperature; the admitted typed forcing delivers that same Dirichlet capability per interval. The old measured-temperature file grammar is separate I/O. For SWTOPBHEA1 without snow, the literal source simply sets TeTop=tav; the typed prescribed-temperature route therefore supersedes that source selector when the caller supplies resolved air temperature. The source snow-covered soil/interface resistance formula remains SW431-TEMP-SNOW and is not disposed of by this mapping. Top flux (3), temperature plus flux (4), bottom prescribed temperature (2) and analytic annual-wave modes remain distinct.

### Bottom concentration is a typed forcing replacement

solute.f90 lines553–574 defines SWBOTBC0 as Cseep=Cdrain, 1 as independently supplied Cseep and 2 as a supplied date/concentration series; line315 resolves the latter with afgen. All feed the same bottom advective receipt. The admitted matrix mobile route validates typed matrix_bottom_mg_cm3 with units, source/revision identity and interval coverage and passes it to the same owned transport candidate. Shared/constant/time-varying external bottom concentration is therefore SUPERSEDED by that general typed route within the admitted matrix envelope. The caller resolves the source value per immutable interval. SWBR1 aquifer evolution is a distinct still-open reservoir capability and is not covered by this disposition.

### Additional Soil-N capabilities from complete source routines

The routine scan now also includes no-argument procedures, bringing navigation to 392 routines and 6073 control-branch locations. This is source navigation, not 6073 independent capabilities. The source Soil-N family separates ammonium/nitrate inventory/supply, analytical water/solute balance, nitrification, denitrification and crop biological N fixation. These have individual IDs under MC-NUT01 rather than hiding transformations inside an undifferentiated mineral-N gap. Rate constants depend on temperature/wetness; denitrification additionally depends on organic respiration. NFIXF partitions soil demand and biological fixation and books N fixation into crop balance. Current WOFOST81 donor mechanics exist, but its admitted N-unlimited request-equals-supply scope does not establish these additional source options or Soil-N coupling. No claim of missing crop-N algebra is made.

### Complete current PR inventory and MICRO successor

The paginated GitHub API snapshot contains all 114 open PRs and all 55 merged since 2026-10-05, with matching reported totals and no incomplete-results flag. The previous 100-item snapshot is historical/bounded. Ten migration-relevant open proposals are explicitly reconciled: older interception, oxygen, RFM, perched/core-macropore and frost-source holds do not reopen later canonical admissions. Performance research proposals are not legacy-coverage blockers.

PR1071 is an actual active PPA-MICRO02 standalone de Willigen workunit at 339cdec3af3fa97d1fcd19068b9ad2259a13e00c. Its draft description and persisted qualification identify a corrected-table nonlinear oracle plus real-MvG smoke, but explicitly exclude production root-sink binding, heterogeneous horizons, transaction/restart and signed lift. This source component work must be reused; MC-MICRO01's remaining runtime work is not a duplicate standalone evaluator. It does not change the canonical MICRO uptake disposition.

### Initial-state and nonlinear runoff source options

Cold start is distinct from restart file grammar. SWINCO1 interpolates HTB and projects the saturated bottom part to hydrostatic heads; SWINCO2 sets h=GWLI-z and pond=max(GWLI,0). The admitted typed initial-state route supplies those same resolved nodal heads and consistent water content directly, within its admitted hydraulic/state envelope. These are explicit SUPERSEDED initial-state capabilities; additional hysteresis/advanced constitutive initialization remains tied to its own open physics family.

The runoff selector was previously mislabeled RSIGNI, which actually belongs to evaporation; the source runoff controls are RSRO/RSROEXP/PONDMX. Source RSROEXP spans0.01..10, with nonlinear power-law runoff and iterative ponding. The current dynamic-top provider explicitly rejects active exponent !=1. SW431-RUNOFF-NONLINEAR is therefore a distinct confirmed production gap under MC-SUR01. Time-varying PONDMX itself is a supplied threshold series, represented by immutable interval ponding_max_cm values in the admitted linear surface route; this replacement does not close nonlinear runoff or extended surface-water inundation.

## Empirical oxygen admission correction and thermal remainder

The draft ledger previously cited C3A as admission of SWOXYGEN=1. That was incorrect: C3A explicitly admits only mode2/type1 Bartholomeus. Legacy empirical wet stress uses distinct HLIM1/HLIM2U/HLIM2L pressure-head factors; the current Feddes process is drought-only. SW431-ROOT-OXYGEN-EMP is restored to an actual open MC-ROOT01 capability. No canonical runtime admission is withdrawn by this audit correction.

The current thermal forcing/assembly proves absence of the five listed harmonic/flux/mixed/bottom-temperature/snow-interface routes. They are confirmed missing production implementations rather than unspecified qualification reviews. De Vries, sensible thermal state and prescribed surface temperature remain admitted.
