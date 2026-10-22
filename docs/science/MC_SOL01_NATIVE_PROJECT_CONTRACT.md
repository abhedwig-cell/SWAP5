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

