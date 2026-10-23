# Native historical project execution

Proposed bounded successor to the admitted trial-beginning root application.
Baseline80dbce8d325e9197a53b7189ad184bcdf91f6f5c. Owner:existing MC-SOL01
root_joint_successor/substep_feedback_work/native_project_successor.

One SWP selects original PATHATM/PATHCROP, METFIL and up to64 ordered simple-crop
periods. Original TTUTIL parses source fields and year-file naming follows original
MOD_meteo:MOD(year,1000),three digits. A native adapter normalizes the immutable
daily weather and projects one SWP preparation view per crop. Existing original
crop and root readers consume those views and unchanged CRP snapshots. The
physical water/chemistry bootstrap always reads the complete original SWP snapshot.
Every original input byte, including future periods and years, binds restart.

The explicit project front end selects existing Reference SWKIMPL0 substep roots
by default. Each period has its own density/Feddes parameters; daily geometry and
demand are prepared with the existing production processes. Phenology is reset at
each actual emergence and stays inactive during fallow/after harvest. There is no
new equation implementation, biological water feedback or restart owner. The
previous column and single-crop applications remain unchanged. The new front end
shares the same physical providers and persistence; orchestration duplication is
explicit, not an independent hydraulic/chemical kernel.

Initial native scope:SWCROP1,CROPTYPE1,IDEV1/2,SWETR1,SWRAIN0,SWCF1,SWRD1,
macro drought/optional empirical oxygen, layered MvG/unsaturated HTB, constant
prescribed SWBOTB2 bottom flux and constant PONDMX/RSRO with RSROEXP1. Unsupported
active options reject before physical output. No silent default to a zero bottom
flux or disabled drainage, irrigation, heat, snow, macropores or nutrients.
SWBOTB1 is deliberately excluded. PM/SWETR0 and arbitrary historical projects are
not admitted by this boundary. A run using historical Andelst weather but a
constructed supported soil/crop fixture is labelled as such, not the original
Andelst project or a full historical accuracy qualification.

Invariants2,3,7,9,13,21,23,29. Start with the two-provider native metadata/calendar
adapter and negative inputs; reuse identical current193 physical provider objects
inside controlled checked O0/O2 builds, link/execute the new real application.
Then complete historical-weather years with differing crop periods, wet/dry
spells, source-bound restart and hard water/solute budgets. Compare preparation
against the original fixed-crop oracle and separate transport against retained
source-exact authorities. Complete model equivalence is only claimed if an actual
complete original reference execution supports it. Expected local build/native
qualification600s; source, forcing, closure, cost and failures must be retained.
No shared production SRC change is planned. Existing component proof is inherited
only with exact executed inputs; full F-CI NOT_SELECTED_IMPACT and highest low-air
NOT_SELECTED_POLICY. Canonical admission remains a separate recorded gate.

## Discovered explicit-transport numerical acceptance gap

The unchanged1998 weather run reaches day229 with228 accepted hard-balance days.
Water succeeds, but original explicit chemical transport reports
B111_REACTIVE_NEGATIVE at accepted water trace step2222. This is not an input,
water-balance or Freundlich failure. A water-acceptable step does not establish
positivity of an explicit chemical update. The failed year and unchanged committed
day228 binary are retained. No concentration clamp, relaxed balance or forcing
change is permitted.

A separately persisted numerical retry experiment halves rejected joint windows
down to2^-30 day. It does not resolve the coarse-grid failure; both reporting-day
owners are restored byte exactly. That unsuccessful policy is not admitted and
is removed from the production candidate. Smaller water timesteps are not evidence
of positivity for centered explicit spatial transport. Its face flux has centered
advection and physical plus temporal dispersion. Its off-diagonal spatial weights
can be negative. The constructed fixture has LDIS=.01,.02cm, not1/2cm.
The original read_solute_CDE reads these values without conversion and the native
adapter passes them unchanged into dispersivity_cm. The earlier1/2cm explanation
was a unit interpretation error, not a conversion performed by either reader.

The qualification therefore retains the coarse failure and executes an explicit
refined-grid comparison:the same120cm profile, layer parameters, original weather,
crop inputs and tolerances, with2cm upper cells and<=3.9cm lower cells including
a2cm interface cell. Both O0 and O2 reject day141 after140 accepted days, with
chemical status3/process3 and1026 completed trace substeps. The refinement does
not resolve positivity and is NOT_QUALIFIED. This is a labelled failed spatial
discretization experiment, not a silent correction of user input. The ordinary
runner always honors the supplied grid and fails rather than clamps a negative
chemical state. No dispersivity, diffusion, forcing or tolerance is changed to
obtain a passing year. Broad coarse-grid
positivity or a replacement monotone transport scheme needs separate numerical/
reference qualification. There is no successful annual transport/restart claim.

Preparation can be checked independently:compare all daily fields from each
period's projected SWP/unchanged CRP and normalized original weather against the
complete original fixed.f90 and ETpot. A passing preparation comparison does not
qualify annual physical execution, hydraulic accuracy or the complete original
Andelst project. Retain failed annual inputs and diagnostics alongside this
bounded evidence. The successor remains proposed and is not canonically admitted.

## Proposed positive transport numerical policy

Continuation baseline:e387b89d382afaee325f3cf2c2760f0713f258e4 (PR1373 draft).
Original SWAP/solute.f90:436-438 zeroes negative cmsy and adds its signed amount
to rounderr. This is historical numerical error accounting, not conservation of
nonnegative physical storage. Source-exact centered Reference remains available.

Implement an explicit opt-in implicit upwind policy in the same reactive process.
Use donor concentration for advection and the original physical diffusion and
dispersivity for centered diffusion. Backward Euler evaluates transport, root/
drain outflow and decay on the new concentration/storage. There is no temporal
Taylor dispersion term in this implicit discretization. Existing pond exchange,
Freundlich storage and decay-rate providers remain the physical authorities.
The nonlinear finite-volume equations have nonpositive neighbour coefficients,
positive storage and nonnegative sources. Solve them by bounded positive scalar
Gauss-Seidel using the existing monotone Freundlich inversion. Require a local
equation residual and the existing hard global balance before returning success.
Failure returns the original candidate owners. No negative concentration reset
or numerical mass source is introduced.

Owned shared interfaces:one numerical selector in reactive forcing, validated
default0 Reference and opt-in1 implicit_upwind; the matrix immutable parameter
fingerprint includes a tagged selector only for opt-in1 so existing Reference
restart vectors remain unchanged. The native project CLI records the explicit
choice in its bound input. Reference physical arithmetic and default remain.
Invariants2,3,5,7,9,13,21,23,25,26,29,30 are affected and must remain satisfied.
Cross-workstream effects include all callers of the reactive forcing type and
matrix restart fingerprint. Current shared builds must be rebuilt; raw old proof
is historical until changed-default preservation has actually run. No admission
owner or historical assertion is waived by adding this policy.

Qualification selection:small real process O0/O2 positivity/conservation across
flow directions, Freundlich0.5..2, temperature/root/drain/pond sources, large dt,
invalid selector and unchanged Reference outcomes; independent two-cell linear
implicit solution and spatial/time convergence against analytic advection/decay.
Then current project builds and exact short default/rejection preservation,
mode-bound restart, actual original coarse/refined annual and cross-year runs,
unchanged weather/soil/crop/chemistry/tolerances. Compare water and crop fields
exactly across policies where Reference has an accepted prefix; solute accuracy
is measured separately. Expected focused feedback60s; checked builds120s; annual
composition up to3600s (selected to test the actual blocked physical route).
Any admission additionally requires current owning preservation and F-CI impact
reconciliation. Highest low-air remains NOT_SELECTED_POLICY; RossFast is unused.

The first implicit attempt resolves the retained day229 but the original short
fixture exposes accumulated inversion roundoff:after668 accepted chemical steps
the day residual4.69e-12 exceeds its existing mass-scaled certificate. Retain this
failed attempt. Total finite-volume amount must be primary. After the implicit
concentrations converge, compute each face once, update conservative cell amounts
and use the physical Freundlich inverse for their equilibrium split. Normalize
its positive dissolved/sorbed fractions onto that exact amount, recompute C from
dissolved amount and theta, and require the existing2048eps equilibrium identity.
This removes repeated inversion-roundoff mass creation without changing the
physical balance or its tolerance. A negative conservative amount still rejects.

The conservative transport candidate passes1024 daily balances across the two
grids and O0/O2 before all four years reject water day257. The source is the
existing SWKIMPL0 hydraulic route, before chemical replay. At a partially
saturated interior interface, the last full/half candidates differ in pressure
while pond and groundwater level are identical. Retaining step proposals is
ineffective after the existing sticky solver-rejection fallback;16 Newton
iterations still rejects. No completed historical year is claimed.

Select one short research probe before any new annual execution:using the exact
day256 state and original forcing, iterate physical conductivity inside the
existing typed SWKIMPL0 solve (modified Picard) with64 iterations. Reuse the exact
physical constitutive/root/top providers, full/half tolerance and hard mass
certificate. The generated diagnostic HeadCalc replaces only its original object
in the checked build; it is not production or admission. This distinguishes the
frozen-conductivity algebraic saturation issue from a chemical defect. Expected
30s compile and180s bounded native execution. A positive result requires a new
explicit numerical policy, owning source/preservation gates and renewed annual
composition before production use. Source-exact Reference remains available.
# Explicit conductivity iteration successor (2026-10-22)

Final current O0/O2 default preservation passes:128 root daily balances,16 fresh
restarts,64 exact predecessor artifacts, default and Picard rejection/retry/A/B/A,
seven Picard compatibility rejects per optimization, native cross-policy rejection,
and cold/calendar/thermal/crash/harvest/saved-harvest NUT composition. Native/default
NUT endpoints match the pre-Picard incumbent exactly. These are preservation and
focused research results; they do not promote the failed annual scope.

Authenticated `SWAP/solute.f90`:346-355 explicitly sets `cfluxt=0` when
`qtop>=-1e-6`. A test-only pond carrier permitting upward water, with the existing
unchanged zero-solute surface operator, passes actual day267 in O0/O2. Therefore
a soil-concentration donor return is new physics, not an exact reconstruction of
this historical source. This checkpoint leaves the production carrier guard
unchanged. A separately named historical-zero boundary can be qualified as a
bounded source-exact extension; physical donor-return transport needs its own
scientific/reference contract. Evaporation must never export dissolved solute.

The implemented policy is still experimental. Both O0/O2 annual experiments
terminate: coarse accepts266 days then the existing pond carrier rejects actual
soil-to-pond exfiltration on day267; refined accepts64 days then the water
transaction fails near internal saturation on day65. Both grids' O0/O2 budget
prefixes and rejected committed snapshots are byte-identical. Annual physical
restart and cross-year remain unexecuted dependencies. Passing actual day257
does not establish mesh robustness or annual qualification.

The day267 diagnostic identifies the existing `qtop > soil_evaporation_rate`
carrier guard: qtop=.039407159969323521cm/day, soil evaporation0, pond
evaporation=.10234288861161206cm/day, dt=.25day, pond .015733932160572135cm
to0. The water balance closes exactly. This is the unimplemented exfiltration
chemical ownership boundary, not evidence of negative implicit transport.
The refined day65 replay also fails at the largest admitted temporal tolerance
1e-3;1e-2 and1e-1 reject the existing input domain before any water trial.
No tolerance or carrier guard has been relaxed. Further saturation/error-control
research and source-backed exfiltration coupling precede a new annual attempt.

Canonical moved from80dbce8d to7eb6f10b while the experiments ran. The independent
NUT harvest/saved-output adapters have been merged into this working branch;
their fresh default preservation is selected alongside cold/thermal/calendar
controls. No root/SOL predecessor status or scientific source is overwritten.

The actual day-257 O2 research replay completed with modified Picard conductivity
and 64 iterations, without changing the physical providers, beginning-of-trial
root sink, temporal tolerance (1e-4), local tolerances (1e-12), or daily mass
limit (1e-10). This is a focused result, not annual qualification.

Implementation contract: `picard_conductivity_iteration` is an explicit numerical
switch, default false, carried by the existing typed solver numerical request.
It refreshes candidate conductivity and face means from the constitutive provider
while retaining the SwKimpl=0 Picard matrix. It does not enter legacy SwKimpl=1.
The initial FMR scope is Reference/default MvG, mean method 1, constant-flux bottom
mode 2, 64 iterations, external full/half control, no temporal history, and no
extended hydraulics, thermal, snow, macropore, drainage-response or additional
root physiology. The historical project exposes this as `--water-conductivity
picard`; frozen conductivity remains the default. Input binding must distinguish
the modes across public restart. New shared numerical fields require fresh
default-preservation and dependent NUT builds. Architecture invariants 2, 3, 5,
7, 9, 13, 21, 23, 25, 26, 29 and 30 remain applicable. No canonical admission or
full historical migration claim follows from this implementation contract.

## Explicit historical upward-water surface boundary

Continuation at canonical17a6c17a plus the existing positive-transport research.
The actual day65 still rejects after the admitted saturation repair: accepted
progress64.967257647735735, no mass rejection. The separate actual day267 water
solve succeeds, but the pond carrier rejects upward water before chemical commit.

Add a default-false `historical_zero_solute_exfiltration` supply selector. With
explicit selection, allow bounded upward water through the existing hard pond
water certificate and unchanged historical chemical surface operator. Original
`SWAP/solute.f90`:346-355 supplies the zero chemical flux for qtop>=-1e-6.
This boundary retains all chemical mass in soil/pond except existing declared
sources, runoff, uptake and decay. It does not return soil donor concentration
to the pond and does not qualify that alternative physical assumption. Water
exfiltration and zero chemical exfiltration must be reported separately.

Expose only through the proposed native-project option
`--surface-exfiltration historical_zero`. The default remains `reject`; old
applications remain on their default. The complete input document and audit
bind the option into public restart identity. Do not convert public restarts
across the modes. A test-only physical checkpoint replay may change this
selector, labelled explicitly as a diagnostic, never as public continuation.

Select small real pond O0/O2 tests with the authenticated source oracle,
water/mass/rejection/continuation checks, actual day267 production-carrier replay,
short native public restart and cross-mode rejection. Rebuild current shared
providers after the appended derived-type member. Estimate two builds500s and
focused execution60s. Native annual scope remains unqualified while day65 fails;
do not spend another full year merely to re-demonstrate that known blocker.
No tolerance, concentration, physical forcing, mass or rollback gate changes.
Invariants2,3,7,9,13,21,23,25,29 remain applicable. Canonical admission and full
default preservation are separate from these focused development results.


### Preregistered day65 temporal-metric diagnostic

After completing the surface boundary, test exactly the retained day64 state
with a copied test-only backend and unchanged1e-4 budget, Picard solve, inputs,
root sink and hard mass gates. Substitute the existing admitted weather metric:
unsaturated pressure difference, integrated absolute storage difference and
integrated Darcy-face differences; omit the free-drain bottom conductivity term
for the prescribed constant-flux bottom2, whose sibling flux error is zero.
This distinguishes saturation pressure sensitivity from a remaining water-solve
failure. It is an explicit research change of the error estimator, not relaxed
tolerances or production admission. Execute O0 first, then O2 if useful. Expected
local compile plus native120s per setting. Retain both success and rejection,
exact generated backend and original input identities. A success selects a
separate policy/accuracy/preservation study before any production or annual claim.

### Local continuation outcome, 22 October 2026

The explicit historical boundary passes the actual day267 physical-state replay
in current checked O0/O2 builds. All four budget/state/endpoint/restart artifacts
are exact across optimizations. Reported upward surface water is separate from
zero historical chemical return. This diagnostic selects the boundary on a
validated physical checkpoint; it is not a public cross-policy restart claim.
Default mode still rejects this actual upward-water day without changing either
committed owner. The original short project retains all eight O0/O2 incumbent
physical artifacts,144 exact original preparation values and14 invalid-input
rejections. Full default root preservation gives64 exact files,128 daily
balances,16 exact fresh restarts and real reject/retry/A/B/A controls.
The opted-in short project gives12 exact fresh-restart files,eight rejected
transport-policy switches and two rejected public surface-mode switches.
The real two-provider pond executable additionally checks240 upward-water
cases against the authenticated original source, alongside its incumbent240
mixing cases,hard budgets,nonmutation,restore,remobilization and runoff.

The instrumented O2 saturation-metric probe demonstrably calls the substituted
metric, but day65 still rejects at64.967257647735735 with the same1674 accepted
steps and18877 attempts. No mass rejection occurs and both committed owners
remain exact. This rules out that estimator substitution as a sufficient repair
for this replay. It does not establish which remaining solver/constitutive
detail causes stagnation. The general annual/cross-year route remains blocked.
Wider NUT/source-owner admission reconciliation remains pending. Work is locally
committed only: automatic approval review rejected remote publication, and no
alternate publication route was attempted. No canonical admission is claimed.

### Day65 conductivity study, 23 October 2026

Published baseline801e78ee has the exact previously tested tree10ee4f77.
Canonicala1f9fb2b adds a separate default-OFF failed-line-search weather policy.
Its bottom7/consistent-provider scope does not activate it for this bottom2
Picard project. The source delta is composed before any current shared build.

The layer2 native parameters alpha=.02,n=1.6 imply that the inherited early-Ksat
shortcut at relative saturation1-1e-6 starts at h=-.016413490934930813cm.
The retained day65 accepted heads approach this same value. The underlying
Mualem value there is about.983819Ksat; the shortcut jumps toKsat. This is a
specific constitutive discontinuity hypothesis, not yet a demonstrated repair.

First execute the real two-provider curve for both layers at checked O0/O2,
including cutoff-side values, unchanged retention and existing continuous-curve
selection. Then rebuild current shared providers,expected500s,and replay the
actual day64 committed state with unchanged weather/crop/bottom/chemistry and
1e-4 temporal budget. A copied diagnostic backend selects the existing continuous
curve only for the explicit Picard test. The existing native surface option is
selected to avoid confusing a later already-understood chemical exfiltration
rejection with the water result. Expected native120s/optimization. Separately
test the old head norm and the already-investigated saturation-aware norm if
needed. No production/default constitutive law, acceptance tolerance, mass gate
or public restart conversion is changed by this diagnostic. A success requires
an explicit policy contract and current preservation before admission.

The real leaf confirms conductivity jumps from9.62116757to10 and
1.96763756to2cm/day at the respective native cutoffs. The actual day65 cutoff
replay still rejects with exact committed owners; continuous-curve O0/O2 replays
complete with the unchanged original head norm. A separate continuous-curve plus
saturation-aware norm O2 replay also completes; that metric is not selected for
production by this result. The matched-intervention evidence identifies the
inherited conductivity shortcut as the cause of this retained blockage.

Proposed explicit option: `--water-conductivity picard_continuous`. It selects
the existing prepared-default-MvG continuous curve and existing64-iteration
Picard route. Reuse the typed prepared hydraulic flag; add no generic solver
field or independent equation. The backend honors a compatible prepared curve
only with the bounded Picard compatibility contract. Neither the frozen default
nor existing `picard` behavior changes. Prepared coefficients remain immutable;
worker-owned copies remain separate when needed. Retention and physical forcing
are unchanged. The old temporal norm and all hard acceptance gates remain.
Native continuous-project parameter identity670002 distinguishes its raw restart
from the retained670001 route; public source/executable/input binding also
rejects cross-mode continuation. Actual historical checkpoint experiments are
explicit physical-state counterfactuals, never public restart conversions.
Select fresh current O0/O2 builds and day65/day267 production replays, default
root/crop/solute preservation, opted-in short/native restart and raw/public mode
rejections, and affected current NUT preservation. Then select actual annual
coarse/refined continuation and cross-year work with unchanged physical inputs.
No whole MC-SOL01 or full capability admission follows from a focused day replay.

The existing continuous-provider flag also selects stable near-zero storage
increments. To isolate the conductivity inference, additionally replay with a
copied test-only provider selecting the continuous K function while leaving its
parameter flag false. This retains the old storage-increment branch and old
temporal norm. The actual driver must demonstrate a sub-Ksat value in the band
and explicitly assert the unchanged storage-policy flag. This is a causal
discriminator only, not an additional production selector; expected120s/O2.

### Composite saturation successor

The curve-only production candidate completes the actual day65 replays but its
coarse whole-year run rejects water day257 after256 accepted days. Replay of
that exact new day256 state rejects at256.57903459002995 with3555 solver and
15258 temporal rejections,zero mass rejections. Selecting the existing
saturation-aware storage/Darcy norm on the same continuous curve completes that
day. Both interventions are therefore needed for the broader candidate.

For the proposed `picard_continuous` option only, use the existing weather norm
for this compatible prepared continuous curve. Omit its free-drainage bottom
conductivity displacement for bottom2, whose prescribed bottom flux has zero
sibling difference. Unsaturated head, integrated absolute storage, pond/GWL and
integrated interior/wet-top Darcy differences remain controlled. Positive head
is algebraic; no uniform saturated-pressure accuracy claim is made. Existing
frozen/Picard modes keep their original norm, and weather bottom7 keeps its
existing free-drainage term. The1e-4 budget and all local/global mass gates stay
unchanged. Earlier curve-only results and failed year remain immutable evidence.

Stop the obsolete refined curve-only year after its current accepted prefix:
it is a censored superseded candidate,not a newly established physical failure.
Select a complete coarse O2 year/cross-year and a focused98-day refined prefix
past day65, with exact fresh-process restart. Full refined annual qualification
is not inferred. This avoids repeating the known failed candidate or using a
whole second fine-grid year where the shorter saturation fixture distinguishes
the changed numerical policy. Retain source identities,actual costs and all
failure/censoring information. Recompile only changed providers when the
compiled module interfaces and unchanged object identities are exact; execute
the current scientific programs afresh. No old numerical PASS is rebound.

The bounded98-day native observations contain no runoff; the complete coarse
year does (36.57245247925319cm). The initial prefix recipe incorrectly retained
the full-year positive-runoff coverage assertion. Correct only that test-scope
condition: retain the positive-runoff requirement for every full period, not a
truncated prefix. All hard mass, source/original fixed/ETpot and exact
full/split/resume assertions remain. The numerical programs are unchanged.
Retain the original recipe, raw events and wrapper failure, then validate its
completed native observations with `validate_native_project_prefix.py`.
The composed evidence gate accepts exactly this one reviewed validation-only
source delta, not arbitrary changed execution inputs. It explicitly records
that the unchanged physical programs were not rerun for the coverage correction.

### Current bounded composite result, 23 October 2026

The real prepared-interface day65 replay passes checked O0/O2 with four exact
physical/budget/restart artifacts; the exact day256 state also completes day257
using current production providers, without a copied constitutive or temporal
backend. The fresh public native mode is tested separately from these labelled
historical-state counterfactuals. Current rollback/compatibility,12 native exact
restart files,8 transport-mode,6 curve-mode and2 surface-mode rejections pass.
The incumbent daily route retains64 exact files,128 hard daily balances and16
fresh restarts; cold, thermal, calendar, harvested-phase and saved-harvest/fallow
NUT programs all execute on the current shared postimage and pass. Cold endpoints
and retained thermal/calendar/saved result identities remain exact.

Actual O2 native composition now completes the365-day1998 and481-day1998/1999
coarse calculations, including exact full/split/resumed state, endpoint and raw
restart, daily gross water/solute balances and literal original fixed/ETpot
preparation. The41-cell refined prefix completes98 days with the same independent
restart and hard balances. Its original annual-event assertion failure and the
subsequent scope-correct validation remain separate retained observations.
Maximum reported water/solute residuals are2.2648549702353193e-14cm and
1.3288675715372733e-13mg/cm2 over the coarse481-day calculation; the refined
prefix maxima are2.606248550307555e-14cm and7.92681892347602e-14mg/cm2.

Over the matched first98 days, maximum coarse/refined daily water-storage spread
is.0015127562025867292cm; solute-stock spread is.3935686314517852mg/cm2.
This is a measured two-grid spread, not demonstrated convergence, a spatially
resolved annual solute solution, or equivalence to the full historical Andelst
model. The original low dispersivities, prescribed crop demand and all physical
inputs remain explicit. Full refined annual execution, broader physics/default
dispatch, full MC-SOL01 and canonical admission are not claimed.

Owning recovery is the existing `day65_continuation_20261023` child in
`MC_SOL01_DYNAMIC_DECAY_STATUS.json`. The new source/raw research gate is
`integration/audits/verify_sol_day65_continuation.py`; its capsule retains source
versions, actual costs, failed curve-only year, censored obsolete refined year,
compiler/cache provenance and every current raw scientific observation.

### Canonical composition selection

Published27b630f9 has exact complete tree828bd4c8. Reconcile against canonical
53010691 without changing the tested production postimage. Complete the missing
current incumbent water/chemistry/crop and weather preservation programs and
the independent original FSI35 body; expected1200s. Reuse the exact current
year/root/NUT evidence only after source and raw validation. The existing
source owners retain their original assertion bodies and receive only an exact
registered successor dispatch. Current-source, physical, frozen predecessor,
FSI35 and actual-merge admission are distinct gates. Invariants3,5,7,13,21,23,25,
26,29,30 remain binding. Full MC-SOL01 and broader historical default dispatch
remain outside this bounded admission.

### Current complete qualification, 23 October 2026

The bounded candidate composes canonical `d3986e26`, including the newer NUT
thermal saved-generation and repeated-harvest owners. Fresh current O0/O2
incumbent, chemistry, water, daily, ETref, crop/root, transaction and trace
programs pass (578 native events). Twelve 97-day weather cases, day35 process
reconstruction, complete off/on rollback and the original immutable FSI35
O0/O2 body pass. There are 1,320 exact incumbent physical files and twelve
daily CSV comparisons with every physical field exact; only measured
`core_cpu_s` is excluded from equality.

The current 331-provider cold closure was rebuilt O0/O2. Current heat, saved
output and accepted-heat fallow drivers pass, preserving 1,164 canonical
physical files. The subsequent cold/heat two-crop driver passes all64
roundtrips,64 fresh progressions and8 crash recoveries. Its only runner change
allows the existing thermal-saved directory name; all scientific assertions
remain unchanged. The seven preserved NUT families are cold, thermal,
calendar, harvest, saved, thermal fallow and repeated harvest. The unchanged
year/root/transport evidence retains its actual executed source; the earlier
saved codec preimage is explicitly historical and is superseded by the fresh
current saved/fallow composition. No old execution is relabelled as current.

The sealed current preservation capsule and original native FSI35 receipt are
under `integration/audits/evidence/MC_SOL01_NATIVE_ADMISSION_20261023.tar.xz.b64`
and `MC_SOL01_NATIVE_FSI35_20261023.tar.xz`. The owning current gate is
`integration/audits/native_project_admission.py`; the earlier day65 gate remains
an immutable research-snapshot validator. Source registration and corruption
controls are separate from actual canonical admission. Full MC-SOL01, full
refined-year/spatial convergence, broader historical heat/snow/default
activation and full MC-NUT01 remain open.

Actual bounded canonical admission: PR1382, merge
`76d2ab9db8c20e976a25bb4c7414f176dd02c5cb`, exact qualified complete tree
`2cef7484b17a836af15fad7767ea1c6b4892b148`. The actual merge owner and all60
source/raw corruption controls pass. The durable receipt is
`integration/mc-sol01/MC_SOL01_NATIVE_PROJECT_ADMISSION_20261023.json`.
The numerical proof's own `canonically_admitted=false` remains an immutable
qualification-time assertion; this separate actual-merge receipt establishes
the later bounded admission. Full migration flags remain false.

## HIST-INTEGRATION01 seasonal prescribed bottom successor

Baseline 6a21c4251d48959bde4a99ef5127d4039d5ab952. Proposed, not admitted.
Native SWBOTB2/SW2=1 nonzero SINAMP now binds the existing
PPA-LOW02-TIME Reference application control, with original t1900 origin
and exact January-first calendar knots including the final year sentinel.
The backend evaluates flux at every trial-start, including rejected/full/half
trials. No daily-mean sinus approximation or new physics/state owner.
Zero amplitude preserves the previous generated input and physical path.
The new optional budget bottom_up_cm sums the actual accepted bottom flux.
All original SWP bytes and generated calendar bind public restart as before.
SW2=2, other bottom modes and SWBOTB1 remain rejected here.

Changed owned surface: native project reader, launcher, application only.
No shared interface/source, reference bytes, crop, SOL or NUT owners change.
Invariants 2,3,7,9,13,21,23,29 remain. This extends the bounded native
fixture; it is not full Andelst or general historical project equivalence.
Select checked O0/O2 builds with hash-verified unchanged193 physical
providers, independent existing LOW02 oracle, zero-amplitude physical
preservation, actual seasonal joint budgets/restart across January1 and
positive/negative bottom flow. Expected build60s, short feedback60s,
481-day composition up to1800s. Existing annual evidence remains historical
until actual application preservation; full F-CI NOT_SELECTED_IMPACT,
highest low-air NOT_SELECTED_POLICY, RossFast unused.

### Executed HIST-INTEGRATION01 evidence

Both checked O0/O2 native seasonal runs complete481days using original
1998/1999 weather and the retained constructed12-cell soil/three-crop fixture,
SINAVE=-.01,SINAMP=.005,SINMAX=150, tolerance1e-3, implicit_upwind,
picard_continuous and historical_zero exfiltration. Complete endpoints,
budgets and public restart after day365 are byte-exact across optimizations.
The independent gross balance includes the actual accepted bottom amount;
maximum absolute residual6.24e-14cm. Default eight-day physical files retain
exact incumbent identity. Short seasonal flow crosses zero in both directions.
Existing LOW02 independent O0/O2 sine/calendar/dry-guard/A-B-A controls pass.

The full original retained Andelst input is available in the existing
MIGMAC10 gzip files, including swap.swp,swap.bbc,swap.dra,wintcer1/2,
weather and rain files. The exact reconstructed B1.12 manifest is
5bab54598c3519c1b1f2f313431ba0947f39c9673eb1fbc7eec719477f9f2d0e.
The full original O2 model returns100 with swap.ok and empty swap.err after
283.27s;481daily outputs plus the initial state reproduce all existing B1.11
DATE/RAIN/DRN/GWL fields exactly. These original outputs have no BALDEV or
solute/N fields, so this is no newly certified original hard-mass comparison.
A reporting-only absent-BALDEV error was repaired by validating retained raw
files; no historical native rerun or input modification was needed.

The original native SWAP5 attempt rejects SWRAIN3 before publication. Its
other required compositions are SWCFBS1,SWREDU2,SWMACRO1,SWDRA1,
external Cauchy SWBOTB3 and SWHEA1/SWCALT2; these remain open in this
project front end. Original SWSOLU0 does not certify solute or nutrients.
Kalmthout model archive/NetCDF files were not located by exact-title
Library searches; this is an access/search result, not proof of absence.

Paired normal97-day fixture timings compare1e-4 and1e-3 in alternating
order, two executions each. They measure the Python launcher plus native
child CPU, not isolated solver CPU or general production performance.
Fourfold historical rain fails water at day6(1e-4) or day8(1e-3), before
chemical replay. The old constant-bottom control also rejects day8.
For both seasonal and constant1e-3 cases, the rejected committed binary
equals a separate accepted-day7 endpoint exactly. This is retained failure
evidence, not a qualification of this wet profile. No mass/clamp/tolerance
change or new solver policy was introduced. The earlier repaired PERF01
wet case remains a different, independently bounded application.

Canonical admission must bind the exact seasonal postimage and the unchanged
shared src tree. The existing SOL status child historical_integration01_20261023
and verify_native_seasonal_bottom.py retain the full163-control incumbent
receipt plus new native/raw corruption controls. No whole master row promotion.
### Selected refined-year continuation, 23 October 2026

Baseline `c2363394a77d9e0f289c7db2f4fcd6f57ff47bc0`; PR1382 native
production providers remain unchanged. The composed current source/raw owner
and all130 current controls pass. Workspace maintenance removed the old native
executables/compiler. The user authorized a work-directory-only GNU Fortran13
installation; no system package installation is used. Ubuntu13.3.0 package
identity and a checked OpenMP compile/link/native smoke are recorded locally.

Select fresh checked native project O0/O2 builds. Execute the existing short
native preparation/restart/rejection body on O0. Select the existing O2
41-cell1998 annual body with implicit_upwind, picard_continuous and
historical_zero. Retain original1e-4 temporal tolerance, original low
dispersivities, strict daily gross water/solute balances, full versus day180
split/fresh-process resume bytes and complete literal original fixed/ETpot
preparation. The existing per-process1800s timeout remains binding; a failure
or timeout is not a PASS and no physical tolerance is to be weakened.

Scientific question: does the previously qualified98-day refined native prefix
extend through the complete original forcing year while retaining conservation
and independent restart? This closes a documented execution-coverage gap;
it does not establish spatial convergence or the full historical Andelst model.
No production implementation, physical contract or default changes are selected.
Existing component science and latest NUT composition are inherited only with
their unchanged source/raw identities; unrelated component preservation,
RossFast, broad moving F-CI and highest low-air are NOT_SELECTED_IMPACT/POLICY.

Expected compile/link cost200s; O0 short feedback under30s; O2 annual
full/split/resume2400s combined, with actual costs reported separately.
First98-day complete native cost was501.64s, with180.99s split and272.35s
resume. These are preregistration estimates; completed results follow below.

### Completed refined-year continuation, 23 October 2026

The selected source-unchanged execution passes. Fresh checked O0/O2 closures
contain194 physical providers and153 original TTUTIL providers; the ordinary
project bundle reuses193 verified physical objects. O0 short preparation,
physical execution and independent restart pass. O2 executes the entire365-day
1998 constructed supported fixture on41 cells, with two crop periods and fallow.
The independently executed day180 prefix matches every daily field exactly;
fresh-process continuation matches all185 remaining daily budgets. Final
`state.csv`, `endpoint.csv` and `restart.bin` are byte-identical to the full run.
All98 previously qualified daily budget rows remain exact.

The literal original fixed/ETpot preparation gives6570 exact annual values,
6714 including both fresh short cases. Fourteen negative input/restart cases
pass. Independent daily, cumulative and endpoint stock reconstruction passes;
maximum daily water, solute and gross-water residuals are respectively
2.904e-14cm,2.606e-13mg/cm2 and9.483e-14cm (rounded upwards). Final cell and
surface stocks remain nonnegative. Original1e-4 temporal tolerance, low
dispersivities and strict mass gates are unchanged.

Actual native costs are1775.877s full,648.262s split and1154.923s resumed,
each below the unchanged1800s process limit. There are417026 accepted annual
substeps; these are local execution measurements, not portable speed claims.
The execution checkpoint remains `7bde3165791a33120aeef0fc9828a5d790f066f8`,
with the unchanged compiled source surface of `c2363394`. Later canonical
`710b4173` adds unrelated NUT/performance work; all213 actual execution inputs
remain exact. Its current composed source/raw owner and all147 controls pass.

The2197-member source/raw capsule is
`integration/mc-sol01/evidence/MC_SOL01_REFINED_YEAR_20261023.tar.xz.b64`,
decoded SHA256 `7dfe7a6cee6666484ebbbc8614a979d8ea86b240f7a46ddb3b66358d27303b4e`.
It retains the actual checkpoint/plan, compiler identity, generated original
sources, build/native streams, complete physical generations and its own
`verify_refined_year.py`. Eleven missing/corrupt/source/false-claim controls pass.
The separate qualification record is
`integration/mc-sol01/MC_SOL01_REFINED_YEAR_QUALIFICATION_20261023.json`;
canonical admission is a separate actual-merge receipt.

This supersedes only the earlier full-refined-year execution-coverage limit.
It does not establish O0 annual execution, spatial convergence, original full
Andelst equivalence, general/default historical dispatch or broader heat/snow/
age/NUT composition. Production/defaults, all frozen capability dispositions,
full MC-SOL01 and full MC-NUT01 flags remain unchanged.

### Actual refined-year canonical admission, 23 October 2026

PR1388 refined native year is canonically admitted at
`8066b06a6383bfbd1cd82bcbc3b8b22b41eb9cb0`; the complete merge tree exactly equals the
qualified `ce3c27cec3af23dce16958eff3f8c5ec48317208`. Actual-merge capsule validation,
all11 evidence controls and all163 current NUT preservation controls PASS.
`integration/mc-sol01/MC_SOL01_REFINED_YEAR_ADMISSION_20261023.json`
owns this admission. Production/defaults, capability dispositions and the
qualification-time record are unchanged. Spatial convergence, the original full
Andelst configuration, general historical/default dispatch and full SOL/NUT
closure remain open.

### Current canonical reconciliation

Reconciled7ae093c5b32b4abfd10a6a37c8113ecffa2cdbb6, including the concurrent
saturated-flux repair and refined-year admission. The complete193-provider
current closure was hash verified and the new native application separately
linked O0/O2. Both complete481-day/full/split/resumed executions were actually
repeated, with the additional independent daily gross budget assertion.
O0/O2 and old/current complete budget/state/endpoint/restart bytes are exact.
The current wet day8 rejection retains exactly the same committed day7 state.
The saturated-flux repair explicitly excludes Picard, so its successful plain
MvG wet case does not qualify the failing Picard fixture. The full current
predecessor owner and18 repair controls pass separately; the earlier163-control
owner remains explicitly historical. Neither receipt is relabelled as a fresh
whole NUT model execution. Current actual build/commands/raw artifacts are in
the resealed existing HIST-INTEGRATION01 capsule.
### Independent transport accuracy, 23 October 2026

The bounded study in `integration/mc-sol01/transport_accuracy/STATUS.json`
separates spatial and temporal error of the actual implicit-upwind process.
All36 checked O0/O2 profiles pass positivity, mass and independent dense/analytic
oracles. First-order time convergence and decreasing spatial error are observed
for the tested linear-sorption, small-dispersivity Gaussian cases. However,
at0.125cm spacing the concentration-peak deficit is still10.2% without sorption
and5.4% with linear sorption. These are pulse-specific measurements, not errors
of the native year. Closed mass therefore does not establish profile accuracy.
The coupled41-cell year remains execution-qualified; native spatial accuracy,
nonlinear-Freundlich accuracy and full SOL/NUT closure remain open. No production
source, default or tolerance changes are made.

### Actual native nested-grid observations, 23 October 2026

`integration/mc-sol01/native_grid/STATUS.json` records the constructed historical-
weather project on41/82/164cells with original chemistry and unchanged1e-4
temporal tolerance. Complete2day constant-bottom nonlinear-solute observations
give common-bin soil-stock L1 differences0.18735% and0.12327%; these are mesh
differences, not known-solution errors. The8day41/82difference is0.5389%;164cells
was explicitly censored at180s. Starting stock quadrature is retained. All
completed water/solute/gross balances and nonnegative stocks pass. These January
prefixes have no active crop or runoff and do not qualify full-year accuracy.
Current seasonal-caller reconciliation keeps the SRC tree exact and freshly
checks41cell2day state/endpoint/budget equality; historical82/164executions are
not relabeled. Current owner and30controls pass. Research, source/raw proof and
claim limits are separate from production/defaults and full SOL/NUT admission.

## HIST-INTEGRATION01 detailed rain and soil-factor successor

Implemented continuation, reconciled with canonical
`c22fe5b2bfad9cd832be4bca34c8fde1ac40cae7`. Existing
SWRAIN0 remains exact. SWRAIN3 resolves original RAINFIL year naming or one
.RAIN file through TTUTIL DAY/MONTH/YEAR/TIME/AMOUNT. Original LoadRainData
amounts belong to the preceding interval. Preserve complete source bytes,
including future unused data, in the existing restart-bound input document.
The native preparation day view integrates original rain records; physical
execution consumes the actual interval endpoints/rates, never a daily average.

The native application stages the existing water and solute owner types for
one reporting day, executes the existing joint pond transactions at rain
boundaries, and publishes only after every segment and the unchanged hard
daily water/solute certificates pass. A rain cursor is derived from the opaque
committed time; no new persistent owner, restart ABI, physics kernel or shared
interface. Scalar output receipts sum actual accepted trace contributions,
without constructing/copying an ever-growing concatenated flux trace.
SWCFBS1/CFBS0..1.5 uses the existing daily atmospheric-demand provider. SWREDU,
macropores, drainage and heat remain explicitly rejected by this front end.
No silent reduction or deactivation is performed on original physical input.

Owning surfaces: existing project/crop readers, launcher and native application.
Shared src and original reference bytes unchanged. Invariants2,3,7,9,13,21,23,29
remain binding. Select original whole LoadRainData and fixed/ETpot witnesses,
O0/O2 actual interval/day budgets, within-day failure rollback, source-bound
fresh restart and future-source rejection; preserve existing daily/seasonal
physical outputs. Reuse only hash-verified193 physical providers. Expected
build30s, focused60s, actual481-day composition up to1800s to test original
rainfall timing. Full F-CI NOT_SELECTED_IMPACT; highest low-air
NOT_SELECTED_POLICY; RossFast unused. Full original project parity is separate.

Actual evidence: `integration/mc-sol01/detailed_rain/STATUS.json` and its sealed
capsule. O0/O2 complete481days,2630 original rain intervals, original whole
LoadRainData and fixed/ETpot witnesses, day365 fresh restart and future-source
rejection pass. Daily water/solute residuals stay below1e-10 without clamps;
all O0/O2 physical outputs are byte-exact. The incumbent daily seasonal481day
and admitted wet97day proposal outputs remain exact. Four-times-rain Picard
fails on day7 after14 successful intervals: the rejected committed generation
is exactly the independent complete day6 restart, while the partial candidate
has advanced. This is failure atomicity evidence, not a completed wet product run.

A separate O2 native CPU observation measures45.389s CPU/45.400s wall for the
normal481days, and30.483s CPU/30.485s wall for the rejected wet prefix. These
checked builds and different completed durations establish no speed comparison.
All new long runs explicitly use1e-3. The requested1e-2 probe is rejected by the
existing application domain; no tolerance bound is relaxed. Full original
Andelst now reaches the explicit unsupported SWREDU rejection. Numerical heat,
macropores, drainage and Cauchy3 remain separate missing compositions. This
admission covers the existing ETref/simple-crop native route, not full original
Andelst, profile accuracy, full SOL/NUT closure or a mastercoverage promotion.

### Bounded conservative-correction prototype, 23 October 2026

`integration/mc-sol01/fct_prototype/STATUS.json` owns an isolated research module
that calls actual implicit upwind and corrects internal face transfers with
MUSCL-Hancock prediction and positive/max-preserving budgets. Checked O0/O2:
64uniform constant-water linear-advection profiles,288unsupported/CFL atomic
rejections, analytic cell-average improvement and hard mass pass. At320cells
the Gaussian peak deficit changes10.57%to1.01% without sorption and5.60%to0.73%
with linear sorption. These are zero-diffusion/zero-decay research cases, not
current native accuracy or timing results. The failed initial tiny-flux ratio
overflow is retained; traps and physical gates were not relaxed. No production
activation, changing-water/nonlinear/source/age/crop/restart/native qualification
or full SOL/NUT closure is inferred. Actual accepted-water coupling remains a
separate required scientific step.

### Changing-storage correction research,23October2026

`integration/mc-sol01/fct_water_sorption/STATUS.json` qualifies a separate
research successor with prescribed water-balanced single steps and actual
Freundlich storage/inversion. Checked O0/O2:192steps,2880atomic rejections and
384OFF delegations pass; exact constant/zero solutions and independent algebraic
low/corrected mass oracles pass. Maximum mass residual1.46e-15mg/cm2. Incoming
mass bounds use the new water content and nonlinear storage; only internal face
transfers change. The first independent-oracle convergence failure is retained.
Production sources, defaults, native dispatch and the frozen prototype remain
unchanged. Prescribed water balance is not replay of an actual accepted water
trace. Nonlinear transient accuracy, native/restart benefit, active additional
processes and full MC-SOL01 closure remain unqualified. No earlier pulse-accuracy
measurement is promoted to this changing-water scope.

PR1396 admits the detailed-rain/CFBS scope above at actual merge
`ba6b12ec5cff7844bce474e20ef136984a22d5ac`, complete tree
`93423c229671a4e0a38e3548e1e0fe922ccf2f73`. Actual-merge entrypoint controls
and source/tree identity are recorded in
`integration/mc-sol01/detailed_rain/ADMISSION.json`. The SWREDU2 continuation
needs the existing Boesten owner layout in the pond joint transaction and
lossless restart; the present BASE-only transaction and S5MJ0001/0002 writer
explicitly reject this composition. Merely accepting the SWP flag is unsafe.

### Actual accepted-carrier correction research,23October2026

`integration/mc-sol01/fct_accepted_trace/STATUS.json` owns a separate bounded
successor. Actual committed Reference traces from12checked O0/O2 two-day runs,
2486accepted substeps and40/80/160cells feed72 real process/research replays.
All360late batch rejections and72exact split continuations pass. Maximum chemical
mass residual5.371e-14mg/cm2; water and solute postimages are exact O0/O2.
Independent carrier-defined refined finite-volume references support41.4% to
88.1% lower L1 deviation than low order across18Gaussian cases, with explicit
reference-resolution criteria and the failed/coarse rounds retained. The
existing exact-empty-pond physical option is explicitly selected on both sides;
the unselected production default is not qualified by this experiment.
This advances the earlier prescribed-step limitation only for pure downward
no-sink carriers and uniform material. Production activation, joint native
water/chemical transactions, dispersion/decay/root/crop/age composition, native
restart/year accuracy and full MC-SOL01 closure remain separate and open.

## HIST-INTEGRATION01 Boesten continuation

Baseline: canonical22cdf5700dbea526c2ef217db20b738048e3eebe, complete tree
equal to local77bdbf286. Reuse the existing SWREDU2 Boesten physical owner,
COFRED process and SPEV/SAEV continuation. Extend accepted water trace access
only for the plain Boesten layout, compose it with existing pond-solute owners
and root binding, and preserve the original process equations. No second state
owner or empirical daily replacement. Reject macropore/Rutter/heat/snow and
step-proposal combinations in this caller.

S5MJ0003 explicitly carries the Boesten pair and surface chemistry; existing
S5MJ0001/0002 encodings stay byte-exact. Restore remains tentative until CRC,
layout, pair domain, water and chemical identity and owner-clock checks pass.
Rain reporting days retain the already admitted atomic publication boundary.

Select local checked O0/O2: small real coupled driver, original Boesten process
and water runtime preservation, changed pair wet/dry/ponded paths, independent
water/solute/gross balances, chemical rejection after successful water trial,
fresh-process V3 restart and malformed/wrong-layout atomic rejection. Then
select native8day and481day historical-rain composition if focused results
support it (expected physical rebuild180s; focused60s; native up to1800s).
Preserve existing daily/detail-rain and wet-proposal application outputs.
Full F-CI NOT_SELECTED_IMPACT; highest low-air NOT_SELECTED_POLICY; RossFast
unused. Mass gates remain1e-10 and explicit temporal tolerance1e-3. Sole
physical/chemical ownership, candidate publication, rollback and lossless
restart remain binding. Qualification and canonical admission have separate
status and actual-merge receipts below.

The actual focused run exposed repeated temporal rejection under the old
water-only identity metric. For the new plain-Boesten accepted-trace route,
use the existing pond-water full/half error and the maximum absolute SPEV/SAEV
full/half difference (all existing centimetre quantities). This tests the
persistent process continuation as well as the water owner. Original
Boesten water-only model-certificate/identity behaviour remains unchanged.

Actual frozen-conductivity historical rain completes64days before a later
interval on day65 rejects (45 intervals completed in that day). Keep this failed
observation. Select the existing Picard/continuous-MvG numerical route for the
Boesten composition, with the same1e-3 temporal tolerance and hard budgets;
no new solver or physical reduction formula. This is a new coupling
qualification, not inheritance of the earlier SWREDU0 Picard run.

The first Picard observation reaches270 complete days, then rejects on day271
with zero mass rejections near saturation. Bind the selected continuous-MvG
Boesten route to the same existing weather-surface temporal measure as the
admitted continuous-MvG pond route: unsaturated heads, storage and Darcy/pond
flux differences, augmented here with the Boesten history pair. Keep the
original plain/frozen metric and the failed observation. No mass threshold,
process history, concentration or accepted physical state is adjusted.

Actual historical input uses `COFREDBO`, not the internal process field name
COFRED. The native route reads that original key. The final481day fixture uses
the original Andelst coefficient0.79; the short independent case uses0.35.
Both O0/O2 complete and freshly restart with exact physical output. Their
maximum daily residuals are1.705e-14cm water and8.643e-14mg/cm2 solute, below
the unchanged1e-10 gates. Whole original Boesten process and water-only
preservation pass separately; the new plain trace/root route adds chemical
rollback, retry, ABA, accepted root feedback and V3 CRC/pair/layout rejection.
Compensation, salinity, frost and mechanistic-oxygen variants remain excluded
from the new Boesten root composition. The pre-existing root-OFF water route
keeps its original admission boundary.

Actual four-times-rain Boesten O0/O2 fails on day7 after14 intervals and leaves
both owners, including SPEV/SAEV, exactly at the independent complete day6
restart; the partial day candidate has advanced. Failed frozen64day and first
Picard270day observations remain retained under their actual source identities.
Full original Andelst input now reaches the explicit SWDRA rejection. Detailed
rain, CFBS and Boesten admission does not qualify drainage, macropores, Cauchy3,
numerical heat, full original-model parity, profile accuracy or full SOL/NUT.
The sealed scope/selection is `integration/mc-sol01/boesten/STATUS.json`;
canonical admission requires a separate actual-merge receipt.

The matched constructed481day comparison keeps139.6508cm rain unchanged.
Activating Boesten reduces soil evaporation23.4807 to17.8460cm, increases pond
evaporation7.1595 to8.2200cm and runoff64.5493 to69.1376cm; transpiration changes
18.2314 to18.2173cm. The increased wetness/runoff follows the physical reduction
of bare-soil evaporation, with independent gross budgets closing. This is a
material process-option effect, not numerical equivalence to SWREDU0 or full
original Andelst output. A separate checked O2 native observation measures
42.529CPU/42.531wall seconds for481days and30.884CPU/30.898wall seconds for the
failed wet prefix. Different physics/durations establish no speed comparison.

Canonical PR1399 NUT progression is reconciled before admission. Its four
production providers and original assertion bodies remain unchanged. The
affected two water-provider changes select74 fresh transitive compilations,
580 verified unchanged module-closure reuses and all78 actual HIST processes;
all original HIST assertions and incumbent endpoints pass. Four current
nondepleting Richards/crop/N runs and eight process restarts also pass exactly.
The original40-control NUT proof is frozen at4beca656; historical input reads
for the two changed water providers retain that source identity, while the
fresh current composition proves the new postimage.36 current source/raw
controls pass. Neither exhausted competing sinks nor full NUT is promoted.

PR1400 canonically admits this bounded composition at actual merge
`b98b7606cab8de8ba5f5bad09b54dc4ee2241c8d`, exact qualified complete tree
`a76d43d7b5a8acc37a60a187104702e427fd827a`. Four current owner entrypoints
each pass36 source/raw controls on that postimage. The receipt is
`integration/mc-sol01/boesten/ADMISSION.json`; whole original Andelst and the
remaining drainage/macro/Cauchy3/heat compositions are not admitted.
