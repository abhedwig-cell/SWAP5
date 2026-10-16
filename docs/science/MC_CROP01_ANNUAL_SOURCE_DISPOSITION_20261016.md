# Classic annual crop: source-state completeness disposition

Status: **BLOCKED_SOURCE_STATE_COMPLETENESS**, 16 October 2026.
Capability: `SW431-CROP-ANNUAL`, `SW_WOFOST=1; IDSL=0; SWCROPSNM=0`.
This is a negative full-capability qualification conclusion, not an admission,
replacement decision or new crop variant. Production is unchanged.

## Fixed authority and acceptance boundary

Canonical was pinned at `d27c6abe023eecd4f2e63ae42ad2fb330ad2ef15`.
The existing master/PR1072 checkpoint is
`988b46c3246e835b6f9bcd97b3f2714c56de30d2`. Its annual row has **no remaining
capability dependencies**. The existing source resolution and surface/crop owner
reviews require literal B1.11 actual daily/seasonal trajectories, water stress,
carbon/organ/leaf closure, accepted-event ownership and restart. These conditions
were recorded before execution; they were not widened after observing a failure.
Automatic emergence, Soil-N, soybean/grass, IDSL1/2, root-depth variants and
companion potential RELMF remain separate. Whole sowing/harvest/rotation admission
is not imported as an annual dependency.

The real archived source is `SWAP/wofost.f90`, SHA256
`3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b`,
from PR1072's existing `SWAP431_B111_AUTHORITY.tar.gz.b64`. The new probe verifies
that hash before compiling literal source routines. No WOFOST81 or PCSE donor is
used as a substitute.

## What is implemented and demonstrated

The existing classic prepare/finalize/two-phase/structural production modules
already implement AMAXTB assimilation, respiration, organ partitioning, water
stress, leaf cohorts, thermal development and anthesis/maturity clipping.

Three 200-day source/process trajectories were run at O0/O2: relative uptake1,
relative uptake0.6, and a five-day cycle0/0.25/0.5/0.75/1. Each trajectory traverses
anthesis and DVS2. Literal `totass`/`assim`, `update_dvs_rate`, `update_wofost`,
partition/carbon checks and leaf routines form the independent source side.
Production calls the real two-phase crop window. Source organ balance, assimilation,
all living organs, LAI/cohorts, DVS, thermal sum and anthesis are checked every day.
The same prepared candidate is replayed without modifying the input owner.

Every17 days the actual classic production transaction persistence API exports,
reconstructs and returns the owner used for subsequent days. This demonstrates
continued **living-state** equivalence, not completeness of the B1.11 state.
O0/O2 stdout is identical. Maximum absolute living/source difference is
`1.918465386552271e-12`; probe comparison tolerance is1e-10 relative, with a unit
absolute floor. Existing admission tolerances were not changed. Final compile/link
costs are3.190s/9.738s; native costs0.022s/0.014s. Separate compile/link times are
UNKNOWN because each measured command combines both stages.

This is a discriminating process qualification with supplied weather/astronomy
and water-ratio boundaries and constant parameter tables. It does not establish
variable table interpolation, calibrated field behaviour, Richards coupling,
automatic calendar/harvest scheduling or fresh-process disk restart. Growth after
DVS2 is exercised as the literal task3 process; the fixture does not assert that
a real application's harvest dispatcher would continue that crop.

## Concrete failed full-capability precondition

B1.11 `update_wofost`, lines1083..1085, retains three cumulative dead-organ masses:
`DWRT += DRRT`, `DWLV += DRLV`, `DWST += DRST`. These are explicit source state,
subsequently published through `update_wofost_interface` and end-state output.
They are not alternative root-depth or Soil-N options.

The common `wofost_actual_biomass_state_t` stores living root/stem/storage mass,
leaf cohorts, specific area, leaf age and exponential LAI. It has no retained
dead-organ masses. The classic crop owner adds phenology and minimum-temperature
history, not those inventories. The classic transaction persistence view copies
that owner. Its optional root/potential/lifecycle carriers do not provide the
three missing actual-organ inventories.

The source produces positive cumulative death in all three trajectories. For the
nonstressed trajectory, terminal dead root/stem/leaf masses are respectively
2013.711641103772,2529.122365652407 and2838.164478166315kg/ha. The corresponding
living states match production, but the full source totals cannot be represented
or reconstructed by the existing classic owner. Native living-restart PASS is
therefore not a complete-organ restart PASS. This is a state-representation gap,
not a demonstrated error in the living growth equations or the existing bounded
persistence API.

No accepted reference decision has been found that removes those retained source
states or replaces this classic capability with WOFOST81. A SUPERSEDED or ADMITTED
disposition would consequently lack authority.

## Resolution boundary and recovery

The previous qualification-only classification overstated implementation
completeness. Reclassify this single capability as ACTIVE_MIGRATION with the
bounded blocker `CLASSIC_RETAINED_DEAD_ORGAN_STATE`. The total unresolved denominator
is unchanged. This does not assert that AMAXTB or the whole crop implementation is
missing.

Before another admission attempt, the existing common biomass/crop and persistence
owners need an explicit retained-mortality/total-organ representation, initialization
and legacy/default compatibility decision. It must preserve their single ownership
and identify the actual affected WOFOST81/harvest/codec consumers. That shared-state
successor is not silently introduced in a qualification-only work unit. No additional
external permission is asserted as necessary; the next work must carry that explicit
owner contract, implementation and its proportional preservation gates together.
Then prove nonzero mortality through source trajectories and accepted-event rollback,
exactly-once publication and complete source-state restart. Reuse unchanged living
source evidence where its dependencies permit.

The current full admission attempt stops at this failed state-completeness
precondition. Accepted-event admission, a real Richards-linked trajectory and
complete-organ restart qualification were not executed or labeled PASS. Full F-CI,
RossFast, frost and unrelated N/root qualification were not selected. There is no
production merge. A later canonical advance to`9b05521b` changes only NUT leaf-return
review/status/evidence, with no overlap in the compiled classic dependency surface.

Recovery, exact inputs, raw O0/O2 logs, failed harness-path attempt and executed Git
bundle are in `MC_CROP01_ANNUAL_QUALIFICATION_STATUS.json` and its sealed source
qualification capsule. The existing master recovery and capability row carry the
same bounded disposition; no duplicate migration PR is needed.

## Selected same-owner repair, 16 October 2026

Following the explicit continuation instruction, canonical is pinned at
`9b05521b2df3579869f1906cb13900078fdeeda4`. No newer production candidate overlaps
this work. The three DW variables are **cumulative gross mortality diagnostics**,
not additional physical retained-material pools. In particular dead roots may
already have been returned to soil; their cumulative diagnostic must not be added
to the physical water, N or organic-matter storage balance. This clarifies the
previous inventory terminology without weakening the full source-state gate.

Selected representation: three zero-initialized, finite nonnegative cumulative
organ-death scalars in the existing `wofost_actual_biomass_state_t`, copied by its
existing clone and the existing classic owner/persistence API. The classic rate
packet exposes the already computed root/stem deaths; structural evolution adds
stress plus age leaf death exactly once. No growth/assimilation equation, N state,
root owner or transaction authority changes. WOFOST81 uses its existing independent
structural updater and keeps the new diagnostics at their default zero until its
separate source/diagnostic policy is selected; no WOFOST81 equivalence is claimed.

Extend the existing qualification-only F-WOF40 external adapter in place: codec1
bytes stay unchanged for zero counters, codec2 carries nonzero counters. Codec1
restores the previously admitted zero-counter representation; it cannot recover
unrecorded historical B1.11 mortality and does not claim that equivalence. Unknown
codec, nonfinite/negative counter and truncated extension fail closed. The existing
opaque production persistence carries the complete owner directly. This adds no
production codec and allocates no native crop/Soil-N codec tag.

The fixed annual acceptance conditions remain controlling. Execute small literal
source O0/O2 trajectories including all three counters, same-owner clone,
rollback/replay, real accepted-event publication/retirement and existing persistence
continuation. Extend existing true-process restart tests, preserve the WOFOST81
source trajectory and old codec bytes, and select only affected owner gates. Any
remaining physical-runtime/admission gap must stay explicit; these repairs alone
are not permission to declare the whole capability admitted.
