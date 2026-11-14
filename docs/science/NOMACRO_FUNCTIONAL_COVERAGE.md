# Original no-macro functional coverage

## Scope and authority

Work unit **SWAP5-NOMACRO-COVERAGE01**, baseline canonical `e157e65ff`, extends
original project reachability through the existing hybrid daily controller.
The development and qualification recovery point is
`integration/nomacro-coverage01/RECOVERY.md`. Its versioned evidence and actual
canonical merge receipt own admission; this page does not establish a scientific
PASS. The frozen release branch `release/swap5-nomacro-rc1-20261112` is unchanged.

The three registered release profiles retain their separate authority in
[functional closure](SWAP5_FUNCTIONAL_CLOSURE.md). A general experimental input
route is separate from that production scope. Original oxygen failures,
underqualified references, thermal limits and the closed platform investigation's
scientific limitations remain unchanged.

## General original input route

The adapter derives calendar dates, original compartment count and solute mode
from the actual original `swap.swp`. The caller selects an input directory,
including relative input subdirectories, rather than a registered project name.
Every input byte, generated Fortran source, original object/library, compiler,
controller executable and process adapter is bound to the build and day restart.
Changes require a new build. Source-provider preparation still executes no model.

For example, from the repository root:

```bash
python -B tools/solute/run_water.py --no-macro-release --prepare-sources --reference-work ./provider
python -B tools/solute/prepare_saltfarm.py --run 2 --output ./saltfarm08-input
python -B tools/solute/run_water.py --model HYBRID_NOMACRO_WATER --experimental-project ./saltfarm08-input --reference-work ./provider --build-only --output ./saltfarm08-build
python -B tools/solute/run_water.py --model HYBRID_NOMACRO_WATER --experimental-project ./saltfarm08-input --reference-work ./provider --build-bundle ./saltfarm08-build --output ./saltfarm08-full --checkpoint-at 365
python -B tools/solute/run_water.py --model HYBRID_NOMACRO_WATER --experimental-project ./saltfarm08-input --reference-work ./provider --build-bundle ./saltfarm08-build --output ./saltfarm08-restarted --restart ./saltfarm08-full/accepted-column-1-day-365.zip --restart-day 365 --days 367
```

Run 3 selects original SaltFarm16dS. Output remains explicitly
`EXPERIMENTAL_NOT_PRODUCTION_QUALIFIED`, with scientific equivalence
`NOT_QUALIFIED`. `--no-macro-release` cannot be combined with this model.
The default hard model wall cap is60seconds; an explicit positive cap up to
300seconds is available. A cap/refusal is never reported as completion.

Numeric/physical input validation remains in the original TTUTIL/Fortran reader.
Before compilation or worker creation, the process adapter rejects active
macropores, unsupported state/ledger families, ambiguous selectors, symlinks,
absolute/parent references, reserved restart/output names and foreign reused
builds. Relative folders remain inside each worker's copied project. No physical
switch is silently changed. Validated crop signatures retain the original
Hupsel, Grassgrowth and SaltFarm process implementations, with general parameters
and project calendars. Original WOFOST/scheduled-irrigation management state is selected independently
of chemistry. Solute runs retain their conserved chemical auxiliary state;
experimental water-only runs use their distinct management format. The registered
grass-only water path retains its own native state, and unqualified water-only
hydraulic/snow history remains explicitly refused.

## First implementation block

The generic Fortran controller accepts `HYBRID_NOMACRO_WATER` using explicit
grid/calendar metadata and the strict `1e-10cm` water guard. It retains the
original source water solver, physical process ordering, numerical controls,
source-based trial rollback and original native plus auxiliary day-state codecs.
No new solver, general process framework or performance policy is introduced.

The first executed coverage cohort includes:

| Configuration | Original relationship | New reachable functionality |
| --- | --- | --- |
| SaltFarm08dS | Workbook run2; same independent SaltFarm project | Original higher-salinity irrigation and crop stress trajectory |
| SaltFarm16dS | Workbook run3; same independent SaltFarm project | Original16dS irrigation/stress trajectory |
| Hupsel free bottom | Derived original input, only SWBOTB6to7 | Original free-drainage bottom law |
| Hupsel no drainage | Derived original input, only SWDRA1to0 | Short execution; full-period FAIL retained at day51 |

These are two new workbook configurations and two derived process
configurations, **zero new independent historical projects**. The pinned
distribution contains only three independent no-macro projects; its fourth
independent project, Andelst, activates macropores and remains outside scope.

Qualification compiles actual Fortran O0/O2 controller builds, runs complete O2
periods and short O0 controls, checks independent daily water/solute balances,
exact own day-state continuations and complete native/auxiliary endpoints,
alternating independent workers at distinct physical origins, external
discard/replay/disk recovery and an actually refused inconsistent-mass candidate.
The three registered release applications have separate complete-period and
O0/O2 public-command regressions on the changed host. Evidence is reported only
after those checks complete on the persisted source.

The literal SaltFarm template requests `S_CONC`, which the original executable
refuses before simulation. That failure is retained. An additional run changes
only CSV field selection, reporting interval and precision and uses the unchanged
original executable. Its actual differences are diagnostic comparison evidence;
they do not turn the literal failure or inherited scientific failures into PASS.

## Remaining process boundaries

The source-based A/B/C/D inventory is in the recovery record. Source presence
does not establish execution, restart correctness or scientific qualification.

The first block at PR1669 admitted original Mualem/van Genuchten or table
hydraulics without hysteresis, supported atmospheric forcing, bottom modes1to7 (solute substep receipt excludes reconstructed modes1/5),
no drainage or original methods2/3, existing crop signatures, numerical heat with
the supported boundaries and conservative solute without adsorption/decay or a
mixed aquifer reservoir. Not every permitted parameter combination has full-period
evidence. Original numeric/physical validation and runtime mass guards remain
mandatory for every experimental run.

The qualified second block below connects hysteresis, snow and adsorption/decay.
Frost remains a separate source/state/corrected-reference gap.
Other drainage/surfacewater methods, analytical
heat/boundary variants, age tracer, arbitrary crop-memory combinations and
subsurface irrigation retain their distinct integration/evidence gaps. A new
stateful combination is not enabled solely because its Fortran routine exists.
Active macro functionality and macro-only processes are outside this work unit.

The platform/performance workstream's separate math probes and original B0/B1
macropore research are not incorporated. The admitted durable restart publisher
and existing strict acceptance thresholds are retained.


The undrained Hupsel request is **not a full-period PASS**. At source335656c6f,
50days are accepted; day51 independently reports1.0001328931696918e-10cm and
is refused by the unchanged1e-10cm guard. The projected substep sum is
9.991413595525985e-11cm. This near-boundary disagreement is retained, not
rounded into admission or used to start a general solver campaign. Own49to51
replay and absence of rejected-day publication are checked separately.

## Original state and reaction block

Qualified source `12ae9114857b97bb5cbe3dd587703f2e96ef7b7f`, hosted
run43406084493, passes all three cohorts: the seven new process configurations,
the entire first block (including its retained failure), and the registered
three-profile release regression. `integration/nomacro-coverage01/BLOCK_B_STATUS.json`
owns the evidence and subsequent actual canonical admission.

| New derived configuration | Complete days | Functionality |
| --- | ---: | --- |
| Hupsel hysteresis1 | 1096 | Original wetting-start scanning curves |
| Hupsel hysteresis2 | 1096 | Original drying-start scanning curves |
| Hupsel snow | 1096 | Positive snow accumulation/melt and original snow/soil heat boundary |
| Hupsel snow plus hysteresis1 | 1096 | Combined original snow and hydraulic history |
| SaltFarm08 sorption | 1461 | Nonlinear Freundlich adsorption |
| SaltFarm08 decay | 1461 | Positive decomposition with original moisture/depth response |
| SaltFarm08 sorption plus decay | 1461 | Combined original reactions and saline crop trajectory |

These are8767 additional complete model days, not seven independent historical
projects. Each configuration has checked O0/O2 builds, own2to4 and365to367
continuations, byte-exact complete native/auxiliary endpoint files, alternating
workers at distinct physical origins, external discard/replay/recovery and a
deliberately inconsistent mass candidate refused without commit. Sixteen
resealed history corruptions exercise the actual native decoder: wrong format,
truncation, NaN and negative state; no rejected target is published. Maximum
accepted water/solute residuals remain below the unchanged1e-10 bounds.

The first hysteresis execution exposed a real restart gap: native H and scanning
variables do not preserve the accepted hydraulic carry after hysteresis changes
the head/curve. Only experimental active hysteresis adds accepted theta,
conductivity/interface conductivity, capacity, head, volume and groundwater to
its auxiliary state. This restores exact continuation without changing the
original hydraulic law or Newton policy.

The first snow continuation reproduced the water rows but changed the native
temperature profile. The original snow-interface boundary uses the previously
accepted `heacon(1)` before updating heat properties. Native TSOIL alone therefore
does not define its continuation. Only active experimental snow now preserves
conductivity, heat capacity and the two thermal boundaries. History combinations
have distinct auxiliary formats; inactive options add no fields. The original
no-history formats and registered production input remain unchanged.

Conserved `cmsy` already includes dissolved plus adsorbed solute. The existing
native aqueous state, conserved auxiliary state and independent decomposition
ledger therefore support the original sorption/decay bodies without rewriting
them. The derived SaltFarm tests explicitly use Freundlich exponent0.9,
reference concentration1.0, layer coefficients0.0001389/0.0001378 and/or
potential decay0.001/day with depth factors1.0/0.65. These parameterized process
tests are distinguished from the original workbook configurations.

Frost remains refused. The preserved FROST-GEOMETRY-01 correction excludes
SWDIVD1 and general production admission, while Hupsel uses SWDIVD1. No
uncorrected frost defect or unrelated B0/B1 correction is silently adopted.
Full physical energy and whole scientific equivalence remain unqualified.

## Basic original options and complete future-input checks

Qualified source `24a5ed08cce662470015a6d4c6e7f9cbcd9583c2`, hosted
run43408409505, completes seven further derived1096-day configurations:
bare soil/free bottom; bare soil/no heat/free bottom; cultivated no-heat maize
rotation; undrained/free bottom; prescribed bottom-flux table; sinusoidal bottom
flux; head-dependent bottom flux. These add7672 complete model days.
`integration/nomacro-coverage01/BLOCK_C_STATUS.json` owns this evidence and
subsequent actual admission. All14 O0/O2 profiles pass native/auxiliary own
continuations, independent origins, external discard/replay/recovery and the
actual inconsistent-mass refusal. Bounds remain1e-10cm and1e-10mg/cm2.

No Fortran physical/state/host/provider, registered CLI or original archive byte
changes from the qualified PR1670 surface in this block. Its registered-release
qualification is preserved by an explicit empty relevant-source comparison;
unmodified historical periods are not rerun solely for an adapter-only change.

The valid no-heat cultivated case uses the original maize file/simple growth
in the three original date windows. The table-bottom fixture supplies downward
flux knots-0.05/-0.10/-0.075cm/day over2002through2004; the sinusoidal fixture uses
mean-0.05/amplitude0.02cm/day. These are explicit derived inputs, not unchanged
historical configurations.

The original no-heat Hupsel rotation ran523 days before the physical-oxygen
reader refused its future potato crop: SWOXYGEN2 requires SWHEA1/SWCALT2.
That prefix/refusal is retained and is not counted as a successful configuration.
The adapter now checks every referenced future crop before output/build, so the
same incompatibility refuses atomically. An unused crop file remains hash-bound
input data and cannot activate an irrelevant process or invalidate a bare-soil
or different-rotation run.

The undrained/free-bottom configuration is a complete functional result; it
does not replace or relabel the distinct undrained/closed-bottom day51 failure.
Across the first three blocks there are17 additional complete configurations
and20457 executed complete-model days, with zero new independent historical
projects and no whole-science promotion.


## Current coverage register and remaining work

The categories below describe the current integration boundary: **A** means an
executed, source-bound functional configuration; **B** means original Fortran is
present but its broader option/state combinations are not qualified; **C** means
a demonstrated missing or defective integration; **D** means active macropores,
which remain outside this work unit. A supported input selector alone is not A.

| Family | A: executed scope | B/C: remaining original integration or qualification |
| --- | --- | --- |
| Project input/grid/calendar | Three registered projects; general derived original inputs in blocks A/B/C | B: arbitrary grids, references and process combinations need their own evidence |
| Richards/hydraulics | Selected original MvG and unchanged production solver; hysteresis1/2 trajectories and named restarts | B: hydraulic tables and other original constitutive families; C: later active history restart FAIL retained; water-only history explicitly refused |
| Lower boundary | Selected original Cauchy/closed/free; table, sine, head-dependent flux | C: strict solute substep receipt absent for reconstructed modes1/5; B: other original boundaries8/9 |
| Drainage/surface water | Selected original drainage methods2/3; undrained free-bottom trajectory | B: other original drainage/division/surface-water options; retained undrained closed-bottom day51 refusal is not A |
| Crops/roots/ET | Registered grass/rotation/WOFOST; bare/simple maize; Gash/Feddes/microscopic drought2/Walsum2 | B: broader original growth structures, root/stress/interception/ET controls and combinations; block D is pending admission |
| Irrigation | Registered fixed surface and external surface histories, managed rotation | B: original scheduling and subsurface variants beyond the executed families |
| Heat | Selected numerical and analytical temperature; original top1..4 and bottom1/2; compatible no-heat routes | B: unexecuted process combinations; whole physical energy including mass-carried energy remains a separate scientific limitation |
| Snow/frost | Positive snow accumulation/melt, snow plus hysteresis, named exact continuations | B/C: complete frost state and corrected-reference integration; frost remains refused |
| Solute | Original conservative CDE; separate and combined Freundlich sorption/decay | B/C: reservoir SWBR1, original age/tracer SWSOLU2 and their matching conserved ledgers/state |
| Weather/top boundary | Selected original daily weather, atmosphere, interception and surface store | B: detailed weather/rainfall and further original top-boundary options; implicit conductivity SWKIMPL1 remains excluded |
| Runtime control | Registered groundwater and surface forcing; experimental original-forcing accept/discard/recovery | B/C: general runtime dynamic boundary forcing beyond the registered contracts |
| Macropores | None within this work unit | D: all active macropore processes and owner research remain separate |

This register is derived from the explicit adapter restrictions in
`app/hybrid_water/experimental_project.py`, original bundled readers/process
bodies and the source-bound block records. It identifies the next implementation
surfaces, not a claim that unexecuted mixtures work. The available pinned
no-macro historical distribution still provides only three independent projects;
derived SaltFarm levels and switched options do not increase that count.

Block C was admitted by PR1671 at `a6720a0e8`. Its actual tree includes the
separately admitted PR1672 GNU arithmetic profile, which entered canonical
between preflight and merge. Run43412494520 requalified all seven C configurations
on that exact actual merge. The historical premerge result is retained separately
from `BLOCK_C_POSTMERGE_*` and `BLOCK_C_MERGE.json`.


## Chemistry-independent crop and management state

Block D separates original irrigation/WOFOST management from chemical transport.
Previously that carry was generated only for active solute. Explicit experimental
water-only runs now preserve the same original schedule/rate/crop state under a
distinct `S5WAT007` auxiliary format, without inventing a chemical stock or ledger.
Referenced future crop salinity stress requires active solute, and incompatible
requests refuse before output/build. The original SaltFarm text initialization
must consistently declare the derived SWSOLU0 as well as its SWP input.

The six derived configurations are water-only Hupsel1096 and SaltFarm08/1461;
Hupsel with interception off, oxygen stress off or compensation off (1096 each);
and SaltFarm08 with solute active but salinity stress off (1461). Their initial
source1c64ba98d qualification completed7306 model days and all A/B/C/release
predecessors. The final source adds actual generated/touched donor O0/O2 builds
and active-crop windows530to532/200to202 at both optimizations. The immutable
original object provider remains O2; this is not a full-provider O0 claim.
Final source42f066bf0 passes run43418605842 for all six configurations.
A/B/release43418610124 and C43418614412 all pass on the same source. Maximum
water residual is9.996782546727034e-11cm; maximum active-solute residual is
7.64517615881033e-12mg/cm2, under the unchanged1e-10 bounds. Actual admission
belongs to `BLOCK_D_STATUS.json` and the merge receipt.

These windows inspect an actually emerged crop and nonzero saved growth rates,
then compare complete physical rows and native/auxiliary endpoint bytes.
Water-only malformed state tests reseal wrong format, truncation, NaN and
invalid crop flags and run the actual decoder. Independent origins, external
accept/discard/replay/disk recovery and deliberately inconsistent mass rejection
retain their own actual execution checks. Inactive chemical balance is reported
as absent, not a fictitious zero-residual chemical qualification.

A proposed seventh variant, water-only snow plus hysteresis, passed its full
O2 period and named winter restart on source dec0bbfa1, but failed the later
active-growth continuation. Source640565a8d repeated that genuine mismatch with
actual generated O0: first resumed water storage differed2.2815e-9cm and the next
by2.1637e-8cm. Daily conservation passed, which does not establish exact restart.
The original failure and selected raw state are retained in
`BLOCK_D_RETAINED_FAIL_*`. Two narrowly scoped cache hypotheses both failed and
were removed. No tolerance, physical law or general solver change was made.

The revised route explicitly refuses new water-only hysteresis or snow history
before compilation/output. Completing these combinations requires preserving a
larger original state block in a separate bounded successor, rather than another
local cache-repair loop. Earlier solute-history block B evidence remains limited
to its named2/365 restart origins; it is not proof of arbitrary active-crop
history restart. Whole scientific equivalence remains unqualified.


## Original thermal and additional canopy/root options

Block E connects the unchanged original analytical temperature routine and all
four original thermal top boundaries (air, prescribed temperature, prescribed
heat flux and the original mixed temperature/flux condition), plus prescribed
bottom temperature. The future-crop check still requires numerical heat for
physical oxygen2; analytical heat cannot bypass that original constraint.
Original drought2 and compensation2 become independently selectable. No
Fortran physical equation, time-step policy or existing state codec changes.

The nine derived Hupsel fixtures exercise analytical heat with oxygen off;
prescribed bottom temperature; top temperature, top flux and mixed top;
Gash interception; Feddes oxygen; potential-based drought; Walsum compensation.
Thermal tables span the complete2002..2004 period and remain bound input files.
Qualification requires complete1096-day periods, actual touched donor/controller
O0/O2, exact native2/365 and active530 continuations, finite native temperature
state, original-reference diagnostics, hard water/solute bounds, independent
origins and external discard/replay/recovery. Actual qualification/admission
belongs to `integration/nomacro-coverage01/BLOCK_E_STATUS.json` when present.

The first thermal cohort completed five full trajectories with exact native
continuations, but the proposed Gash fixture later reached original WOFOST
potato. The original reader correctly forbids Gash outside simple crop type1.
That prefix and original refusal remain in `BLOCK_E_FIRST_RUN_*`. The valid
fixture uses the original simple maize file/type1 in all original date windows.
The preflight now checks every referenced occurrence of a crop file and rejects
Gash/type2 or type3 before build/output; unused files cannot activate a process.
Simple-crop activation is checked by positive actual root uptake, while WOFOST
cases retain the nonzero saved-growth-rate check. Neither inactive WOFOST rates
nor finite temperatures establish a complete physical energy balance. Original
oxygen/scientific FAILs and the mass-carried heat limitation remain visible.


The second cohort completed seven full trajectories, then the original
microscopic drought2 input refused extra compensation1 on day140. This original
physical compatibility rule now also applies to every referenced future crop
before output/build. The drought2 fixture explicitly selects compensation0;
Walsum compensation2 explicitly selects Feddes drought1 throughout its rotation.
Both original input refusals are retained as failures, not counted as complete
configurations. No numerical repair or threshold change is involved.


The microscopic-option input also exposes inactive original ROOTXYLEM0.02,
which exceeds the supplied root radii and is correctly refused by the original
reader. Its explicitly derived fixture uses the reader's own example,
ROOTXYLEM=0.4*ROOTRADIUS, for each referenced crop. Original source and numeric
validation remain unchanged; this is a different physical input, not an
unchanged historical-project claim.


Final block E source `b7a9d8405c3ec3f79d199b9c5a8273cebd4d9bdc` passes
run43423367602: all nine full1096-day trajectories,9864 complete model days,
and all18 actual touched-unit/controller O0/O2 profiles pass exact native
2/365/530 continuations, independent origins and external transactional controls.
The immutable original provider remains O2. Maximum water residual is
9.997787873191472e-11cm and maximum solute residual2.0189361551216096e-13mg/cm2,
below the unchanged1e-10 bounds. All five thermal choices produce distinct
active native temperature profiles; this proves activation and exact supported
state, not a full physical energy balance. Three incompatible future-input
requests refuse before output/build. `BLOCK_E_STATUS.json`, source-bound reports
and raw archives own the qualification; the merge receipt owns admission.

Registered release runtime, host, kernel, original provider and existing state
codec sources are unchanged from D. All24 prior selected experimental project
descriptors (23 complete configurations and one preserved refusal) remain exact
under current validation. This inherits previous evidence only within its
unchanged selected-process/runtime surface. Adapter fingerprints changed, so old
experimental build bundles cannot be silently rebound and require a fresh build.
Across A/B/C/D/E there are32 additional complete configurations and37627 complete
model days, with zero new independent historical projects. Complete original
no-macro functional coverage has not yet been established; the remaining register
and retained history/scientific gaps are still open.

## Experimental general external surface events: qualification pending

Block F extends the existing typed surface-event transaction to validated original
experimental projects. Every referenced future crop must retain SCHEDULE0 and
the original SWIRFIX1 fixed-event route. Chemical1 retains S5IRR001; water-only
uses distinct S5IRR002 and requires exactly zero chemical concentration. Original
schedules are never implicitly disabled. Build/source/origin/clock identity,
discard/replay, isolation and durable forcing lineage retain their existing owner.
The incremental builder copies and verifies the restart publisher and preserves
executable permissions; it reuses the original kernel and untouched objects.

The first full source6c79235cf run43583516947 passes the complete water-only1096
forced days with exact daily warm/cold physical and native states, and both
generic O0 active532-day windows. Salt O2 accepts572 exact days, then the warm
original CDE trial on573 violates the unchanged1e-10 chemical guard by
0.00020858649141789897mg/cm2. Original intermediate negative-inventory clipping
accounts for the mass creation. No accepted573 checkpoint is published. This
full run is a retained FAIL, not full block qualification.

Two scalar stability hypotheses fail to change that result. A revised strategy
retains the complete original chemical substep as a transaction: snapshot every
mutable stock and cumulative flux; refuse a negative intermediate inventory
before clipping; roll back the whole trial and retry a smaller chemical interval.
Only acceptance advances the chemical clock. The explicit experimental option
`--experimental-solute-step-policy transactional-cde-substeps-v1` selects this
execution policy for SWSOLU1; it is not an automatic failure fallback. Physical
flux/reaction laws and all acceptance tolerances remain unchanged. Trial buffers
are transient; the accepted physical restart schema is unchanged.

Private exact573 run43586778043 reproduces the old failure and supports the new
strategy with independent residual-3.5551331843686196e-12mg/cm2 and one whole-trial
retry. It publishes no accepted checkpoint and establishes only that interval.
The public full forced trajectory still requires fresh qualification. Registered
and default generated source must remain byte-identical against the eight actual
preimages from43583358529; only the explicitly selected generic chemical source
may differ. The selected policy/generator is build and checkpoint-bound; old
bundles cannot be rebound. `BLOCK_F_STATUS.json` and the versioned raw evidence
own execution status. No F canonical admission or whole-science PASS is claimed.
