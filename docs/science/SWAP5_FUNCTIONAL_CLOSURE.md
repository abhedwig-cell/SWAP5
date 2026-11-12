# Current functional closure of the original projects

## Shared no-macro surface input and complete day-state successor

The source-bound successor in
`integration/f-ci/NOMACRO_SURFACE_IRRIGATION_20261112.json` extends the existing
daily surface-event consumer to SaltFarm and Hupsel through
`surface-irrigation-daily-v1`. The legacy Hupsel mode retains its project
restriction. Water, salinity and application rate remain explicit caller inputs;
no original event table or active-macropore input is silently changed.

Two demonstrated conserved-state defects are closed. The original dry-surface
mixed-reservoir equation is evaluated in its exact complete-transfer limit when
pond and macropore area are exactly zero, preventing a negative roundoff stock.
Separately, resetting cumulative output counters no longer erases restored
physical surface solute. Actual saved day109 held0.001834mg/cm2 which the old
initial counter reset lost on day110. Cold initialization, wet-surface physics,
strict nonnegative native-state checks, codec and all tolerances are retained.
An unrestartable private candidate is refused before external publication.

Fresh Windows/Ubuntu26.04 donorO2/kernelO0/O2 cohorts complete Grassgrowth1827,
Hupsel1096 and SaltFarm1461:12 profiles and17536 accepted daily records. All72
seasonal own windows remain physical/native exact. Forty-four accepted surface
histories cover legacy/shared Hupsel, SaltFarm changed/disabled/original summer
events and original/changed winter events. Twelve further actual day109-to110
continuations consume the retained identity/modified/disabled histories, with
exact live/disk native payloads and independently initialized original-table
physical controls. The earlier winter mass refusals remain historical evidence;
the current repaired histories pass without parameter tuning or relaxed guards.

Complete supported numerical heat export is freshly checked after the changed
solute producer, with exact physical/native controls and unchanged1e-9J/cm2
guards. Water/solute retain1e-10 limits. Current Grass prescribed-groundwater
transactions also pass; existing MODFLOW source/contracts are unchanged. Actual
release CLI probes refuse13 active/missing/ambiguous/fractional-macro requests
before output or compilation; all three selected original SWMACRO0 files remain
unchanged. This verifies named profiles and supported process combinations, not
arbitrary original options or whole scientific equivalence.

Commands, compiled providers, original inputs, actual generated sources, raw
trajectories, checkpoints, negative controls, failed predecessors and costs are
bound by the owning record and its member-hashed raw archive. The
[surface-event contract](HYBRID_HUPSEL_DAILY_IRRIGATION.md) and
[scientific disposition](FULL_TRAJECTORY_SCIENTIFIC_DISPOSITION.md) distinguish
the corrected physical-state contract from preserved historical references.
Admission is established only by the PR and verified canonical postimage in the
owning record; the earlier sections below keep their own dated scope.

## No-macro original-project successor,12November2026

[PR1658](https://github.com/abhedwig-cell/SWAP5/pull/1658) adds the additional
original-workbook SaltFarm/Texel04dS configuration through the SAME daily host:
195nodes, potato rotation, saline irrigation, drainage and original sinusoidal
lower boundary,1461days. Windows/Ubuntu26.04 donorO2/kernelO0/O2 complete the
period; five own windows, including the terminal/year boundaries, reproduce the
complete physical receipts and both native payloads exactly. The accepted
seasonal t and calendar iyear are serialized explicitly in S5NON006/S5HUP012;
original computation order and existing tolerances stay unchanged. The earlier
terminal failure is retained with its causal observation and corrected successor.

The owner's next release excludes active macropores. Its selected configurations
are Grassgrowth1827,Hupsel1096 and this materialized SaltFarm1461 scenario. The
original workbook's numerical/date content is preserved; byte equivalence with
the original R preprocessing is NOT claimed. Existing Andelst functionality,
branches and proof remain preserved outside that release selection; original
active-macro inputs are explicitly refused by the no-macro release option.

The subsequent compact observer exports supported original conduction/storage
for every accepted day of all three selected complete periods on Windows and
Ubuntu26.04, at O0/O2. Original production coefficients and reductions are
preserved; the saline irrigation108–110 discriminator agrees exactly with the
retained detailed headers and within the existing1e-9J/cm2 independently
reconstructed nodal budget. Compact files contain production reductions, not
independently exported node measurements. All complete physical receipts and both
final native payloads remain exact against their source-bound unobserved controls.
The worker owns its buffered output channel; this is process-local observation
I/O, not shared model state or a thread-safety claim. Numerical heat export is
separate from complete mass-carried energy and whole scientific equivalence.
The failed Grassgrowth oxygen criteria and underresolved
Hupsel reference families below remain visible. Source/build/command/raw evidence
and the next functional acceptance point are recorded in
`research/hybrid-water01/NOMACRO_RELEASE_WORKPOINT.md` and
`integration/f-ci/NOMACRO_RELEASE_20261112.json`.

The full-period thermal successor is owned by
`integration/f-ci/NOMACRO_HEAT_EXPORT_20261112.json`, with raw compact receipts,
source/build/input identity, unchanged1e-9J/cm2 cell/global checks, accepted-only
support, measured costs and retained censored attempts. Missing advective donor
energy remains unavailable; asserting zero advection still FAILS. The thermal
export closes a supported accounting gap without changing temperature physics,
water/solute/uptake, accepted state, restart codecs or external forcing contracts.

The earlier three-application table below retains its own baseline and profiles;
it must not be confused with the owner's three selected no-macro configurations.

Complete compact observation calls (seconds, O0/O2 accounting objects and kernels,
original donorO2) have the following measured costs. Compilation/linking is
recorded separately; each selected call retains its60second cap. These are
same-platform preservation measurements, not an accuracy-matched SWAP431 speed
claim or a portable performance guarantee.

| Configuration | Accepted days | Windows seconds O0/O2 | Ubuntu26.04 seconds O0/O2 |
| --- | ---: | ---: | ---: |
| Grassgrowth | 1827 | 20.79 / 18.10 | 11.97 / 10.26 |
| Hupsel | 1096 | 10.98 / 10.12 | 4.39 / 3.77 |
| SaltFarm04dS | 1461 | 28.29 / 20.49 | 15.36 / 11.09 |

The largest observed numerical global step residual is1.74e-11J/cm2 against the
unchanged1e-9J/cm2 guard. Earlier unbuffered Windows calls that hit the selected
cap remain censored, not successful. Buffered compact output is174times smaller
than detailed output in the270-step irrigation discriminator. O0/O2 accounting
reductions show small compiler roundoff on Ubuntu; each separately satisfies the
original energy guard and exact physical/native controls. Their accounting text
is not claimed byte-identical across optimization levels or platforms.

Reproduction uses the existing qualifier, the exact native/control bundles named
by the owning record, and the matching original-object capsule:

```text
python -B research/hybrid-water01/qualify_original_heat_accounting.py --base-archive CAPSULE --workspace PROVIDER --output NEW_OUTPUT --case PROJECT-O2 --current-bundle NATIVE_BUNDLE --control-root COMPLETE_CONTROL --project PROJECT --compact --full-period
python -B research/hybrid-water01/check_original_heat_accounting.py --runs NEW_OUTPUT --compact
```

`PROJECT` is `grass`, `hupsel` or `saltfarm`; select O0 explicitly for its second
cohort. The manual `nomacro-release.yml` heat-export mode reuses the exact
qualified Ubuntu native builds and complete controls instead of recompiling
unaffected physics or rerunning active-macropore projects.

The new codec also has fresh full Grassgrowth1827/Hupsel1096 preservation on
Windows AND Ubuntu26.04 with both kernels: all4/9 seasonal own windows reproduce
the physical suffixes and both payloads exactly. Earlier complete cold ledgers
remain byte-identical on the same platform; no old accepted package was rebound.
The functional acceptance boundary is this named PR/source profile, not a blanket
claim for every no-macro configuration or a completed scientific qualification.

The [complete-trajectory scientific disposition](FULL_TRAJECTORY_SCIENTIFIC_DISPOSITION.md)
reproduces existing full-period comparisons, adds the full Hupsel water/solute/
uptake/crop disposition and identifies the current Andelst clock-scoped numerical
policy. Functional3project coverage and whole scientific equivalence remain separate.

Baseline: canonical `937bd93b58ff913fcf9eafa3825a5da07f951513`, after PR1644.
This is a reconciliation of admitted evidence, not a new model qualification.
Older dated Status-A paragraphs retain their original source/profile claims.

## Complete executions and their distinct model profiles

The application-level completion count is **three original projects**. The shared
hybrid daily host also has complete executions for all three. These counts do not
qualify whole scientific equivalence or turn the hybrid heat profile into the
native accuracy-controlled thermal profile.

| Original project | Complete application evidence | Shared hybrid route and own continuation evidence |
| --- | --- | --- |
| Grassgrowth,1827days | [PR1623](https://github.com/abhedwig-cell/SWAP5/pull/1623), native thermal profile and separate day188 oxygen disposition | [PR1640](https://github.com/abhedwig-cell/SWAP5/pull/1640), original-block1827; own2→4,187→190,365→367,1792→1827 physical receipts and both endpoint payloads exact |
| Andelst,481days | [PR1624](https://github.com/abhedwig-cell/SWAP5/pull/1624), public hybrid481 and source-bound restart/instance/refusal evidence | [Application review](https://github.com/abhedwig-cell/SWAP5/blob/937bd93b58ff913fcf9eafa3825a5da07f951513/research/hybrid-water01/ANDELST_APPLICATION_REVIEW.md); later generic-route controls retain same-platform original continuations; older96-byte cold/restored auxiliary distinction stays explicit |
| Hupsel,1096days | [PR1625](https://github.com/abhedwig-cell/SWAP5/pull/1625), native pressure/film rotation profile and its own source-bound restart/balances | [PR1641](https://github.com/abhedwig-cell/SWAP5/pull/1641), corrected-original-block1096; nine exact own windows including saline gift, rotation, day584 and terminal1096 |

The shared route's Hupsel corrections are explicit: original runoff/pond stock,
CDE endpoint truncation and harvest interception clearing, plus original Newton
convergence/residual polishing under unchanged1e-10 guards. This is not unmodified
SWAP4.3.1 bitwise equivalence. The [generic application description](HYBRID_GENERIC_WATERHOST.md)
and source-bound reviews preserve these distinctions. Native numerical profiles,
the private AndelstV9 research trajectory, and the shared hybrid route must not
be treated as interchangeable reference families.

Full-run evidence is inherited at its **qualified source/build/input boundary**.
Subsequent bounded same-platform O0/O2 controls qualify the affected dependency
changes. No new full run at this page's baseline is implied.

## Qualified bounded original macro-state successor

[PR1653](https://github.com/abhedwig-cell/SWAP5/pull/1653) adds an opt-in original
nonlinear/macropore policy with complete native state inS5MAC006. The original
MACROINTEGRAL local previous-wall array shadowed its checkpointed module name;
the independent cold-zero quadrature history, original reset flags and original
HeadCalc counters are now explicit and persisted. Same-platform Windows/Ubuntu
kernel-O0/O2 cold controls, complete own2to3/4, external discard and cold3to4 are
exact. Windows also reaches22 and reproduces complete own14to16 payloads across
1949 mass-step retries, retaining1e-6cm. The admitted public481 profile and its
historical auxiliary distinction retain their exact original scope. The complete
original481 successor is now executed on the same Ubuntu-O2 build, with exact
year365to368 and late453to459 own physical continuations and selected full native
endpoints. Its maximum daily residual is9.998866333377667e-7cm. Preserved raw
artifacts, exact source/build/input binding and a zero-model Linux reproduction
are in`research/hybrid-water01/ORIGINAL_MACRO_481_20261112.md` and its owner record.
Whole scientific qualification FAILS: day438 groundwater differs by79.5114cm
from original printed output, supported by a large spatial pressure difference
against the retained corrected profile. Mass closure does not approve pressure.
Public/default builders remain unchanged; this is a complete functional opt-in
profile, not scientific equivalence or a runtime-parity claim.

A later bounded same-state observation identifies an actual residual inconsistency
at the final accepted438 step: cached maximum5.80e-12 versus refreshed original
coupled maximum4.3198 under the unchanged1e-6 local criterion. Both observed and
control physical433to438 records and complete raw native endpoints are exact.
This is a research-only fork observation, not a production repair, a qualified
reference or full attribution of the groundwater discrepancy. See
`research/hybrid-water01/ORIGINAL_MACRO_DAY438_20261112.md` and its preserved
artifact/independent zero-model audit. No model-source dependency is changed.

The subsequent fixed-live-state control supports retaining the original local
derivative: eight columns at two perturbation scales show zero off-tridiagonal
response; sequential and saturation-crossing round-trip evaluations are exact.
The cached/fresh residual change is accounted for by the macro exchange change
to8.9e-16. This is one-context evidence, not a pressure repair or full trajectory
attribution. `research/hybrid-water01/MACRO_DIRECTIONAL438_20261112.md` preserves
the actual15.587seconds of observer runs and zero-model independent assessment.
Rejected solver variants remain rejected; actual numerical timestep rollback is
the next independent functional acceptance point.

## What the shared application architecture actually provides

One project-aware daily host owns explicit kernel clocks, pressure stocks,
acceptance/rejection and immutable schema3 day packages. Original Fortran blocks
run in independent worker processes; legacy module globals stay inside their
worker. This is process isolation, not proof that legacy globals are thread-safe.
Restart requires both native and auxiliary payloads and exact project/input/
source/build binding. Refused trials cannot publish an accepted day. Independent
columns, own continuations and publication failures retain their scoped evidence.

[PR1642](https://github.com/abhedwig-cell/SWAP5/pull/1642) admits serial external
daily prepare/discard/accept and durable recovery on **original project forcing**.
Private local acceptance is only a proposal; external accept publishes the caller's
accepted generation. This does not provide forcing override, groundwater feedback,
peer-backend iteration or multiparty atomicity. Existing production groundwater
coupling and thermal-binding contracts have their own separate owners/qualification.

[PR1643](https://github.com/abhedwig-cell/SWAP5/pull/1643) observes actual original
conduction and changing-composition sensible storage on accepted days.
[PR1644](https://github.com/abhedwig-cell/SWAP5/pull/1644) exposes actual same-step
water/root/drain/net-macro/drip carriers. Both are opt-in read-only observation
profiles, not an activated conservative-heat solver. Their17172-step Windows/
Ubuntu proof preserves original physical daily records and complete native state.
Water, conduction, physical energy completeness and scientific equivalence are
separate acceptance questions.

## Reproducible thermal handoff limitation

At this page's pinned baseline, `CoupledDailyColumn.prepare(self)` has no thermal/forcing
argument. Its source constructs the original DailyHost and publishes native state
with the binding `forcing=original-project`. No caller temperature reaches the
original heat equation through that interface. Existing
`mod_fmr_bottom_external_thermal_binding` attaches finite external donor temperature
and provenance to a candidate lineage/sample ordinal; the bottom sensible-energy
owner evaluates those transfers. It does not replace the original temperature
equation or persist a new joint thermal state for this application.

Consequently, adding a wrapper that merely accepts temperature metadata would
not implement a thermal feedback handoff. No such wrapper or speculative model
change is admitted. The original numerical heat route is conduction-only. Current
actual incoming water lacks measured donor temperatures; gas motion and macropore
domain thermal state are unavailable. Local soil endpoints/air observations and
water-content changes cannot silently supply those inputs. A new caller-defined
thermal model would require its explicit physical scope, consumers and joint state/
restart/rollback ownership before model execution could qualify it.

This is a **data/model-interface limitation**, not a newly discovered numerical
bug. No new historical heat run or donor-temperature proxy is selected. Existing
accepted physical state is untouched; no numerical or physical tolerance changes.
The exact inspected source hashes and API signature are retained in
`integration/f-ci/FUNCTIONAL_CLOSURE_CURRENT_20261112.json`.

## Remaining acceptance work

Whole scientific equivalence is not qualified for all three projects. The native
day188/day584 failed comparisons remain failed at their frozen criteria. Hupsel584
original and implicit reference families remain independently underresolved;
another reference is selected only for a distinct, independently verifiable causal
hypothesis. Full physical energy is likewise open, not a reason to invent inputs.

The later [Cauchy water-forcing successor](HYBRID_CAUCHY_DAILY_FORCING.md) supplies
caller-controlled **water** forcing through daily prepare/discard/accept with actual
day20→22 original controls and unchanged mass guard. Original forcing remains the
default. It adds no thermal consumer. The [Grass groundwater successor](HYBRID_GRASS_DAILY_GROUNDWATER.md)
extends the same transaction to original prescribed groundwater, with actual
leading/interior and modified-history recovery controls. Original Hupsel zero flux
retains its semantics. The [Hupsel surface-irrigation successor](HYBRID_HUPSEL_DAILY_IRRIGATION.md)
now supplies actual fixed water/solute events after complete persisted irrigation-
context restoration, with changed-history retry/recovery and independent original-
input physical controls. The [Cauchy changed-history successor](HYBRID_CAUCHY_CHANGED_HISTORY.md)
now proves second-day disk recovery from an actually modified accepted state
and exact both-day independent original controls. Cross-platform sensitivity
and whole scientific equivalence remain separate. The [controlled-instance
composition](HYBRID_CONTROLLED_INSTANCES.md) now verifies interleaved independent
Cauchy/GWL/irrigation owners, pending and accepted state isolation, mixed discard/
accept and cold reconstruction against exact single-instance physical/native
controls. The complete preserved trajectories now have a source-bound scientific
disposition; unresolved reference accuracy, native temporal behavior and the
Andelst research clock-policy remain explicit. The next implementation target is
a justified generic state/process contract for that macro-rate policy, using
retained original-origin evidence rather than another broad reference campaign.

For thermal feedback an explicit corrected-physics scope and joint state/restart
owner remain prerequisites, not an unused handoff wrapper. Reuse the completed full
applications and their qualified dependencies; do not repeat them to refresh status
or to measure historical inputs that are absent.
