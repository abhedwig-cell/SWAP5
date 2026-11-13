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
and project calendars. The existing complete solute auxiliary state is required
for WOFOST/scheduled-irrigation combinations; the known grass-only water path
retains its own native state.

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
