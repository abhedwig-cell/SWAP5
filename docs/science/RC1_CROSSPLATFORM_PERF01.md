# RC1 cross-platform and performance successor

## Frozen scope and first transport discriminator

RC1 remains `release/swap5-nomacro-rc1-20261112` at
`11529865e76fb2259542f1e770726cd87af27603`. The workstream owns
`integration/f-ci/RC1_CROSSPLATFORM_PERF01_20261112.json`.
No active macropore or broad migration work is selected.

Existing exact-input benchmarks retain the GNU16.2/O2 original, actual input
bytes, output-only compatibility settings, failed literal CSV attempts and
original scientific FAIL dispositions. Mixed WindowsGNU16.2/LinuxGNU15.2
full trajectories are evidence of combined build/platform differences, not an
isolated operating-system effect or an accuracy-matched speed ratio.

The measured dominant wall bucket is waiting for the Fortran donor. Worker CPU
is reported separately from overlapping wall buckets. Process launch, Python
JSON and transcript flush are smaller; they are not assumed to explain the
whole SaltFarm ratio. Zero budget-step rejections do not mean zero extra Newton
iterations: the strict original-block mass-polishing policy is retained.

A full SaltFarm coherent-worker replay without the SWAP5 kernel reproduces every
unrounded physical record and the original CSV exactly. Thus Python/kernel state
transfer is not the source of the baseline field differences on this profile.
The generated worker still has daily return boundaries; this alone does not
exclude a Fortran day-return dependency. That distinction remains explicit.

## Rejected internal hydraulic-frame prototype

The diagnostic prototype changed only original-worker hydraulic output serialization. Each
binary64 groundwater, bottom flux and pressure-head value is transferred to an
ISO `int64` bit pattern and emitted as sixteen hexadecimal digits. The tag is
`HYBRID_HYDRAULIC_HEX_V1`; order remains groundwater, bottom flux, all grid heads.
This is a text framing change, not a binary restart codec or a process equation.
The Python receiver reconstructs the exact IEEE bits, checks word width and
finiteness, and supplies the existing canonical hydraulic view. Existing decimal
frames remain readable. Signed zero and all finite normal/subnormal values round
trip exactly. Empty, truncated, invalid-hex and nonfinite frames refuse.

No values, state, original process order, mass guard, rollback, journal durability,
input, user CSV, external transaction or restart codec are omitted or relaxed.
Source/build binding changes deliberately; old checkpoints are not rebound.
Candidate admission requires actual whole-trajectory and own-native-restart
preservation on each tested platform, and relevant O0/O2 coverage.

The output-only prototype preserves every SaltFarm CSV record and terminal
native/auxiliary byte. Its hex variant also preserves all daily unrounded heads.
Its one-shot cost change is only a discriminator, not the accepted speed result;
paired full application measurements determine whether the candidate is useful.

## Selected first implementation: one compiler verification per invocation

The hydraulic prototype is NOT admitted: paired full SaltFarm model/controller
cost did not establish a material improvement over normal run variability.
The implementation restores the original hydraulic text producer/receiver
exactly. Raw prototype data and its complete bit-preservation result remain.
No new frame is part of the supported interface.

After the dominant native compute cost is separated, the actionable public-route
cost is repeated toolchain verification. The CLI already validates the current
compiler executables, versions, targets and provider before it validates a reused
build. It now passes that invocation-local verified toolchain record to the build
validator instead of launching and hashing the same tools a second time. A
standalone build-validation call still obtains a fresh toolchain record.
No cache survives a command, no mutable global cache is added, and source/object/
library/input/executable/binding checks remain. This changes neither original
Fortran nor any physical state, journal or rollback contract.

## First qualified numerical and cost results

Both WindowsGNU16.2 and Ubuntu26.04GNU15.2 pass all three source-bound O0/O2
public-route controls: complete O2 periods, exact baseline/candidate physical
journals, all original CSV fields and exact own native/auxiliary continuations.
Original origins remain unchanged. New toolchain/compiler/provider refusal
controls run before output. Ordinary standalone validation still refreshes tools.
The changed preparation-helper identity requires a newly prepared provider on
the successor; RC1 providers/checkpoints are not silently rebound. Frozen RC1
checkouts remain usable at their own exact dependency surface.

The first improvement removes seven duplicate compiler/version/target process
calls and three binary-hash reads per reused-build invocation. Windows observed
non-model startup overhead drops by0.40/0.40/0.58seconds for full Grass/Hupsel/
SaltFarm; Ubuntu drops by0.006..0.010seconds. Full wall observations are noisy:
Windows11.27->11.04,7.59->7.63,12.58->13.06seconds. These do NOT establish a
native solver speedup or a statistically resolved whole-run gain. All timings
include the same source-bound user route and one saved state; original earlier
no-checkpoint benchmarks keep their separate scope.

The dominant extra native work is now counted. Original versus corrected
converged-solve/iteration totals are48493/108964 versus the same for Grass,
32518/104672 versus43636/227360 for Hupsel, and38772/77664 versus59176/219566
for SaltFarm. The original Newton/mass-polishing policy affects subsequent
adaptive steps; zero additional budget rejections does not erase this cost.
No stopping rule, iteration or tolerance is relaxed for a speed claim.

For all three Windows projects, a corrected coherent full-call worker produces
exactly the same daily unrounded water, heads, uptake, supported soil-temperature
state and solute frames as the daily-return worker. All corresponding user CSV
controls remain exact. Thus the daily split and external SWAP5 transfer are
excluded as the source of these selected whole-trajectory differences. Hupsel
and SaltFarm first nonzero head/heat/stock differences already arise on day1
inside the corrected original block; their complete differences against4.3.1
remain quantified rather than universally explained by one correction. Grass
matches the original observer exactly, including all supported thermal states.
This diagnostic is not a replacement scientific reference or full-energy claim.

The separate cross-platform assessment remains open: compiler-major and C/math
runtime differences must be separated before attributing observed amplification
to the operating system, and no fitted tolerance is introduced. Existing failed
original oxygen criteria and underqualified reference families remain visible.

## Matched GNU15.2 control and bounded scientific disposition

The additional Windows2022 GNU15.2 MinGW control completed successfully in
Actions43252338070 at3f0ad796ef88b201ba17ebb30290ee80f5f5e678. All three
O0/O2 public builds, complete O2 periods and short exact own native/auxiliary
restarts pass their unchanged guards. Ubuntu26.04 GNU15.2 controls are the
existing successful43246935136 and43249724326 runs. Executed input hashes match
across the cohorts; generated donor source text matches after CRLF/LF
normalization. Compiler binary, target and runtime identities remain distinct.
Matching version numbers do not isolate OS, C library or build-distribution
effects, and cloud/laptop timings are not compared as a solver speed ratio.

`GNU15_WINDOWS_UBUNTU.json` records every observed maximum with day, slot,
unrounded values and complete-stream hashes. These are descriptive differences,
not newly fitted acceptance bounds. Original4.3.1 has identical successful-solve
histograms on all three projects; maximum original Hupsel head differences are
8.98e-10cm and SaltFarm1.24e-12cm. The corrected routes remain sensitive even
with the same compiler version:

| Complete corrected profile | Head maximum (cm) | Temperature maximum (C) | Stock maximum (cm) | First histogram fork |
| --- | ---: | ---: | ---: | ---: |
| Grass1827 | 1.44e-10 | 2.63e-13 | 2.84e-14 | None |
| Hupsel1096 | 17.28254 | 0.006461 | 0.001152 | Day364 |
| SaltFarm1461 | 0.112589 | 0.008229 | 0.020219 | Day156 |

Both operating-system cohorts reproduce their own corrected daily route exactly
in a single coherent full-period original-main call, including nodal heat,
heads, uptake and solute. Thus daily state transfer and daily-return clock
boundaries are excluded for these tested differences. Native numerical-policy
branch amplification remains a demonstrated limitation. Compiler-major change
alone cannot explain it. The original reference comparisons, including failed
Hupsel584 oxygen and underqualified reference families, remain failed/open.
Functional whole-period execution and same-build restart are qualified;
whole scientific or portable trajectory equivalence is **not qualified**.
The listed maxima do not constitute accepted errors or a full energy balance.

## Rejected pure-polish adaptive-feedback experiment

The private discriminator retains every original Newton iteration and every
1e-10 water/solute guard. Only when convergence took exactly one extra final
confirmation iteration does a local wrapper remove that one iteration from
the subsequent time-step growth feedback, outside the Fortran DO loop. Actual
iteration histograms retain all executed work. Maximum-iteration step reduction
is preserved. No saved state, supported model or frozen release was changed.

Five-day controls pass unchanged guards and reduce work markedly. The bounded
full-period discriminator then gives Hupsel43636->35176 accepted solves and
227360->196420 converged-solve iterations; SaltFarm59176->38885 and
219566->141096. However, Hupsel day364 has independently summed daily water
residual **1.0033339783999118e-10cm**, exceeding the existing1e-10 bound.
SaltFarm's full-period guards pass, but that does not admit a generic policy.
The candidate is **REJECTED_NOT_ADMITTED**. No tolerance change, selectively
enabled SaltFarm shortcut, extra reference campaign or claimed speedup follows.
No O0/restart/platform qualification of this rejected policy is claimed.
`POLISH_FEEDBACK.json` preserves both successful and failed controls; the
private generated sources and raw ledgers are in the hashed proof archive.

## Checkpoint and exit cost decomposition

The instrumented same-build four-day controls for all three projects preserve
every physical record and exact native/auxiliary2-to4 end state. Publication,
archive/identity verification and case preparation are separate from worker CPU.
Resume publication costs about0.006/0.021/0.022seconds for Grass/Hupsel/SaltFarm;
archive/identity verification about0.035/0.036/0.038seconds. The generated native
serialization remains inside the donor-return wait bucket, not falsely resolved
as a separate measurement. cProfile separately records normal worker close and
per-command compilation/loading of the durable publisher. Steady publisher setup
is about one second here; one cold7.04second outlier is retained. These are
instrumented diagnostic costs, not headline timings or additive CPU/wall totals.
`RESTART_COSTS.json` records all observations and exactness checks.

The safe invocation-local startup optimization remains admitted byPR1665,
postimage95b16cfab4f5e7597d366d355d83e9812993a1b0. The dominant numerical cost
is investigated and the attractive generic shortcut rejected by an unchanged
physical gate. Portable Hupsel/SaltFarm scientific acceptance remains an explicit
release decision; neither roundoff language nor performance evidence authorizes
accepting their complete cross-platform trajectories.
