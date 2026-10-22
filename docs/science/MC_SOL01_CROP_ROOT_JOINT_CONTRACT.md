# Native daily crop/root/solute composition

Status: locally qualified bounded native daily composition; canonical admission
is recorded separately in the existing recovery record. Owner: existing MC-SOL01 recovery record,
simple-crop preparation child, `root_joint_successor`. Baseline63676062.

An explicit crop application composes the existing native calendar/phenology/
canopy/ETref preparation with original TTUTIL root-density/Feddes input, actual
accepted Reference water and original matrix/pond solute. The core physics is
unchanged. This application has the incumbent column's I/O/state orchestration
and adds a mandatory `/crop/` group and current committed root binding. It does
not introduce a second water, root, crop or chemical equation implementation.
The separate explicit front end keeps the already admitted column and its
complete execution dependency surface byte-identical.

Root profile and stress are evaluated once from the accepted **beginning of each
daily reporting window**, using existing static RDCTB geometry and macro-Feddes
uptake. The resulting nodal sinks are fixed for that window. Accepted hydraulic
substep traces are the sole water/solute carriers; potential demand must never be
passed as actual extraction. This bounded composition is not the original full
within-substep stress feedback. That broader timestep contract stays open.

Scope: one CROPTYPE=1 period, immediate emergence, IDEV1/2, SWETR1, SWCF1,
SWRD1, static root density, macro drought and optional empirical oxygen stress.
Native upper-layer node support comes from ISOILLAY/NCOMP. Physical oxygen,
salinity stress, adaptive roots, compensation, interception, CO2, heat, snow,
water age, nutrients, proposal policy and general historical/default dispatch
are excluded. Zero demand and fallow use the production zero-root route.

The native SWP bootstrap supplies the exact grid, hydraulic profile, initial
head and chemistry. RDS must fit that profile; a second prescribed root sink is
rejected. Original TSCF supplies chemical root uptake. Biological state has no
water feedback in this SWRD1 branch and is deterministically prepared from all
original source bytes. The generated forcing embeds complete SWP/CRP/MET bytes
and reader/generator identities. Existing complete-generation restart therefore
binds crop input as well as physical water/pond/chemical state. A changed CRP or
MET, including bytes outside the executed prefix, must reject continuation.

Transactional trial/commit, balances and restart layout are unchanged. Chemical
failure must retain both committed owners, and retry must recompute roots from
the same accepted beginning state. Diagnostics independently integrate accepted
root sinks and compare them to the bound actual uptake. Budget columns report
potential, actual, drought and oxygen reductions in cm per reporting window.

Invariants:2,3,7,9,13,21,23,29. Scientific tests: current production root/density
contracts and original source oracle; real native dry/wet/drought/oxygen/harvest
composition, hard water and solute conservation, source-bound fresh restart,
invalid input atomic publication, and chemical rejection/retry ownership.
Build native applications O0/O2 before broad stable-candidate qualification.
Expected cold build/physical suite:240seconds; existing unchanged numerical
providers and proof are identity-checked, not blindly rerun. Full F-CI is
NOT_SELECTED_IMPACT; highest low-air is NOT_SELECTED_POLICY.

Qualification:16 O0/O2 physical cases and128 daily balance observations;16
independent-process restarts are byte exact;30 invalid/source-changed inputs
reject atomic publication.82 application controller processes pass their expected
outcomes. Original upper-layer stress support, scalar parameters and both RDCTB
axes are checked explicitly after native serialization. A zero-density or rootless
future plan rejects even when only an initial fallow prefix was requested.
Two actual root/chemical rejection/retry tests produce exact binary owner identity;
their four compile/run events reuse193 unchanged provider objects per optimization
from the new194-provider application build. These are measured accepted-state
closures, not a small process-only build. Existing root contract and empirical
oxygen modular cases also pass O0/O2. Six fallow state/endpoint/restart artifacts
and all incumbent common budget values remain exact against the unchanged
application. Existing prep576-value and full physical SOL/NUT raw authorities
validate every current executed input byte.

The separate crop executable deliberately reuses the existing column launcher
and complete-generation file inventory. A new explicit application is required
to consume `/crop/`; no old application silently accepts that group. Build it
with `tools/solute/build_crop_column.py`; build the small original root reader
with `tools/solute/build_root.py`, and use the admitted crop reader from
`tools/solute/build_crop.py`. `tools/solute/run_crop_daily.py --help` lists the
explicit three source files, three executables and output/restart arguments.
No crop state is inferred from an unbound historical loose restart.


Concurrent PR1368 reconciliation:canonical advanced to f2b7be23 while this crop
work was qualified. Its three NUT output providers are outside all194 new crop
application inputs and outside the old SOL build. Their exact admitted source,
current cold/thermal native proof and21 original owner controls are preserved.
The old NUT raw execution is explicitly frozen at63676062; it is not presented
as current proof for changed providers. The current thermal output validator
checks all336 executed input identities and all original cold/thermal/atomic
assertions. Both owning entrypoints receive exact additive handoffs to the
composed crop guard; all earlier assertion bodies remain byte-preserved.
No physical rerun is selected for the crop column because every actual compiled
input, forcing, driver, oracle, compiler flag and recorded result is unchanged.
