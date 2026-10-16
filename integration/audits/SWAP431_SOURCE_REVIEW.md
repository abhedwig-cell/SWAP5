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
  and FrozenBounds drain/bottom heuristics. The soil-temperature/frost equations
  have no soil-ice partition or latent-heat state. This does not describe snow:
  `snow.f90` has liquid retention and uses melting latent heat in rain-on-snow
  melt. Those terms belong to SW431-SNOW, not a soil phase-change capability.

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

MOD_meteo lines 1917–2001 has distinct traditional SWDIVIDE=0 and PMdirect=1 energy/resistance partitions. Detailed-record atmospheric demand also changes the temporal radiation term. F-APP03's daily PMdirect admission excludes detailed meteorology. Its historical SWCF=2 exclusion was subsequently superseded for the bounded Hupsel crop-height envelope by canonical F-APP05 merge 158ef1e70, owner and independent F-VQ115 qualification; the current daily evaluator is unchanged and the frozen observations pass again at O0/O2. Do not carry that old SWCF=2 exclusion forward as a live gap. SWCFBS=1 is also absent from the restricted reference-ET process, whose source comment specifies SWCFBS=0. Detailed interception continuation is a different admitted capability and does not settle these atmospheric-demand options.

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

The routine scan now also includes no-argument procedures, bringing navigation to 392 routine declarations/definitions. The statement-aware scanner now records 4085 executable control-branch statements and 1256 selector-branch statements; terminators such as END IF are excluded. These are source-navigation counts, not independent capability counts. The source Soil-N family separates ammonium/nitrate inventory/supply, analytical water/solute balance, nitrification, denitrification and crop biological N fixation. These have individual IDs under MC-NUT01 rather than hiding transformations inside an undifferentiated mineral-N gap. Rate constants depend on temperature/wetness; denitrification additionally depends on organic respiration. NFIXF partitions soil demand and biological fixation and books N fixation into crop balance. Current WOFOST81 donor mechanics exist, but its admitted N-unlimited request-equals-supply scope does not establish these additional source options or Soil-N coupling. No claim of missing crop-N algebra is made.

### Complete current PR inventory and MICRO successor

The paginated GitHub API snapshot contains all 114 open PRs and all 55 merged since 2026-10-05, with matching reported totals and no incomplete-results flag. The previous 100-item snapshot is historical/bounded. Ten migration-relevant open proposals are explicitly reconciled: older interception, oxygen, RFM, perched/core-macropore and frost-source holds do not reopen later canonical admissions. Performance research proposals are not legacy-coverage blockers.

PR1071 is an actual active PPA-MICRO02 standalone de Willigen workunit at 339cdec3af3fa97d1fcd19068b9ad2259a13e00c. Its draft description and persisted qualification identify a corrected-table nonlinear oracle plus real-MvG smoke, but explicitly exclude production root-sink binding, heterogeneous horizons, transaction/restart and signed lift. This source component work must be reused; MC-MICRO01's remaining runtime work is not a duplicate standalone evaluator. It does not change the canonical MICRO uptake disposition.

### Initial-state and nonlinear runoff source options

Cold start is distinct from restart file grammar. SWINCO1 interpolates HTB and projects the saturated bottom part to hydrostatic heads; SWINCO2 sets h=GWLI-z and pond=max(GWLI,0). The admitted typed initial-state route supplies those same resolved nodal heads and consistent water content directly, within its admitted hydraulic/state envelope. These are explicit SUPERSEDED initial-state capabilities; additional hysteresis/advanced constitutive initialization remains tied to its own open physics family.

The runoff selector was previously mislabeled RSIGNI, which actually belongs to evaporation; the source runoff controls are RSRO/RSROEXP/PONDMX. Source RSROEXP spans0.01..10, with nonlinear power-law runoff and iterative ponding. The current dynamic-top provider explicitly rejects active exponent !=1. SW431-RUNOFF-NONLINEAR is therefore a distinct confirmed production gap under MC-SUR01. Time-varying PONDMX itself is a supplied threshold series, represented by immutable interval ponding_max_cm values in the admitted linear surface route; this replacement does not close nonlinear runoff or extended surface-water inundation.

## Empirical oxygen admission correction and thermal remainder

The draft ledger previously cited C3A as admission of SWOXYGEN=1. That was incorrect: C3A explicitly admits only mode2/type1 Bartholomeus. Legacy empirical wet stress uses distinct HLIM1/HLIM2U/HLIM2L pressure-head factors; the current Feddes process is drought-only. SW431-ROOT-OXYGEN-EMP is restored to an actual open MC-ROOT01 capability. No canonical runtime admission is withdrawn by this audit correction.

The current thermal forcing/assembly proves absence of the five listed harmonic/flux/mixed/bottom-temperature/snow-interface routes. They are confirmed missing production implementations rather than unspecified qualification reviews. De Vries, sensible thermal state and prescribed surface temperature remain admitted.

## Statement-aware source scan

Schema1.2 joins free-form continuation lines, preserves quoted !/semicolon characters and doubled quotes, and splits independent semicolon statements. Four targeted lexical tests pass. The full 63-member scan retains 881 input-reader calls and 238 integer/boolean reader calls with zero unmapped navigation targets. Every continued record carries its first and final source line. This closes a scanner limitation; it does not declare the physics denominator exhaustive.

## Empirical macropore absorption and Darcy split

The A8 real-FMR fixture explicitly supplies positive empirical sorptivity alpha and SorpMax, current theta/heads and committed sorption history. The runtime implements the SWABS1 empirical power-law amount and restart fields. SW431-MACRO-SORP2 is therefore bounded ADMITTED for positive alpha and extra Darcy OFF; this does not qualify Parlange preparation or the full legacy parameter range.

SWDARCY=0 is functionally replaced by the typed zero unsaturated-exchange conductivity coefficient used in the actual A8 fixture. This coefficient is not the Richards soil conductivity; saturated horizontal conductivity/CDarcy are separate inputs. The resulting Darcy amount is exactly zero and sorption remains active. SWDARCY=1 is a different capability: source uses current K(ic), while current adapter retains immutable template conductivity instead of binding current constitutive K. That binding is missing, despite the presence of Darcy algebra. SWABS2 also requires a distinct diffusivity operator absent from the current request. No production source has been changed by these adjudications.

## Fixed-crop state and additional physical branches

CROPTYPE1 is not merely calendar/table parsing: IDEV1 advances DVS by 2/LCC; IDEV2 advances by max(0,TAV-TBASE)/TSUMEA or TSUMAM across anthesis. DVS/TSUM and previous WRT are continued process data. The two routes now have separate capability IDs. Typed crop views consume their results but do not implement these updates, so neither is written off as supplied-table compatibility. SWGC1 is just the deprecated GCTB-to-LAITB input alias; SWGC2 errors and has no executable soil-cover capability.

SWSEP1 Ernst horizontal/vertical/radial resistance and SWSEP2 Youngs seepage geometry are separate physical branches. Both have typed algebra, but the A8 coupled fixture disables saturated exchange; active branch coverage still needs admission reconciliation. Snow-insulated temperature driving frost is separate from bare sensible thermal frost and depends on TEMP-SNOW. Current explicit gates prove the listed frost and macro compositions blocked. Internal fixed-weir rapid-drain receipt is separated from externally prescribed surface-water level; the latter is not automatically classified as absent merely because the internal owner is blocked.

## Tillage selector correction and bounded source defects

I_N_MODEL1/2/3 changes the hydraulic n parameter (unchanged, silt/clay density power law, matching-point slope), not consolidation models. Shared theta_r/theta_s/Ksat/alpha changes precede water adaptation. Consolidate_Bdens uses exp(-K_R_cons*nraidt*10); the source itself questions this forcing substitution. Rain rate/amount and interval semantics need adjudication; no accepted time-clock model is inferred.

The literal extracted Adapt_WC_H routine is reproduced at O0/O2 in SWAP431_TILLAGE_DEFECT_PROBE.json. IREDIST1 turns oversaturation into negative pond: 3cm initial water becomes1cm including pond=-1cm. IREDIST2 selects branches by unweighted theta sums; a bounded equal-sum, unequal-thickness case skips the new-material inverse update. Its stubbed constitutive query is explicitly scoped, not a full trajectory qualification. These defects are registered for the reference-policy review; the intended conservative tillage capability stays open. Unadmitted SWAP003/004 changes are not adopted. IREDIST0 fatally errors outside TEST and is NOT_APPLICABLE production physics.

## Irrigation event-rate and interval branches

TCSFIX1 is already qualified with TCS1/DCS2 in F-APP07 and now has an explicit bounded ADMITTED entry. TCSFIX0 has no equivalent admitted owner binding; it must not be inferred from setting the minimum interval to1. Scheduled IRR_RATE0 uses depth/day; positive-rate requested duration>1 uses a depth-preserving rate adaptation. The admitted TCS1 owner requires positive rate and rejects duration>1, so these two fallback capabilities are explicit production gaps.

TASK4 is not discarded as plumbing: source scales gird and dt_irr_event by F_IRR_AVAIL, hence both rate and duration affect delivered volume. Actual callers and allocation semantics remain under source review. Fixed SSDI divides configured depth by node count (725..729), whereas scheduled SSDI sets each node to the requested rate/depth. Single-node and multi-node ownership must be qualified separately rather than assuming identical aggregate semantics.

## Actual remaining dependencies

Already admitted foundations are recorded as nonblocking closed_foundation_authorities rather than remaining dependencies. Queue depth is recomputed from only unresolved capability edges. Internal sequencing is separate from external workunit dependencies. Source-bound additions include runon before macropore runon, tillage events before consolidation/redistribution, mineral/organic inventories before amendment/residue coupling, soil supply before crop-N limitation, and sensor TCS7/8 before concentration-threshold excess irrigation. Legacy irrigation initializes SWCIRRTHRES only within TCS7/8 (irrigation.f90:279..302); tillage event/consolidation precedes hydraulic/water adaptation (tillage.f90:160..190). No closed admission is treated as a blocker.

## Static macropore geometry authority

SWPOWM belongs to macropore.f90 initialization (349), not macrorate.f90. It replaces PowM with its reciprocal below SPoint in the IC-frequency integral. Both the default depth-curve geometry and this alternate curve are explicit reviews. Typed runtime inputs carry resolved static capacity, domain fractions, endpoints and diameter, while legacy initialization integrates curves, temporarily splits cells and lumps IC domains. A generic array interface is evidence of a possible replacement route, not yet source-mapping/admission evidence. Existing dynamic shrinkage and covering admissions remain closed in their own envelopes.

## Soil-N ownership versus crop fixation

The actual WOFOST81 transaction supplies its full soil_request (334..347), preserving the admitted N-unlimited route. Crop N state/formulas exist, but no canonical production SoilManagement/Wofost_Soil* inventory/rate owner supplies the source organic/mineral transformations, amendment/residue, NH4/NO3 transport or limited soil-crop exchange. These eight entries have confirmed missing owner/binding evidence.

Biological fixation is different: mod_wofost81_nitrogen implements rnfixation and nfix_total, and PP02 component tests use nfix_fr=.2. Fullseason/PP03 runtime qualification uses0. Nonzero current81 admission is one review axis; the source-lineage correction below adds the distinct old vegetative-demand/DVSNLT gate replacement decision. Do not label the current81 fixation component absent or assume its nonzero runtime test would settle old source equivalence.

## WOFOST source lineage correction

F-WOF-PP01 MAPPING_CONTRACT explicitly pins SWAP_4.3.1_WOFOST81_WORKING_FINAL_13B.zip (4e0bf97b...) as its donor, distinct from the bundled B0/B1.11 authority (distribution2b48353d..., manifest24ce2768...). Literal B1.11 wofost.f90 uses AMAXTB(DVS); current WOFOST81 uses leaf-N assimilation. Literal wofostnut demand excludes storage/growth increments and gates fixation/soil uptake by DVS<DVSNLT and RELTR>.01; the current81 request differs. Current81 admission is preserved as SW5-CROP-WOF81 outside the legacy denominator. The B1.11 annual-crop entry is ACTIVE_MIGRATION for explicit replacement/source qualification; no historical WOFOST81 admission is reopened. Nonzero current81 fixation testing alone would not close the old gate semantics.

## Root extension and density subselectors

SWRD1 is a stateless DVS-to-depth table with rdm cap; SWRD3 uses WRTPOT/WRT and is prohibited with the simple crop. Their typed profile replacement mappings still need qualification. SWRD2 owns continued rd/rdpot/rr and gates growth by transpiration/root assimilates. SWDMI2RD0 keeps the daily maximum-rate increment,1 scales by IQROT/IPTRA, and2 applies minimum/drought-response and deepest-node biomass supply limits. These three continued growth routes are explicit production gaps. SWWRTNONOX gates actual SWRD2 only, not every root-depth option. Adaptive SWRDC1 node biomass and the independent SWLRVCONSTANT length-density override are separate entries.

## Surface-water primitive versus native shared carriers

The restricted fixed-weir owner remains ADMITTED with configured nonnegative drainage forcing, power-law discharge, supply and storage/restart. Its backend call passes that forcing unchanged; it does not take the just-accepted soil drainage receipt or feed its updated level into a native drain basis. Native drain/store feedback is an explicit gap. Signed qdrd is executable source storage depletion, but current provider rejects it as held-signed-route. Runoff is a separate source carrier absent from current forcing/binding. Automatic groundwater/air-volume/sensor target management and QH table rating also lack current owner fields/operators. These are not inferred admitted from the primitive.

WLSBAK/OSSWLM is a four-call numerical oscillation/timestep heuristic, not physical hydraulic history; it is NOT_APPLICABLE. Persistent automatic-target wlstar history is physical management state and remains in scope.

### Absolute root length density is not normalized uptake distribution

B1.11 `MOD_cropdevelopment.f90:2334..2358` first converts root mass to absolute LRV, then independently permits `SWLRVCONSTANT=1` to override it with `max(.01, AFGEN(RDCTB, -z/abs(zbotcp(noddrz))))`. `rootextraction.f90:118,234,239,251` supplies this LRV to MICRO and stress attribution. Current crop/Feddes contracts publish normalized cumulative root fractions; the canonical MICRO component supplies a matric-flux table only. Neither establishes the absolute-LRV resolver/consumer. `SW431-ROOT-LRV-CONSTANT` is therefore a confirmed production-binding gap, with a stateless typed resolver that does not require adaptive biomass history. The queue uses MICRO2 as the first planned consumer; MICRO3 can reuse the same carrier. This is not a final replacement admission.

### Irrigation decision rules versus prescribed fluxes

The current generic irrigation component has fixed-event geometry and TCS7/DCS2 scheduled SSDI parameters; the separately admitted sprinkling component has TCS1/DCS2 and a minimum event interval. Source `irrigation.f90:473..636` additionally evaluates RAW/TAW/absolute depletion (TCS2/3/4), a weekly deficit clock (TCS6), theta sensor timing (TCS8), field-capacity refill with rain deduction (DCS1), selected-depth min/max bounds, salinity-surplus depth and external availability scaling. Their necessary parameters/requests/evaluators are absent from both current components and their application binding. These nine entries are confirmed decision-rule gaps, not merely pending qualification of existing equivalent evaluators. Externally supplied irrigation fluxes do not close the decisions. Fixed sprinkling and scheduled-surface routing retain their separate reachability/admission reviews.

### Active Ernst and Youngs algebra exists; runtime envelope qualification remains

`probe_swap431_macropore_seepage.py` extracts the literal SWSEP1/2 seepage-face branch from B1.11 `macrorate.f90:1550..1561` and compares the typed saturated exchange component. All 48 cases per O0/O2 pass (largest relative error 1.96e-16), using positive horizontal K, two diameters/widths and full/quarter top matrix fractions. The external pi carrier is explicitly assumed `acos(-1)`. The typed factory and standard adapter carry SWSEP, K and matrix topology into this component; these are not absent formula implementations. The inherited A8 fixture has SWSEP0 and K=0 and therefore does not qualify the active branches. Both capabilities remain ACTIVE_MIGRATION for actual Richards/ownership/donor-cap/retry/restart qualification, with component evidence preserved and no new runtime admission claim.

### Historical SWCF2 hold removed against actual canonical admission

The Git ancestor `158ef1e704fbc72f293773cc30ae4d6082d3c28f` explicitly admits the F-APP05 restricted Hupsel SWCF2 aerodynamic crop-height route after owner/F-VQ114/F-VQ115 passes. F-APP05 preregistration and admission-ready records identify the typed field change and three frozen daily observations. The complete current daily evaluator equals the evaluator at the admitted merge; the later module diff adds only SWINTER0 interval handling. Existing daily observations pass locally at both O0 and O2. `SW431-ET-CROPHEIGHT` is ADMITTED within this envelope, correcting this audit's earlier reliance on the superseded F-APP03 hold. Detailed ET, traditional partition, soil-factor variants and generic crop materialization are not thereby admitted.

### Resumed canonical census: drainage selector correction

Canonical was fetched again at e5eab995ef04fc813dd644025fb0f32e4f5050a1.
The recovered published audit is 01fd0afe62a455bfff9f479bf83a1d070cb98aba.
The previous local continuation was not itself a Git recovery authority; its
MICRO, oxygen-type2, kinematic/Parlange and vernalisation conclusions were
rechecked against the unchanged source before inclusion here.

The master ledger had incorrectly assigned DRAMET1 to linear resistance and
DRAMET3 to tabulated drainage. Literal drainage.f90 and the admitted
Drainage-v1 scientific authority agree: DRAMET1 is the groundwater-depth table,
DRAMET2 is Hooghoudt/Ernst, DRAMET3 is per-level drainage/infiltration resistance
with OWLTAB head resolution, a drain-bottom clamp and directional controls.
The bounded one-way linear and highest-level empirical contributions remain
admitted, with their source selector and claim boundaries corrected. Their
existence does not admit the entire native DRAMET3 dispatcher.

Three distinct residuals are now explicit: native signed DRAMET3 controls and
resistance dispatch, ordinary signed default DIVDRA, and multiple interacting
DIVDRA discharge layers. Scalar multilevel aggregation with bottom-node lumping
is not the latter. Separate infiltration partition and fixed/fractional
redistribution at the top of a discharge layer retain their individual IDs.
The ordinary DIVDRA binding allocates one level and rejects negative transfer;
B18 is an isolated scientific component and is not a runtime counterexample.

The literal DRAMET3 branch and actual EXTENDED provider were compared locally
at O0/O2. With zero entry/exit resistance and GWLINF=ZBOTDR, three bulk cases
agree, but the independent EXTENDED 0.001 cm activation seam suppresses a
positive source flux near 5e-6 cm/day. The same probe verifies direction
suppression and channel-depth infiltration capping. Therefore a blanket
SUPERSEDED decision is not defensible. The constant OWLTAB test stub does not
qualify interpolation or full trajectories. See the replayable
SWAP431_DRAMET3_REPLACEMENT_PROBE.json evidence.

### Lower-boundary and rainfall residuals narrowed

SWBOTB9 is selectable input, not merely a private mode: DATE9A/HBOT9 and
DATE9B/QBOT9 supply two histories. BoundBottom overwrites the last cell's
head/theta/K; HeadCalc solves numnod-1 cells and Fluxes excludes mode9 from
bottom-flux reconstruction. The master retains this as an explicit physical
ownership/migration decision. No unexecuted global mass-defect claim or
unapproved scope rejection is inferred. The explicit SWBOTB3 variant also
remains distinct: its GWL/SHAPE_3 and saturated-profile resistance calculation
is absent from the implicit Cauchy application route.

SWRAIN1 constructs a midnight-start pulse using min(1,depth/intensity) and
rate=depth/duration. SWRAIN2 uses WET duration. SWRAIN3 derives rates from
end-stamped interval amounts and reconstructs daily totals. The time controller
clips to rain events. Generic typed rate intervals can carry these resolved
inputs, but do not by themselves implement their derivation or qualify daily
interception/snow composition. The first two need a typed stateless resolver;
the third needs a source-bound mapping/envelope qualification. None needs the
old file cursor as kernel state.

### Persistent vernalisation and other recovered source findings

IDSL2 in wofost.f90 accumulates VERN and FL_VERNALISED. The canonical common
crop parameter validator permits only IDSL0/1 and its crop owner lacks that
history. Vernalisation is now a distinct open capability; daylength forcing is
not its replacement. The classical AMAXTB crop component also exists in the
canonical tree: source-envelope reconciliation remains necessary and absence
of the entire annual-crop implementation is not claimed.

SWSORP1 derives SorpMax/SorpAlfa through hydraulic diffusivity integration and
fitting; the empirical runtime operator accepts these parameters but does not
supply that resolver. SWMBF2 instead requires NKWT wave/storage propagation;
the production configuration fixes SWMBF1 and rejects 2. The canonical MICRO
component still ends at the table at this baseline. PR1077 is a bounded draft
runtime successor, excluding de Jong van Lier, lift and stress composition;
it must not be counted as canonical admission or independently reimplemented.

The separate top-interflow partition (SWTOPNRSRF1) was also missing from the
ordinary census. It first distributes the highest level down to its physical
drain bottom and excludes that layer from subsequent levels. This is neither
SWDISLAY truncation nor B15's highest scalar response. Its new individual ID
is SW431-DRAIN-DIV-TOPINTERFLOW. The empirical reader name SWINTFL maps into
the source variable SWNRSRF; both names remain explicit navigation aliases.
