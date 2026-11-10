# HYBRID-WATER01 donor day boundary

## SWAP5-FUNCTIONAL-CLOSURE01 workpoint

The consolidation branch is `codex/swap5-functional-closure01`. It starts
from the exact hybrid evidence head `0ca2e3edd7e869d2ac7d37ed6c139ae126fdcc49`
with canonical checked at `7535a9e650aa01ca3ee711353c2e2801e2872f00`.
PR 1619 remains the research baseline.

The shared application command is now
`tools/solute/run_water.py --model HYBRID_ANDELST_WATER`.
Its native driver resolves the explicit model with the existing
F-APP01 selector before any donor starts. The shared day host lives
in `app/hybrid_water`. See the
[application commands](../../docs/getting-started.md#run-the-explicit-hybrid-andelst-application)
and the [application receipt](CLOSURE01_APPLICATION_RESULT_20261109.json).
Both Windows O0 and O2 kernel builds, using the O2 donor, match the
first 22 full-period receipts and CSV rows exactly. Each build resumes
its own day-20 package exactly. The cross-build restart is refused
before model launch. The mixed-clock and column-local refusal controls
also pass through the application driver. Earlier schema-3 packages
require their original build at `3ec721ebf`.

The same command selects the existing Grassgrowth owner with
`--model NATIVE_GRASSGROWTH_WATER`. It checks the original 113-node
project inputs, compiled executable and retained-step thermal profile
before starting the native project. The native owner commits days and
writes its water, heat, crop and root restart using the existing codec.
Both Windows O0 and O2 builds reproduce the first four historical budget
and crop records. Each day-2 restart reproduces days 3Ã¢â‚¬â€œ4 and the terminal
state, endpoint and checkpoint bytes. Damaged and other-build checkpoints
are refused before budget publication. Maximum absolute water residual
is 2.257e-14 cm and maximum absolute heat residual is 2.046e-12 J/cmÃ‚Â².
See the [Grassgrowth commands](../../docs/getting-started.md#run-the-native-grassgrowth-application)
and the [application receipt](CLOSURE01_GRASS_APPLICATION_RESULT_20261109.json).
The prior 1,827-day evidence remains the full-period authority.

The third explicit selection is `--model NATIVE_HUPSEL_ROTATION`.
It uses the existing 34-node joint rotation with the pinned pressure-film
preparation, whose maximum step is 0.01 day. O0 and O2 reproduce the
first four budget and crop days of the existing full-period runs.
Own day-2 restarts match days 3Ã¢â‚¬â€œ4 and the terminal state and checkpoint
bytes. The application verifies the restart receipt before launch, and
the native codec independently rejects a damaged rotation envelope.
See the [Hupsel commands](../../docs/getting-started.md#run-the-native-hupsel-rotation)
and [application receipt](CLOSURE01_HUPSEL_APPLICATION_RESULT_20261109.json).
The earlier 1,096-day runs remain the full-period authority.

The reusable daily host owns the command and reply exchange with one
Fortran worker per column. The SWAP5 kernel owns the accepted clock and
water state. The host can interleave columns at different accepted days.
A kernel refusal preserves that column's accepted time and state and
ends its worker. The remaining columns can still advance.

The runtime donor writes a checkpoint on the requested day, including
after restart. The host publishes the closed ZIP via the native
`swap5_restart_publish` only after kernel acceptance. Schema 3 binds
the accepted hydraulic state, nested source archives, project inputs
and numerical build. The same donor and kernel build handles every cut.
Strict reopening checks the complete binding and both payload hashes
before extraction, then checks the donor's initial stocks and heads.
Earlier schema-1 directories and schema-2 ZIPs remain historical
evidence. Their strict reader is available at the earlier branch
commit `3bb7d21b5fc056383e0e66b77e66584276b03f20`.

The day-19 package and the day-21 package written after resuming day 19
share the same numerical build identity. Both fresh continuations match
all daily receipts and published rows of the continuous control through
day 23, after accounting for the new kernel revision sequence. The
mixed-clock regression starts one cold and one restored column in the
same host and matches their control receipts. Its day-15 refusal control
preserves day 14, publishes no checkpoint and lets the other column
continue exactly. Strict isolation with two different Cauchy trajectories
matches both separate controls. The original 1e-6 cm water tolerance is
used throughout. An O0 SWAP5-kernel build with the O2 donor reproduced
the mixed-clock control. The legacy raw day-2 restart also remained
exact through day 4.

To reproduce on Windows with GNU Fortran and GCC on PATH, use empty
output directories and the original SWAP 4.3.1 distribution.

```powershell
$ref = "$env:TEMP/hy481-local-b0-20261109"
$archive = "$env:USERPROFILE/Downloads/SWAP_4.3.1.zip"
$flags = @('--budget-retry', '--shared-pond-transfer', '--refresh-macro-final')
$runner = 'research/hybrid-water01/run_daily_kernel.py'
if (!(Test-Path $ref)) { python -B $runner --reference-work $ref --prepare-archive $archive }
$short = "$env:TEMP/swap5-closure01-host-v3-a"
python -B $runner --reference-work $ref --output $short --checkpoint-at 19 --days 23 @flags
python -B $runner --reference-work $ref --output "$short-chain" --origin "$short/accepted-column-1-day-19.zip" --origin-day 19 --require-accepted-origin --checkpoint-at 21 --days 23 @flags
python -B $runner --reference-work $ref --output "$short-chain2" --origin "$short-chain/accepted-column-1-day-21.zip" --origin-day 21 --require-accepted-origin --days 23 @flags
python -B $runner --reference-work $ref --output "$short-isolation" --origin "$short/accepted-column-1-day-19.zip" --origin-day 19 --require-accepted-origin --isolation --days 21 @flags
python -B research/hybrid-water01/check_daily_host.py --reference-work $ref --checkpoint "$short/accepted-column-1-day-19.zip" --output "$short-check"
```

```powershell
$full = "$env:TEMP/swap5-closure01-host-v3-full"
python -B $runner --reference-work $ref --output $full --checkpoint-at 365 --days 481 @flags
python -B $runner --reference-work $ref --output "$full-year" --origin "$full/accepted-column-1-day-365.zip" --origin-day 365 --require-accepted-origin --checkpoint-at 453 --days 457 @flags
python -B $runner --reference-work $ref --output "$full-dry" --origin "$full-year/accepted-column-1-day-453.zip" --origin-day 453 --require-accepted-origin --days 459 @flags
```

The fresh original-input run accepted all 481 days and reproduced every
daily receipt and published CSV record from the earlier hybrid run.
Maximum absolute daily water residual was 9.998896e-7 cm and the signed
sum was -3.098486e-5 cm. It took 522 s from donor link to the final
result in the measured Windows run. The balance guard requested 86,521
retries, of which 24,222 occurred on day 404, 22,635 on day 295 and
16,292 on day 66.

The fresh day-365 continuation matches the continuous run through day
457 and publishes its own day-453 package. A second fresh process from
that package matches through day 459, including day 458. The four
published runtime packages at days 19, 21, 365 and 453 have the same
numerical build identity. The [daily host receipt](CLOSURE01_DAILY_HOST_RESULT_20261109.json)
contains the hashes, full-run water totals and controls.

Against the original SWAP 4.3.1 CSV, mean absolute groundwater
difference is 0.20105 cm and the largest is 10.88535 cm on day 457.
The signed cumulative drainage difference is -0.01233 cm and the largest
daily drainage difference is -0.01135 cm on day 258. The canonical V9
receipt reports 481 days with a maximum daily water residual of
4.731912e-12 cm under its own integration and accounting. These are
separate numerical profiles with separate scientific qualification.

The [schema-2 checkpoint receipt](CLOSURE01_DURABLE_CHECKPOINT_RESULT_20261109.json)
preserves the previously published day 20, 256 and 365 controls. Its
[predecessor](CLOSURE01_ACCEPTED_CHECKPOINT_RESULT_20261109.json) records
the same wet and year controls with full daily receipts.

Resume here. [PR 1620](https://github.com/abhedwig-cell/SWAP5/pull/1620)
was admitted to canonical at `78c801253` from the dedicated
`codex/swap5-water-application-integration` branch. The application
postimage is `6f2ba26ea` and the F-CI routing head is `1649abeeb`.
The eleven-file application change has no changed paths in common
with the PR 1619 diff. The donor adapter, source transforms and
balance guard are owned by `app/hybrid_water`. The application
builds and prepares the original Andelst reference without this
research directory. The [local integration receipt](CLOSURE01_INTEGRATION_RESULT_20261109.json)
records the exact PR-head runs. Andelst O0/O2 kernels reproduced days
1Ã¢â‚¬â€œ22 and own day-20 continuations with the O2 donor. Generated donor
sources match the previous application build byte for byte.
Grassgrowth and Hupsel O2 reproduced days 1Ã¢â‚¬â€œ4 and their own day-2
restarts. The exact head also passes the mixed-clock isolation and
day-15 refusal controls.

The F-CI successor checks the exact application source and replays
the complete unmodified native admission in a detached canonical
`7535a9e65` view. The first registration at `5dee184b6` passed the
successor locally and in GitHub modular feedback. It also triggered
historical workflows that explicitly require the earlier source
footprint. The final registration at `1649abeeb` is confined to the
F-CI workflow and restores the historical entry and status files
byte for byte. The exact head passes the local and GitHub F-CI
successor with full historical native preservation. See the
[successor receipt](CLOSURE01_FCI_SUCCESSOR_20261109.json).

All 55 checks on `1649abeeb` are terminal, with 30 successes,
17 skips and eight failures. The DATAQUAL12, Hupsel root-profile,
Grassgrowth thermal and historical native restart source predicates
reject both the pinned canonical base and the application head.
The exact eight failed-job logs were recovered through the GitHub API.
Seven jobs reach the four historical predicates above. The AHL job
fails in the Linux executable-stack loader with unchanged AHL sources.
The [admission evidence](CLOSURE01_CANONICAL_ADJUDICATION_20261110.json)
pins the logs, exact test merge and local O0/O2 evidence. Grassgrowth
and Hupsel each reproduce all four budget, crop and state days across
optimizations and their own day-2 restarts. Fresh reference preparation
also ran the original 481-day donor and reproduced its CSV records.
The fetched canonical merge has the exact qualified tree
`4caf4e27bab50f67d3f157d45d8f6adf19ec1c5c` and the expected two parents.
All 24 post-merge checks are terminal. F-CI modular feedback and the
F-GC fixed-interface closeout pass on `78c801253`. The four failures
reach the historical DATAQUAL12 predicate that also rejects
`7535a9e65`. Sixteen checks are skipped.

The targeted Andelst replays below localize the day-457 groundwater
discrepancy to the final accepted step. Both same-origin controls show
sensitivity to reuse of the macro exchange during that solve.
The read-only O2 replay reproduces the existing accepted-step and solver
traces exactly. At the first clock-refresh-sensitive residual, pressure
heads cross zero in 7 compartments on original day 457 and 29 on
budget-only day 458. On corrected day 457, no compartment crosses either
zero or 1 cm, yet refreshing the rates changes the net exchange by
9.456 cm/day. A saturation-mask change alone misses that event.

The follow-up experiment refreshes the rates once at provisional
convergence and reruns the original compartment, total and pond
convergence checks. All three O2 variants first differ from their controls
on day 454 and time out after 240 seconds, with the last accepted step
reported on day 456. This rules out this general convergence check as
a replacement for the qualified application path. The research replay,
input and build hashes, and exact first differences are in the
[reuse evidence](CLOSURE01_MACRO_REUSE_20261110.json).

Leave the Andelst experimental solver changes in research. The Hupsel
oxygen holdout on day 584 remains reference-limited. The two finest
literal-original grids differ by 2.4784465e-5 cm against the frozen
5.371840000016327e-7 cm criterion. Seven chronology tests pass, while the
historical capsule correctly refuses current-source reuse because the
shared publisher and current admission verifier have changed. No Hupsel
process change is selected from this evidence.

Grassgrowth now publishes a separate conductive day ledger for every
accepted substep. Windows O0/O2 original-input days 1Ã¢â‚¬â€œ4 and each own
day-2 continuation produce identical conductive rows. Water, crop and
terminal state agree with the prior four-day runs. The exact historical
Grassgrowth production tree also revalidates its sealed 1827-day run.
See the [conductive evidence](CLOSURE01_GRASS_CONDUCTIVE_20261110.json).
The production change was integrated through PR #1621. Its first CI head
had ten passing workflows and three failures. The historical thermal
predicate also rejects canonical. F-CI additionally rejected the
changed Grassgrowth owner because its application receipt pins the old
source. The AHL application hit the previously reproduced Linux
executable-stack loader failure.

PR head `bd24e5922e7661b373aa01f6de8f72dd33d5f345` keeps both historical
guards on exact predecessor worktrees and checks the current conductive
rows through the original-input O0/O2 native disk restart test. The
previous guards and retained receipt hashes are untouched. Sixteen workflows
passed, including F-CI, native disk restart and the
full Grassgrowth thermal workflow. The older Grassgrowth sprint
predicate expects 12 production paths and rejects both the base and
candidate with 39. The unrelated AHL shared-library loader error recurs
with unchanged sources. The canonical merge of PR #1621 at
`a57d7d532464ad89b7aca918263cf114b6b42185` has the exact qualified test
tree `bbed43d97a7c33c9a92a4c1a17c8f25ed1738e84`.

The Grassgrowth heat observer recompiled the exact canonical owner with
output-only instrumentation. Original-input O0/O2 day 1 and each own
continuation through day 4 give the same 13,764 selected thermal leaves
and match the earlier uninterrupted water, conductive, crop and final
state output. Moisture changes contribute +31.75347 J/cmÃ‚Â² of sensible
stock relative to 0 Ã‚Â°C. Changing air capacity contributes -0.009207
J/cmÃ‚Â². Positive net water inflow lacks a measured donor temperature
already on the first accepted leaf. The outflow estimates use soil
endpoint temperature. The original SWAP 4.3.1 numerical routine also
uses moisture-averaged capacity in a conduction-only solve. See
[the heat-stock evidence](CLOSURE01_GRASS_HEAT_STOCK_20261110.json).

The original 63-day Grassgrowth thermal replay recovered 1,664 accepted
intervals and the archived B0 profile within 1.78e-15 Ã‚Â°C. The air boundary
matches the daily weather mean. The SWAP5 thermal owner reproduces the
complete original history on its original clock and original moisture
states to 1.78e-14 Ã‚Â°C, with identical O0/O2 results. On day 63, B0 used
27 heat steps and the newer retained native run accepted 771 adaptive
intervals. Halving each original step with fixed averaged coefficients
changes node 27 by -0.003422 Ã‚Â°C. The observed coupled native difference
there is -0.006367 Ã‚Â°C. Interpolating moisture within each split produces
almost the same contrast. See [the clock evidence](CLOSURE01_GRASS_THERMAL_CLOCK_20261110.json).

The first hydraulic comparison reproduces the original initial theta
and net rain and surface flux exactly. The original first step lasts
2e-4 day. Native day 1 first accepts leaves at 7.8125e-5 day with the
water-only profile and 6.103515625e-7 day with thermal control. Each
profile is exact across O0/O2. On the original first endpoint, both
native profiles integrate the same net surface input as the original
to roundoff. Their maximum theta differences are 4.280e-6 and 8.720e-6
respectively, both at node 1, with water residual below 3.17e-15 cm.
Thermal control uses 3065 adaptive intervals over day 1 versus 496
for water-only. See [the startup evidence](CLOSURE01_GRASS_WATER_START_20261110.json).

At the original 2e-4 day interval, the native full candidate matches
B0 within 5.55e-17 in theta and 5.29e-12 cm in pressure head. Its
independently reconstructed water residual is 1.69e-19 cm. The first
observed 4.28e-6 theta difference at node 1 is in the selected two-half
trajectory. Observing both candidates preserves the accepted outputs
byte for byte at O0/O2. See [the full-trial evidence](CLOSURE01_GRASS_FULL_TRIAL_20261110.json).

The first Grassgrowth discrepancy is temporal discretization. The
retained full runs also expose a separate output phase error. At mowing,
the daily CSV mixed the opening canopy LAI with the closing biomass.
PR #1622 derives completed-day LAI from the committed crop candidate.
On original day 127 the corrected output is 0.838599986228, matching
the checkpoint and original reference. The O2 original run through
day 128 and own day-126 continuation agree exactly. Water budgets,
non-LAI crop fields and the day-126 physical checkpoint match the
retained water-only run. Windows O0/O2 own day-1 disk controls also pass.
See [the mowing evidence](CLOSURE01_GRASS_COMMITTED_LAI_20261110.json).
PR #1622 merged as `a8275101d91f0ab5b413290e9b00bb5666b11917` with the
exact qualified tree `5ad8502ba67c1c53e77a7c5128a71504c050fade`. Eleven
workflows passed, including F-CI and the Grassgrowth thermal workflow.
The sole failure is the inherited Linux AHL executable-stack loader.

Grassgrowth day 188 (1980-07-06) now has an accepted-step comparison
against the original SWAP 4.3.1 B0 nodal run. The O2 native observer
resumed from day 187 and reproduced the retained day-188 budget row and
checkpoint byte for byte. The B0 observer reproduced the archived
potential demand, uptake, drought and oxygen integrals within
`1e-10 cm`. B1 and B0 oxygen totals agree to `4e-12 cm`.
The native trace contains 1,660 integration intervals for 830 reported
accepted steps. B0 has 31 accepted intervals. See
[the measured values and hashes](grass-oxygen188-evidence.json).

| Day 188 | SWAP5 O2 | SWAP 4.3.1 B0 |
| --- | ---: | ---: |
| Root depth (cm) | 30 | 30 |
| Potential transpiration (cm) | 0.142419606217 | 0.141707391074 |
| Actual root uptake (cm) | 0.136425380548 | 0.125136344464 |
| Drought reduction (cm) | 0 | 0 |
| Oxygen reduction (cm) | 0.005994225669 | 0.016571046610 |
| First positive oxygen reduction (minutes after midnight) | 68.30 | 38.40 |
| Peak oxygen reduction rate (cm/day) | 0.095676929 | 0.141707391 |

At the largest overlap gap around minute 76.8, the deepest-root
oxygen factor is 0.272334 in SWAP5 and zero in B0. At the two
accepted interval starts the largest differences in head and water
content are both at node 6. Head is -56.70 versus -95.09 cm and
water content is 0.35300 versus 0.31618. The largest temperature
difference across nodes is 0.027 Â°C. These values come from the two
actual step starts, about 0.41 seconds apart. The native trace exposes
pressure head, water content, temperature and actual nodal sinks.
The potential nodal sink and full nodal oxygen factors were
unavailable as a pair across the two observers.

Decomposing the oxygen integral on overlapping intervals gives
+0.000056631 cm from potential demand and -0.010633452 cm from
oxygen reduction as a fraction of demand, for a net SWAP5-minus-B0
gap of -0.010576821 cm. This is an accounting decomposition. The
scientific cause of the fraction difference remains open. The native
water balance residual is -6.72e-15 cm. The observer is diagnostic and
the model tolerances were retained.

The paired oxygen replay now calls the original B0 `OxygenStress`
and the retained SWAP5 Bartholomeus reference provider on each of
the same pressure-head, water-content and temperature profiles.
Both receive the same B0 hydraulic and soil parameters, atmospheric
boundary, 30-node root-density profile and respiration inputs. The
B0 forcing and nodal potential demand stay constant across the
observed window. The diagnostic relink preserves the complete
accepted B0 trace exactly and reconstructs its oxygen rates within
the existing `1e-10 cm` audit threshold when integrated over each
step. Model tolerances are unchanged.

| Shared accepted profile source | Intervals | First reduction in both kernels (min) | Max absolute nodal factor difference | Integrated SWAP5-minus-B0 loss (cm) |
| --- | ---: | ---: | ---: | ---: |
| B0 | 29 | 38.4000 | 8.5843e-6 | -3.0321e-9 |
| SWAP5 | 1267 | 68.4368 | 1.3076e-5 | -2.8323e-9 |

The integral uses the same B0 nodal demand on both grids, beginning
at minute 38.4. Under that common forcing, changing only the
accepted soil profiles and their step grid reduces the oxygen loss
from 0.01657105 to 0.00593386 cm. The kernel-only difference is
about 3e-9 cm, compared with the 0.01057682 cm gap between the
original daily runs. The actual SWAP5 run first reduces uptake at
minute 68.2996. On that same profile both kernels return a deepest
factor of 1 under B0 forcing, whereas the retained SWAP5 factor is
0.9941774. This comparison holds the nonstate inputs at B0 values
and leaves the smaller difference from SWAP5's own inputs open.

A hydraulic replay then reproduced both accepted control traces
exactly and the SWAP5 endpoint byte for byte. Both routes deliver
1.06 cm gross rain over the first 144 minutes. At minute 38.4
their cumulative net rain differs by 0.000183 cm and downward top
flux by 0.000158 cm. The SWAP5 root zone starts the day with
0.011934 cm less water in the top 30 cm. At minute 38.4 the
accepted surface-node heads are -16.41 cm in B0 and -35.69 cm
in SWAP5, despite the close cumulative input.

To distinguish inherited state and rain delivery from temporal
resolution, cap B0 at 30 seconds only during day 188, before the
first root and hydraulic step. The original B0 endpoint from day
187 and all model tolerances are retained. The capped B0 and
uncapped B0 start with identical full nodal head, water content
and temperature. Their first 144 minutes have the same cumulative
downward top flux to within 4e-9 cm.

| Route | Day-188 integration intervals | First oxygen reduction (minutes) | Day oxygen loss (cm) | Surface head near minute 38.4 (cm) |
| --- | ---: | ---: | ---: | ---: |
| Original B0 | 31 | 38.4 | 0.016571046610 | -16.4128 |
| B0 capped at 30 s | 2880 | 67.5 | 0.006220881579 | -35.4089 |
| SWAP5 O2 | 1660 | 68.3 | 0.005994225669 | -35.6898 |

The day-188 B0 cap removes 97.86% of the original oxygen-loss
gap, leaving 0.000226656 cm. This identifies sensitivity to the
original accepted time grid at this event. The capped run is a
diagnostic variant, and the original B0 remains the historical
reference. The values, profile samples and hashes are in the
[hydraulic receipt](grass-wetting188-evidence.json).

[Grassgrowth PR 1623](https://github.com/abhedwig-cell/SWAP5/pull/1623)
is ready for review at `168e1ebc1`. The fresh canonical thermal O2 run
completed 1827 days, and the fresh day-1791 process exactly reproduces
days 1792-1827 and the terminal checkpoint, state and endpoint. All
daily water, uptake and conductive checks pass with existing bounds.
The source, original inputs and build are bound in the archived evidence.
The diagnostic water-only day-188 attribution stays separate from the
current thermal run and the literal B0 scientific comparison.

The Andelst integration review now uses
`audit_andelst_application_replay.py`. It reverified the retained
481-day ledger and both checkpoint payload hashes against the
published daily-host receipt. The 365-to-457 and 453-to-459
continuations reproduce the accepted physical receipts and every
published CSV row. The two distinct Cauchy columns match their own
separate controls, and the retained refusal leaves revision 14,
publishes no day-15 file and permits the other column to accept day 2.
The older exact post-refusal state comparison remains in the
dedicated host control.

The fresh canonical application chain completed at `a8275101`.
The continuous 481-day ledger matches the retained ledger byte for
byte. All 482 dated CSV rows also match. The new 365-to-457 and
453-to-459 continuations are exact. The new schema-3 checkpoint
payloads match the retained payload hashes. [Draft PR
1624](https://github.com/abhedwig-cell/SWAP5/pull/1624) contains the
current receipt, replay auditor and archived results.

The current original-input Hupsel application has completed all
1096 days. [PR 1625](https://github.com/abhedwig-cell/SWAP5/pull/1625)
contains the exact pressure/film physical CSV comparison, independent
water and solute closure, terminal heat result and exact own-build
O2 day-2-to-4 restart. The older full-profile capsule uses another
numerical route and first differs on day 524. The pressure/film
scientific comparison still fails the frozen day-584 oxygen bound
(0.000244679662 cm absolute difference; 5.37184e-7 cm bound).
That is the remaining scientific acceptance decision for this packet.

PR 1625 now includes both current O0/O2 exact own day-2
continuations and the current O2 year restart, whose physical
budget matches days 366-367 of the full run exactly. Its extracted
archive reproduces the extended receipt. The Grassgrowth full run
and terminal restart are complete in PR 1623.

Hupsel PR 1625 is ready for review at `8768f3f57`. The original
and implicit reference audits were rerun against their bound
evidence. The original finest strict-grid pair still changes
oxygen by 2.47646e-5 cm on day 584. The distinct implicit
conductivity family changes by 4.926112e-6 cm on that same day.
These are 46.1 and 9.17 times the frozen 5.37184e-7 cm comparison
bound. The implicit source guard refuses the current tree and
passes at its admission checkout `eef0c31e`. Both families fail
the accuracy requirement, so the original comparison remains
failed and reference-limited. No native physical correction
is warranted by these measurements.

The next scientific work block needs a distinctly justified
independent reference method and a feasible validation design at
the frozen bound, with original forcing and genuine same-profile
histories. The existing composed cap tests and same-state tests
already exclude repeating those bounded experiments as a remedy.
If no method can be independently validated, record the reference
blocker and choose an independent functional acceptance item.
Review the three application PRs without extending their evidence
scope to whole-project scientific equivalence.

Andelst PR 1624 is ready for review at `a4bab2cf`. Its new
current-source tests cover two distinct Cauchy trajectories, six
interleaved cold/restored receipts and the day-15 refusal. The
refusal preserves the day-14 clock and stocks and allows the
other column to continue exactly. The day-19 package has the
same numerical binding as the full run. The expanded evidence
archive reproduces the full receipt after extraction.

All three application evidence heads have an inherited F-CI110
failure in `ahl-application`, before the model test. The Linux
loader refuses the shared library because it requires an executable
stack. The linker identifies `mod_bartholomeus_response.o`, whose
respiration solve passes a host-associated internal callback to
the scalar bracket. The failure is visible on jobs 129798653897,
129755163198 and 129800407780. A separate engineering acceptance
block can remove the callback trampoline with explicit per-call
state while preserving the bracket evaluation order and outputs.
Require the original O0/O2 oxygen controls and the exact Linux
AHL job to pass before treating that blocker as resolved.

The separate Linux stack repair is in
[PR #1626](https://github.com/abhedwig-cell/SWAP5/pull/1626)
at `1354f5cad9a4db106db50e4e5d8d6a6ba141bca3`.
The Bartholomeus residual and the HBOT5/Cauchy-3 proposal callbacks
now use per-call state. The original oxygen probe has identical
O0/O2 output against canonical. All eleven F-CI110 jobs pass,
including the unchanged [Linux AHL application test](https://github.com/abhedwig-cell/SWAP5/actions/runs/42811507208/job/129813812905)
at merge ref `cc4ccd83045450f997166db9d6bb2b10896e86b4`. This
verifies the stack repair on its own PR. The published application
evidence remains tied to the sources and builds used in those runs.
Before integration, review the broader source-identity gate failures
on #1626 and repeat the application CI against the integrated source.

The independent functional acceptance item is Linux AHL integration.
At exact canonical `a8275101d`, the same DATAQUAL12 predicate reached
through SWAP5-PERF01 already rejects 700 changed paths against its
13-path historical record. The AHL candidate has 705. P2E06 also
already rejects canonical because the Reference tree differs from
its pinned P2E05 tree. The Reference tree is identical on canonical
and the AHL candidate. The predicate comparisons are recorded in
PR 1626 alongside the two passing Linux workflows. The next
integration step is to attribute the remaining red jobs against
canonical and identify any candidate-specific gate before admission.
For Hupsel day 584 the reference blocker above remains open. A
new comparison needs an independently validated reference with
its numerical uncertainty below the existing bound.

The PR 1626 review now covers 46 failing jobs across the 36 failed
workflows returned for the tested head. Of those, 29 signatures match
versioned predecessor logs. RossFast F-CI67P refuses the frozen runtime
blob on both current trees. Its unchanged test fixture compiled with
the current module closure gives identical O0 and O2 output for
canonical and the candidate (normalized SHA-256
`d348bf914e82d5b649c20329a81197528d9b8e3a92efed782d120cb5bc1aa0ba`).
The current F-CI and Grassgrowth thermal workflows reach their historical
fallback because the six AHL production files exceed the Grassgrowth
successor's exact source scope. Both stop before current runtime proof.
The next integration block is a bounded successor that retains exact
predecessor replay and runs current runtime controls. Separately, use
paired Ubuntu 26.04 builds to attribute the F-GC44 derivative output
difference and the anchored-Cauchy contact timeouts before admitting
the shared runtime change. The same F-GC44 command already passes at the
candidate merge ref on Ubuntu 24.04. See the PR for job identities.
This review adds no model changes and retains all prior test verdicts.

The same-runner comparison requested for PR 1626 is complete.
The Ubuntu 26.04 image `20261101.186.1` with GNU Fortran 15.2.0
reproduces the identical F-GC44 O0/O2 derivative output difference on
canonical and the AHL candidate. For Cauchy contact, both O0 builds
reach the unchanged 90-second limit at contact-0. Both O2 builds
refuse both contact variants in macro initialization with
`source rapid reference`, before the required rollback snapshots.
See [FMR](https://github.com/abhedwig-cell/SWAP5/actions/runs/42818169920/job/129836513151)
and the [Cauchy job pair](https://github.com/abhedwig-cell/SWAP5/actions/runs/42819115007).

On Ubuntu 24.04 the [current Grassgrowth controls](https://github.com/abhedwig-cell/SWAP5/actions/runs/42818169920/job/129836512898)
pass runtime, original-input and own disk restart at O0 and O2. The
same job passes the Andelst cold prefix and restart/codec controls.
[Current F-CI](https://github.com/abhedwig-cell/SWAP5/actions/runs/42818169920/job/129836513125)
passes the selector and exact predecessor replay. Its automatic
selection still requires a shared-runtime owner decision. The six
selected current component probes pass locally at O0 and O2.
The next AHL integration decision is the bounded current-source
admission scope. Keep the FMR exact-output and Cauchy contact
failures visible as independent baseline findings.

PR 1626 now contains the exact-source F-CI and Grassgrowth CI route
at `a4da56a0c60105862fc3dc91b6101ff1c963cf84`. It keeps the historical
application and thermal authorities at their frozen commits and runs
current component, selector, original-input and restart controls.
The temporary paired workflow is removed from the PR diff, with its
published logs retained. Model and test trees equal `1354f5cad`.
Follow [F-CI](https://github.com/abhedwig-cell/SWAP5/actions/runs/42822647211),
[Grassgrowth](https://github.com/abhedwig-cell/SWAP5/actions/runs/42822647267),
[F-CI110](https://github.com/abhedwig-cell/SWAP5/actions/runs/42822647049)
and [AHL50](https://github.com/abhedwig-cell/SWAP5/actions/runs/42822647194)
through terminal status before another build or admission claim.
The isolated Windows import of the sealed Cauchy `macro.nml` at
O0 and O2 matches the stored rapid-drain coefficient exactly.
The full Linux O2 initialization refusal remains unresolved and
separate from the scoped AHL portability decision.

The four regular jobs above passed at `a4da56a0c`. F-CI ran the
frozen application predecessor, six current Linux O0/O2 component
cases and the current selector. Grassgrowth ran the current original
input and disk restarts and the Andelst macro codec controls. F-CI110
passed all eleven jobs and AHL50 all seven. PR 1626 is ready for
review. The wider snapshot has 29 green and 34 red workflows, with
no new failing workflow name against the preceding same-source run.
The exact-output and contact baseline failures remain visible.
The application evidence PRs are research-only. In Andelst PR 1624
the build identity binds the changed canonical interval and kernel
modules, so the prior full-run receipt stays tied to its own build.
The next work block tests the current candidate with a cold 22-day
public prefix and an own day-20 restart before using the changed
dependency surface for a fresh full execution.

The current Andelst revalidation is published in PR 1624 at
`51c0b981b`. The production source is `a4da56a0c`. The complete
481-day ledger and 482 dated CSV records match the previous canonical
run exactly. The own-build year and dry-window restarts, O0/O2 day-20
restarts, cross-build refusal, alternating Cauchy columns and day-15
rollback pass. The successor receipt binds the original inputs and
current builds. The earlier archive and science finding retain their
original scope.

The same changed production source enters all six Hupsel build
dependencies. The current O2 prefix to day 4 matches all six physical
CSV files from the earlier canonical control. The day-2 restart
matches its budget and five terminal files. Its receipt is staged
locally at `$env:TEMP/s5-hupsel-a4da56a0-prefix-proof.json`.
The fresh full Hupsel and year-chain runs use the same bundle under
`$env:TEMP/s5-hupsel-a4da56a0-O2-current` with suffixes `-full`,
`-cut365` and `-resume367`. The build and inputs are pinned by the
existing launcher. The next Hupsel acceptance is the full ledger,
year restart and unchanged day-584 scientific classification.

The Grassgrowth O2 registered-profile build and full 1-1827 run use
`$env:TEMP/s5-grass-a4da56a0-O2` with suffix `-full`. A watcher
captures an atomic checkpoint between days 1791 and 1800 and runs
its fresh terminal continuation in `-late-resume`. Use its verified
day and hash from `-late-origin/ORIGIN.json`. Compare these current
runs to the published application receipts before updating PRs 1623
and 1625. Resume the existing processes or audit their output before
starting any new copy.

The fresh Hupsel full execution and restart checks are now published
in PR 1625 at `a6c9fe635`. The O2 run reaches 1096 days and all six
physical CSVs match canonical exactly. The two own day-2 O0/O2
restarts match five terminal files. The O2 year continuation matches
its own full physical budget. The day-584 oxygen result is exactly
0.0033488614852679407 cm. This preserves the failed frozen science
comparison as a separate reference-resolution finding.
The Grassgrowth successor is still running. Its water, crop and
conductive ledgers match through day 188. Monitor the existing
`s5-grass-a4da56a0-O2-full` output and its late-origin and late-resume
siblings. On completion, audit the full ledgers, balances and
late restart, publish the source-bound proof in PR 1623, then check
review disposition and canonical postimages. Do not launch a
second Grassgrowth run while this one is still making progress.

A fresh Grassgrowth process resumed the atomic day-245 checkpoint
while the main O2 run continued. Days 246-247 matched all three main-run
ledgers exactly with the existing balance checks. The origin SHA-256
is `7f3710632bfe7f493c0b36e256b4cf9c2c553a8703f54b7e60f9c29c0ea92bc7`.
The source is `a4da56a0c` and the build manifest SHA-256 is
`712f0c8676fede8102018d8ccc439d53b1283b9ab971819aff7e4fe1ab0b1253`. The live origin, replay and
JSON proof are in the same temporary workspace with suffixes
`-live-origin`, `-live-resume` and `-live-proof.json`. The main run
and the late terminal restart remain the next delivery to PR 1623.

### Grassgrowth runtime reconciliation

The sealed B0 log reports 7.7611 s for the 1827-day reference. The
same Windows host running the verified local B0 with the five original
Grassgrowth inputs reports 8.21875 s, 1828 dated rows including the
initial state, and normal completion. This is an end-to-end model
comparison with different numerical policies. The earlier matched
[50-cell Richards benchmark](../../docs/performance/PERF01_CURRENT_431_20261023_RESULT.md)
found 6-30% higher SWAP5 solver CPU in its short O2 cases and about 4%
lower in its year case. It excludes the crop and time controller.
The much faster [97-day flux metric](../../benchmarks/performance/PERF01_COMPLETE_20261024_RESULT.md)
changes the accuracy measure and has a different admission scope.

The registered [Grassgrowth profile](../../docs/science/GRASS_THERMAL_PRODUCTION.md)
keeps both the water tolerance and the 1e-5 C thermal full/half gate.
On the current source a paired four-day checked O2 run took 20.95 s
and 6882 accepted steps with the profile. The water-only control took
4.67 s and 1163 steps with the same linked object code and inputs.
Terminal water stocks differ by 0.00039249 cm. The thermal run made
7399 attempts with 517 temporal rejections and zero solver or balance
rejections. Rejected retries alone therefore cannot explain the cost.

A scratch replay with unchanged ledgers timed 15.38 s in oxygen,
5.69 s in Richards and 0.17 s in the heat solve out of 23.69 s.
The first 22000 oxygen calls spent 11.15 s in waterfilm and 0.93 s
in response assembly and solve, with zero no-stress gate hits in this
window. [PERF01](../../docs/audits/PPA_WU05C3A_PERF01_RESULT.md) already
reuses trapezoid refinements. The [PERF02 bound](../../docs/audits/PPA_WU05C3A_PERF02_INTERIM_RESULT.md)
is present in current canonical, and its synthetic speedup does not
apply to this measured wet window. A scratch residual-coefficient
preparation trial passed byte-exact O0/O2 oxygen and five four-day
physical files but did not speed up the paired run (22.15 vs 21.61 s
median). The existing production compiler profile gave exact short
outputs and about 10% lower median wall time in two alternating pairs
(21.81 vs 24.13 s). Neither result supports a production change.

The next performance discriminator is to measure exact duplicate
waterfilm inputs across the full/first-half siblings and retries.
Only pursue per-trial reuse if it gives a material saving with the
unchanged quadrature, complete input identity, exact outputs and
existing rollback, restart and isolation controls. Do not repeat the
trapezoid or no-stress experiments and do not weaken the thermal gate.
Use bounded owner feedback for development and preserve full proof
for an affected release dependency surface. The running full Grassgrowth
verification is independent of these scratch measurements.

The historical [oxygen analysis](../../docs/audits/PPA_WU05C3R_BARTHOLOMEUS_RECONSTRUCTION.md)
already removed a duplicate QROMBD integration experimentally and
observed about 95% no-stress outcomes in the old Grassgrowth case.
The original Grassgrowth sets SWKIMPL=0. The conditional legacy
Newton-loop call to RootExtraction(2) is not active there. WFT300
remains a separate numerical option without current admission.

The bounded SWAP5 four-day diagnostic observes 7367 exact consecutive
waterfilm-profile repeats in 22100 calls. The source candidate
`589c1d27536d2daf89c921f1bcabc780aec882bc` limits bit-exact memoization
to one FMR trial, with no checkpoint field or quadrature/tolerance change.
In two alternating checked O2 pairs, median native wall time is
21.17 s before and 18.30 s with trial reuse (13.5% lower). All five
physical output files match exactly, as do O0/O2 assembled oxygen
outputs and the own day-2-to-4 restart ledgers and terminal files.
The candidate remains on its own branch above PR 1626. There is no
production admission or full-period performance claim.

The desired comparison remains full-project runtime on the same host
at comparable verified accuracy. Small exact-preserving savings are
useful but cannot close that gap alone. Earlier matched kernels and
[97-day weather/crop timing](../../docs/performance/PERF01_NATIVE_431_WEATHER_20261023_RESULT.md)
already isolate extra accepted and speculative work as major drivers
in their scopes. [EMBEDSTEP](../../docs/performance/F-PE-EMBEDSTEP_CLOSEOUT.md)
rules out recycling its static selective-control experiments. Use
bounded representative development runs before selecting another
complete experiment. Keep the existing full Grassgrowth verification
on its original source and run no duplicate for this performance probe.

All three full applications on the AHL production candidate
`a4da56a0c` now have published successor receipts. Grassgrowth
PR 1623 at `3941df231` accepts 1827 days and 1819203 steps. The
three ledgers, state and endpoint bytes match the previous canonical
run. The own day-1792 checkpoint reproduces all terminal files
and the day-245 replay matches days 246-247. Recomputing the sealed
B0 comparison yields the unchanged science result. The full launcher
observation is about 100 minutes and the performance criterion is open.
Andelst PR 1624 and Hupsel PR 1625 retain the separately qualified
current execution and restart scopes above. PR 1626 links the three
successor receipts. The next functional admission step is review and
actual canonical postimage verification, with the known red gates
visible. Start no duplicate full application run on this source.
The separate short waterfilm candidate does not replace these receipts.

The unpublished integration preview from canonical `a8275101d`
merges the exact PR heads in order 1626, 1623, 1624, 1625 without
conflicts. The resulting tree is
`505af0cb8de79c6fafe58003556705a531c7b6e7`. The three evidence
merges leave src, app, tools, tests, reference and workflow files
identical to the tested PR 1626 tree
`b8fdd418beb68a0b2d711f469804c74be85d0ff5`. The preview contains
the three successor receipts bound to `a4da56a0c`. The four
intermediate tree IDs in order are `b8fdd418b`, `903e57ee8`,
`79110d7aa` and `505af0cb8`. This is a local Git merge-tree check.
Canonical remains at `a8275101d`. At Grassgrowth evidence head
`3941df231`, nine workflows pass and the sole failure remains the
[AHL loader on the older model tree](https://github.com/abhedwig-cell/SWAP5/actions/runs/42845560399/job/129931957310).
The next condition is the PR 1626 review/admission decision.
The actual canonical tree must then be checked before accepting
the prospective tree or declaring integration complete.

### PR 1626 historical guard comparison

Evaluated the versioned source predicates on canonical `a8275101d91f0ab5b413290e9b00bb5666b11917` and PR head `a4da56a0c60105862fc3dc91b6101ff1c963cf84`. This comparison uses Git objects and requires no model execution.

| Guard | Canonical | PR head |
| --- | --- | --- |
| F-VQ87, first path outside the allowlist in the diff from `43c9f091` | `.gitattributes` | `.gitattributes` |
| PUB-ME D4, changed paths in `git diff --name-only 6a77678b...HEAD -- src reference` | 518 | 519 |
| F-CI59P, changed paths in `git diff --name-only 648c3a2a..HEAD -- src reference` | 593 | 593 |
| PUB-GC E7, bootstrap blob pinned to `356b3825a8ba13af1fed385ab17ffdb330b1058f` | `2f42e0ee89cd0285f05a1bb1553f1bd7789061bd` | same |

These four first rejections predate the repair. E7 also pins the serialized
backend, whose blob does change in this PR. This comparison establishes the
first rejection only. It does not qualify the historical E7 experiment on the
current backend or authorize a merge. Next review decision is the disposition
of inherited historical guards alongside the scoped AHL evidence.

### GitHub merge candidates for the four review packets

GitHub's merge ref for PR 1626 is `05c43aa4c3055f71fc631d92b202a885d1eec168`. Its parents are the live canonical `a8275101d` and the tested PR head `a4da56a0c`. The full tree is byte-identical to the tested head (`b8fdd418beb68a0b2d711f469804c74be85d0ff5`).

| Evidence PR | GitHub merge ref at the same base | Candidate tree |
| --- | --- | --- |
| 1623 Grassgrowth | `4fe82832fe216e3628d5a07454aefa536fb80cbb` | `cafc122dac9d0c07bb7a15f259bf14704f5f23aa` |
| 1624 Andelst | `5fb925ab4787bccd7c37abef774c77ef60c1db7b` | `5f818a6b1b34338944773aee50caefab72e2bda5` |
| 1625 Hupsel | `c39f687ee39a4126661f130342d3d29a03b83491` | `6e0e74d1e2df0de8152b6e4ddafbd709988b3d02` |

All three evidence candidates change only the research directory. Check the
parent and tree again after each admission, using the combined-tree preview
above for the intended 1626 → 1623 → 1624 → 1625 order. GitHub reports all
four PRs open and unstable. The hosted merge refs confirm composition and
source identity, while disposition of the red checks on 1626 remains open.

### Independent file verification of the AHL application receipts

Re-read the receipts from exact PR heads `3941df23`, `51c0b981` and
`a6c9fe63`. All three name the production source `a4da56a0c`.
Rehashed the retained Windows outputs without rerunning the models.

- Grassgrowth: all six full-run outputs and five original inputs match.
  Each of the three ledgers has 1827 rows. All six output hashes match
  at each retained continuation, day 245 to 247 and day 1792 to 1827.
- Andelst: the two executables and the 481-line daily ledger match.
  The 482 dated output records match when joined with LF and a final LF.
  The SWAP-generated report header is excluded from this recorded digest.
  At each restart, 365 to 457 and 453 to 459, the resumed daily ledger
  and both verified-origin payloads match their published hashes.
  The staged `original/swap.swp` is an execution copy. This check did not
  rehash the original input archive.
- Hupsel: all eight full-run outputs and seven input files match.
  The budget contains 1097 records for 1096 model days. All eight
  retained outputs match for each O0/O2 day-2 restart and the O2 year restart.

This verifies the retained bytes against the published receipts. It does
not requalify the historical oxygen comparisons or the unresolved Linux
Cauchy contact initialization.

### Andelst original archive and Linux contact boundary

The original `SWAP_4.3.1.zip` SHA-256 is
`76a79498423ee612a7861efb564b10c4360a4f648396eefcf8e9011919a66039`.
Direct ZIP-entry hashing matches all 14 Andelst inputs and both source
archives in the exact PR 1624 successor receipt. This closes the
archive-input gap in the preceding retained-file audit.

For Linux contact O2, the first refusal is the `source rapid reference`
guard in `app/solute_column/read_swp_macro_initial.f90`, immediately after
`prepare_rapid_drain_reference_kd` and before typed state initialization.
It accepts only a successful derivation with absolute difference at most
1e-12. Both the reader directory and the macropore process directory are
byte-identical between the canonical base and the AHL PR. The paired Linux
logs do not distinguish an unsuccessful derivation from a numerical
mismatch. If investigated further, compile only the macro reader and its
dependencies with GNU Fortran 15.2 on Ubuntu 26.04. Log the success flag,
derived coefficient and sealed coefficient on the existing contact input
before running any time integration. The local host has Windows GNU
Fortran and no WSL installation.

The standalone [contact import replay](replay_contact_macro_import.py)
compiles seven source files and a one-call driver. It extracts the sealed
`run/macro.nml` (SHA-256
`674a1c12564322e15eccf9c6301fcfa9043a0432e677dc8089d9923b2e4b66cc`)
from the selected Git commit and prints the success flag, calculated
and sealed coefficients, and signed difference before the unchanged guard.
On Windows GNU Fortran 16.2 both O0 and O2 return true and
`0.878598015369454255` for both coefficients, with zero difference.
The same script is ready for GNU Fortran 15.2 on Ubuntu 26.04.

```sh
python research/hybrid-water01/replay_contact_macro_import.py --fc gfortran
```

On [Ubuntu 26.04 with GNU Fortran 15.2.0](https://github.com/abhedwig-cell/SWAP5/actions/runs/42849523028/job/129946009456)
the seven-file replay reproduces the refusal with the same sealed input.
O0 returns true and an exact coefficient. O2 returns false and leaves the
coefficient at zero before `source rapid reference`. This is a failure
inside `prepare_rapid_drain_reference_kd`, not a small difference across
the reader tolerance. The next discriminator is the first rejecting
predicate in that routine, using the same isolated driver. No Richards
step, contact rollback or full application was needed to reproduce it.

The [guard trace](https://github.com/abhedwig-cell/SWAP5/actions/runs/42849799320/job/129947011901)
locates the first refusal at `local_ok` after node shrinkage evaluation.
The [KIM trace](https://github.com/abhedwig-cell/SWAP5/actions/runs/42849979505/job/129947666007)
shows `theta == theta_s == 0.525` and a calculated shrink fraction of
`-3.21380349233597712e-18`. This is the wet linear branch, where the
exact result at saturation is zero.

An [isolated trial](https://github.com/abhedwig-cell/SWAP5/actions/runs/42850115845/job/129948155606)
returns zero explicitly only at exact saturation on that branch.
Both Ubuntu O0 and O2 complete import with the unchanged 1e-12 cm
coefficient check. O0 matches the sealed coefficient exactly. O2
differs by `-6.66133814775093924e-16`. The candidate is an overlay
on diagnostic branch `7335cf5b0`. Next gate is a separate production
change with KIM regression coverage and the bounded contact restart
and rollback check. The isolated result does not resolve the
independent O0 contact timeout.

### AHL stable-candidate admission decision

The exact PR 1626 [F-CI preflight](https://github.com/abhedwig-cell/SWAP5/actions/runs/42822647211/job/129851783016)
reports `BLOCKED_OWNER_SELECTION` even though the workflow job is green.
Its output is an impact report. The companion modular feedback job and
the AHL/F-CI110, current Grassgrowth and external MODFLOW coupling jobs
passed on the exact candidate. The current restricted canonical
preservation job is skipped in the automatic F-CI run.

The repository's
[proportional execution rules](../../docs/development/workstream-execution-protocol.md#expensive-tests-are-explicitly-selected)
and AGENTS.md separate automatic feedback from stable-candidate
admission. The shared-runtime admission owner must record the selected
preservation scope for `a4da56a0c` on `a8275101d`, including whether the
full moving F-CI group is required. If required, dispatch the existing
workflow once with the versioned owner selection record. The automatic
workflow and the unrelated historical publication failures do not supply
that decision. Reverify the live base and exact PR head before admission.
The Andelst KIM/contact diagnosis is separately tracked in PR 1627.

The completed Andelst chain used these commands.

```powershell
$b = "$env:TEMP/s5-andelst-canonical-a827-review"
$ref = "$env:TEMP/hy481-local-b0-20261109"
$common = @('--model','HYBRID_ANDELST_WATER','--reference-work',$ref)
python -B tools/solute/run_water.py @common --output $b --days 481 --checkpoint-at 365
python -B tools/solute/run_water.py @common --output "$b-year" --days 457 --restart "$b/accepted-column-1-day-365.zip" --restart-day 365 --checkpoint-at 453
python -B tools/solute/run_water.py @common --output "$b-dry" --days 459 --restart "$b-year/accepted-column-1-day-453.zip" --restart-day 453
python -B research/hybrid-water01/audit_andelst_application_replay.py $b "$b-year" "$b-dry"
```

Replay in PowerShell with the retained O2 build and checkpoint
directories from the preceding workpoint. The output directory must
be new. The observer relinks the retained objects and uses the
original application binding for the diagnostic resume.

```powershell
python -B research/hybrid-water01/replay_grass_oxygen188.py --reference "$env:TEMP/hy481-local-b0-20261109" --bundle "$env:TEMP/s5-grass-lai-O2" --control "$env:TEMP/s5-grass-oxygen-event-189" --archive "$env:TEMP/s5-grass-heat-obs-O2/libttutil.a" --output "$env:TEMP/s5-grass-oxygen188-observe-v3"
python -B research/hybrid-water01/audit_grass_oxygen188.py "$env:TEMP/s5-grass-oxygen188-observe-v3" "$env:TEMP/s5-grass-oxygen-event-189"
python -B research/hybrid-water01/compare_grass_oxygen188.py --reference "$env:TEMP/hy481-local-b0-20261109" --bundle "$env:TEMP/s5-grass-lai-O2" --observation "$env:TEMP/s5-grass-oxygen188-observe-v3" --output "$env:TEMP/s5-grass-oxygen188-pair-v2"
python -B research/hybrid-water01/audit_grass_wetting188.py --reference "$env:TEMP/hy481-local-b0-20261109" --bundle "$env:TEMP/s5-grass-lai-O2" --control "$env:TEMP/s5-grass-oxygen-event-189" --archive "$env:TEMP/s5-grass-heat-obs-O2/libttutil.a" --baseline "$env:TEMP/s5-grass-oxygen188-observe-v3" --output "$env:TEMP/s5-grass-wetting188-v2"
```

Experimental proof on canonical base `7535a9e650aa01ca3ee711353c2e2801e2872f00`.
PR #1618 has a complete corrected V9 run and exact own-year replay. This
experiment uses the original sharp B0 donor and the unmodified Andelst inputs.

Run from the repository root with GNU Fortran 13.3.0:

```sh
python tools/vq/b0_source_runner.py --archive /path/to/SWAP_4.3.1.zip \
  --work-dir /tmp/hybrid-b0 --case 3.macroporeflow
python research/hybrid-water01/run_day_return.py \
  --archive /path/to/SWAP_4.3.1.zip --reference-work /tmp/hybrid-b0 \
  --output /tmp/hybrid-day-return
```

The second command relinks three build-local donors: the loop return, a
four-call driver, and read-only full-precision stock/flux output. The solver
providers, original step selection and day-end process order come from B0.
All four windows completed and the standard daily series is exact against
the frozen B0 prefix. The largest independent recomputation of the donor's
reported daily water inventory residual is about 5.97e-7 cm. This is the
legacy ledger, with its own interception and snow conventions, not a new
SWAP5 kernel mass certificate.

The day-return test keeps one live donor process. In particular, the module
state and the local SAVE fields still live in the executable. A successful
return provides no fresh-process restart or A/B isolation proof. The next
implementation boundary is an explicit per-instance capture/restore of
continuation and attempt state, including TimeControl's saved clock,
HeadCalc's retained memory, BoundTop's atmospheric state, macro event
history, the crop and thermal continuations, and meteorological and output
cursors. The external Cauchy head, kernel rollback and SWAP5-owned commit
are also open. No canonical model or test gate has been altered.


## Balance-driven day stepping

Use `--budget-retry` to enable the Andelst step scheduler from day 15.
This keeps the first 14 days as a same-build control. The scheduler reads
the tentative matrix, pond, instantaneous-bypass macropore and Cauchy
terms before the donor publishes them. It asks the existing donor
rollback and timestep controller to retry if the predicted cumulative
imbalance exceeds the elapsed share of the SWAP5 daily allowance.
The hook runs after the donor's convergence checks and before recording
the step as a success. The original step floor still applies. SWAP5 checks
the actual whole-column daily ledger independently before publication.

This receipt is specific to the original Andelst bypass, snow and
bottom-boundary configuration. The step predictor covers the hydraulic
system below the canopy. The SWAP5 daily gate also includes canopy
stock and the other reported external water fluxes.

Prepare the original reference as described below. Then run from the
same PowerShell session using fresh directories:

```powershell
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced" --budget-retry --trace-richards --trace-day 33
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-cut2" --budget-retry --restart-at 2
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-cut20" --budget-retry --restart-at 20
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-cut256" --budget-retry --restart-at 256
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-year" --budget-retry --restart-at 365
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-dry" --budget-retry --restart-at 453
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-isolation" --budget-retry --isolation --days 20
```

### Measured result on the original Cauchy input

SWAP5 accepts day 15 at a residual of 7.810780e-7 cm and preserves the
original first 14 days exactly. Day 33 required one additional retry.
In its previous failing step, the surface balance expected 0.002479315 cm
to enter the macropores while the macro rates booked 0.002490494 cm.
The retry reduces that day's kernel residual to Ã¢Ë†â€™2.187284e-8 cm.

The 481-day command commits through day 256 (1998-09-13) and refuses
day 257 (1998-09-14) at revision 256 with an independently measured
residual of Ã¢Ë†â€™0.00113638236 cm. The largest absolute accepted daily
residual is 9.998896e-7 cm. The fresh donor and kernel from the day-256
checkpoint reproduce the refused day's heads, all stocks, all fluxes
and the residual. Of the 14,107 accepted donor steps in that private
day candidate, 10,625 are at or below the original 1e-5 day step floor.
They account for Ã¢Ë†â€™0.00113569639 cm of the residual. The largest single
defect occurs at clock 36051.95550000457. The macropores book
5.8657444602e-5 cm of inflow while the surface balance accounts for
5.7133102179e-5 cm. Their difference of 1.52434242e-6 cm explains the
step defect. Independent controls cap the proposed steps on that day
at 0.001 and 0.00025 days. Both still refuse day 257.

The day-2 and day-20 fresh-process comparisons and the two-column
20-day isolation pass. The year and dry-window checks stop before
their checkpoints because the continuous SWAP5 origin fails at day
257. The research host leaves this candidate unpublished. The next
implementation question is whether the original surface and macro
routines can share one transfer at the wet contact while preserving
their physical equations and the native retry contract.

See [the balance-retry result](DAILY_BALANCE_RETRY_RESULT_20261109.json)
and [its evidence archive](DAILY_BALANCE_RETRY_EVIDENCE_20261109.zip).

### Shared lateral transfer experiment

The original `Pondrunoff` code can reduce the lateral transfer after
`MacroRate` has distributed it over the domains. At the largest day-257
defect, this reduces the surface transfer from 5.5962707760e-5 cm to
5.4438365337e-5 cm and leaves the already distributed domain rates higher
by 1.5243424231e-6 cm. A separate diagnostic that adds redistributed
excess to the already accepted rates in `MacroRate` reproduces the
same refusal.

Use `--shared-pond-transfer` with `--budget-retry` to test sharing the
original surface cap. When `Pondrunoff` reduces the transfer, the adapter
applies that same cap to the accepted lateral macropore rates in
proportion to their existing shares. Vertical inflow and the original
hydraulic equations, native step floor and tolerance values retain
their original definitions. The correction is scoped to day 257 and later
so the balance scheduler can preserve the first 256 accepted days. An
earlier trial activating the correction from day 15 changed the trajectory
and refused day 162 at 3.796380e-6 cm. The scheduling-only control remains
available by omitting the shared-transfer option.

A cold run from the original initialization with `--budget-retry
--shared-pond-transfer` accepts all 481 days, January 1, 1998 through April
26, 1999. The largest independent daily water residual is 9.998896e-7 cm
on day 215 and the signed sum is Ã¢Ë†â€™3.098562e-5 cm. Days 257 and 258 close
at kernel residuals of 3.767075e-9 and 2.202054e-8 cm. The scheduling-only
control and the cold corrected run agree exactly through day 256.
The full run matches the entire fresh-process continuation from the
day-256 checkpoint. Days 2Ã¢â€ â€™4, 20Ã¢â€ â€™22, 365Ã¢â€ â€™367 and 453Ã¢â€ â€™457 reproduce the
continuous pressure heads, water stocks, fluxes and published records.
The two-column test passes for days 1Ã¢â‚¬â€œ20 and a separate isolation test
passes across the corrected wet window at days 257Ã¢â‚¬â€œ258.

Use the commands above with fresh output directories and append
`--shared-pond-transfer` to each command. The result and archive include
the original and resumed input hashes, the Cauchy perturbations for the
isolation tests and the full accepted daily ledgers. Compared with the
unmodified donor on the same compiler, the first published difference
is on day 15. The largest absolute drainage difference is 0.01135 cm on
day 258 and the largest groundwater-level difference is 84.3344 cm on
day 458. These are trajectory comparisons and are separate from the
mass acceptance and exact-restart evidence.

See [the full result](DAILY_BALANCED_RESULT_20261109.json)
and [its evidence archive](DAILY_BALANCED_EVIDENCE_20261109.zip).


### Groundwater deviation on days 457 and 458

The first published departure from the same-compiler original donor is
+0.00029 cm on day 15. The balance scheduler retries 1,949 steps on that
day. Day 457 is the first daily difference above 10 cm (+10.88535 cm).
The largest daily difference is Ã¢Ë†â€™84.33440 cm on day 458 (1999-04-03).
The native and corrected trajectories both visit deep states on day 457.
Their first accepted level below Ã¢Ë†â€™130 cm occurs at model clock
36251.941259245505 and 36251.82481645328 respectively. This distinction
separates the first published difference from the onset of the large
local excursions. The comparison does not identify a unique January
step that is sufficient to cause the April result.

The following fresh-process controls use original and corrected day-453
checkpoints with the same forcing. The two own-profile cases reproduce
their published day-458 levels exactly.

| Day-453 checkpoint | Original step policy | Balance scheduler and shared transfer |
| --- | ---: | ---: |
| Original | Ã¢Ë†â€™78.08553 cm | Ã¢Ë†â€™162.36759 cm |
| Corrected | Ã¢Ë†â€™77.98819 cm | Ã¢Ë†â€™162.41993 cm |

On the corrected checkpoint, the scheduler alone reproduces the complete
daily GWL sequence of the combined profile. In the final accepted step
of day 458 its incoming GWL is Ã¢Ë†â€™77.910974 cm. The solution changes the
zero crossing from nodes 55Ã¢â‚¬â€œ56 to nodes 80Ã¢â‚¬â€œ81 and the bottom inward
rate reaches 2.549869 cm/day. Splitting the final proposed step in two
retains a deep endpoint (Ã¢Ë†â€™160.42973 cm).

The same-prefix intervention recomputes `MACROPORE(2)` on every
`HeadCalc` residual evaluation of the final window. The preceding
25,048 accepted trace records and the first evaluation of the final
step match the scheduler-only control exactly. The first differing
evaluation retains Ã¢Ë†â€™5.311980 cm/day of net macro-to-matrix exchange
under the original reuse branch and measures +133.472818 cm/day under
recomputation. The recomputed trial follows a different iteration and
retry path and ends at Ã¢Ë†â€™77.82077 cm. The experiment isolates sensitivity
to reuse of the macro rate in the last nonlinear solve. The change in
the reported water table follows the computed pressure profile.
Recomputation is confined to the replay driver. This experiment does
not qualify it as a numerical policy for the full project.

Prepare `$ref` using the original donor command above. The `--origin`
directory must contain the own day-453 `result.end` and `macro.bin`
from the relevant continuous window. The `--prepared` directory is the
resumed day-453 case generated by that window with its `swap.swp` and
`swap.bbc`. Both profiles use the same original forcing. For the
same-prefix control and intervention, use the corrected origin and run:

```powershell
python -B "$probe/replay_groundwater.py" --reference $ref --origin $correctedOrigin --prepared $prepared453 --output "$env:TEMP/hy481-gwl-control" --budget-only
python -B "$probe/replay_groundwater.py" --reference $ref --origin $correctedOrigin --prepared $prepared453 --output "$env:TEMP/hy481-gwl-refresh" --budget-only --refresh-macro-final
```

Omit both switches to replay the original stepping policy, use
`--corrected` for both research options and add `--split-final` to test
the final half-step proposal. Each command needs a fresh output directory.
The original tolerance values apply in every case. The paired replay
driver runs in private donor directories. The existing full SWAP5
qualification remains the source of the accepted daily mass evidence.

See [the groundwater result](GROUNDWATER_REPLAY_RESULT_20261109.json)
and [the selected step and solver traces](GROUNDWATER_REPLAY_EVIDENCE_20261109.zip).

#### Day-457 final-step diagnosis

The saved crossed controls show that either the corrected day-453
origin or the corrected step policy is sufficient to avoid the
original -93.75334 cm endpoint. Under original stepping the corrected
origin ends at -83.18623 cm. Under corrected stepping the original
origin ends at -82.83449 cm. The paired corrected endpoint is
-82.86799 cm.

Fresh read-only own-origin replays reproduce all four published days
454Ã¢â‚¬â€œ457 exactly. Their last accepted steps are about 3.55 s each.
The corrected-minus-original groundwater difference grows from
0.14190 cm before the step to 10.88535 cm at its endpoint. Both first
residual evaluations have about 0.117 cm/day of bottom inflow.
At the first Newton residual evaluation the original node-58 pressure
is -0.02270 cm while the corrected pressure is +0.06314 cm.
The original final crossing moves to node 62 with bottom inflow
1.70150 cm/day. The corrected final crossing stays at node 58 with
0.11628 cm/day. The two final residual norms are near 5e-12.
The incoming states differ, so these observations identify the
transition to investigate but leave its causal direction open.

```powershell
foreach ($pair in @('00', '11')) {
    $case = "$env:TEMP/hy481-gwl-pair-$pair"
    $flags = if ($pair -eq '11') { @('--corrected') } else { @() }
    python -B research/hybrid-water01/replay_groundwater.py --reference "$env:TEMP/hy481-local-b0-20261109" --origin "$case/first" --prepared "$case/case" --output "$env:TEMP/s5-gwl457-solver-$pair" --solver-trace-day 457 @flags
}
```

See the [final-step receipt](CLOSURE01_DAY457_TRACE_20261110.json).

A same-origin intervention recomputes the existing macropore rate
only from clock 36251.99995 to 36252. The first 11,424 accepted
trace records and 272 solver evaluations match the control exactly.
At the first difference the recorded pressures and bottom rate
still match. The net macro exchange changes from -2.59580 to
+45.98259 cm/day and the maximum residual from 0.26978 to 2.55043.
The changed trial takes three accepted steps to reach the boundary,
ending at -83.71844 cm rather than -93.75334 cm. The independent
day-457 water residuals are 5.568e-9 and 5.575e-9 cm. This test shows
that recomputation is sufficient to change this endpoint in the
original trajectory. A production policy and full-period impact
require separate qualification.

```powershell
$case = "$env:TEMP/hy481-gwl-pair-00"
python -B research/hybrid-water01/replay_groundwater.py --reference "$env:TEMP/hy481-local-b0-20261109" --origin "$case/first" --prepared "$case/case" --output "$env:TEMP/s5-gwl457-solver-00-refresh" --solver-trace-day 457 --refresh-macro-final
```

The corrected-origin intervention uses the same clock window, with
`--corrected` and the `hy481-gwl-pair-11` case. It preserves 17,334
accepted trace records and 151 residual evaluations before the
first difference. The control's endpoint is -82.86799 cm and the
recomputed endpoint is -83.60749 cm. Both runs have a day residual
below 9.7e-9 cm. With recomputation the two origins' endpoints are
0.11095 cm apart, compared with 10.88535 cm in the controls.


### Full-period trial of the final-step recomputation

The optional `--refresh-macro-final` switch carries the exact clock
window of the diagnostic into the regular daily kernel runner. It requests
fresh macro rates during the existing `HeadCalc` evaluations that start
at clock 36252.9989 through the end of day 458. The donor retains its
ordinary convergence tests and retry sequence. The SWAP5 daily mass
gate remains active.

Use the full, restart and isolation commands above with fresh output
directories and add `--shared-pond-transfer --refresh-macro-final`.
The following additional controls cross the actual recomputation
window. Use the corrected continuous day-453 checkpoint (the intervention
has yet to run at that checkpoint).

```powershell
$flags = @('--budget-retry', '--shared-pond-transfer', '--refresh-macro-final')
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-refresh-full" @flags
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-refresh-cross458" @flags --origin $correctedOrigin --origin-day 453 --days 459
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-refresh-isolation458" @flags --origin $correctedOrigin --origin-day 453 --days 459 --isolation
```

With `--origin`, the kernel starts a new revision sequence on the
supplied own checkpoint. In isolation mode, the shifted column
perturbs one Cauchy-table entry by +0.001 cm at the resumed start
date for post-year checkpoints. The original and perturbed columns
have separate workers and each is compared with its own single-column
control.


The cold run accepts all 481 days, with the same accepted daily records
as the previous profile through day 457. At day 458 the published
groundwater level is Ã¢Ë†â€™77.82077 cm, compared with Ã¢Ë†â€™162.41993 cm for the
previous profile and Ã¢Ë†â€™78.08553 cm for the same-compiler original donor.
The absolute discrepancy from the original donor falls from 84.33440 cm
to 0.26476 cm on that day. Over all 481 days, the largest remaining
absolute discrepancy is 10.88535 cm on day 457. The largest day-to-day
change in the trial is +67.44652 cm on day 257, close to the original
donor's +67.44455 cm on the same day. These comparisons cover daily
outputs. They do not measure every subdaily groundwater excursion or
qualify forced recomputation at other clock times.

The independent daily water budget closes within 1e-6 cm on every day.
Its largest absolute residual is 9.998896e-7 cm. The restart windows
2Ã¢â€ â€™4, 20Ã¢â€ â€™22, 365Ã¢â€ â€™367 and 453Ã¢â€ â€™457 match the continuous run exactly.
Continuations 256Ã¢â€ â€™481 and 453Ã¢â€ â€™459 also match exactly, including the
changed day-458 state. The two-column controls match their separate
trajectories over days 1Ã¢â‚¬â€œ20, 257Ã¢â‚¬â€œ258 and 454Ã¢â‚¬â€œ459.

See [the full-period result](GROUNDWATER_REFRESH481_RESULT_20261109.json)
and [the daily comparison and replay evidence](GROUNDWATER_REFRESH481_EVIDENCE_20261109.zip).


## SWAP5 daily host and first refusal

The daily host starts from branch commit
`a0ce3081868a5c2137600739023f68f3c7c96c3d`. Each column has a private
donor process. The SWAP5 kernel requests one day at a time and uses its
reference-floor transaction to check water conservation and publish the
candidate state. The original donor performs Richards, drainage, macropore
exchange and all internal retries in their original order. The primary
run uses the original Andelst project files and tabulated Cauchy boundary.
A refusal leaves the committed kernel time and revision unchanged and
ends the private donor session. Its output remains available as a diagnostic.

Run the following PowerShell commands from the repository root with Python
and GNU Fortran on PATH. The recorded run used UCRT64 GNU Fortran 16.2.0 at
O2. Give each command a fresh output directory. The preparation command
checks the two nested source archive hashes. The daily host checks all
project files against the tracked original project, allowing only line
ending differences. The recorded outer archive is the local distribution
whose SHA-256 starts with `76a79498`. Its two nested source archives match
the pinned SWAP and TTUTIL sources.

```powershell
$env:PATH = 'C:\msys64\ucrt64\bin;' + $env:PATH
$archive = "$env:USERPROFILE/Downloads/SWAP_4.3.1.zip"
$ref = "$env:TEMP/hy481-reference"
$probe = "research/hybrid-water01"
python -B "$probe/run_daily_kernel.py" --reference-work $ref --prepare-archive $archive

# Build the audit object used by both fresh-process windows and test a kernel restart.
$restart = "$env:TEMP/hy481-kernel-restart"
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output $restart --restart
python -B "$probe/probe_macro_checkpoint.py" --reference-work $ref --day-return-work $restart --output "$env:TEMP/hy481-year" --year-boundary
python -B "$probe/probe_macro_checkpoint.py" --reference-work $ref --day-return-work $restart --output "$env:TEMP/hy481-dry" --dry-window
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-isolation" --days 14 --isolation
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-kernel-481" --trace-richards
```

The final command records a refusal and exits with status 1. January 15,
1998 is the first rejected day. SWAP5 retains revision 14 at its original
clock 35809. The preceding 14 published days match the independent,
unmodified donor on this compiler. The rejected day starts with exactly
the previous six stock components. Its independent water residual is
Ã¢Ë†â€™1.9007261301e-6 cm and the kernel measures the equivalent imbalance with
its opposite sign convention. The kernel limit is 1e-6 cm. The time
integral of the 503 residuals observed on the converged `HeadCalc` path
is +1.9007497716e-6 cm. The unexplained signed remainder is 2.36e-11 cm.
The original instantaneous limits are 1e-6 cm/day per compartment and
1e-5 cm/day for the sum. This run meets those rate limits and fails the
SWAP5 day-integrated limit. The next investigation is whether the donor
can satisfy the integrated certificate while keeping its original
physical equations and registered convergence limits.

The day-2 sidecar and binary end file rehydrate a fresh donor and a fresh
SWAP5 kernel. Days 3 and 4 reproduce the continuous pressure heads,
groundwater, drainage, bottom exchange and every water stock exactly.
The fresh kernel starts a new revision sequence at the restored physical
clock. The donor-only checkpoint tests at days 365 and 453 reproduce
1,021 and 12,928 accepted steps respectively. Both compare unrounded
stock and flux ledgers and the published records. The resumed Cauchy
table copies the last original head to the fresh start date for the
legacy date validator, preserving the original terminal hold. Two dry
days independently exceed the daily SWAP5 mass limit. Both dry-window
paths reproduce those residuals exactly.

The alternating test uses two live donor processes and two committed
columns in one kernel process. Column B changes the January 2 Cauchy
entry by +0.001 cm. All 14 days in each column reproduce its separately
executed control. The 481-day unmodified donor control succeeds, but
its Windows series and the frozen reference first differ on day 3.
Published groundwater is Ã¢Ë†â€™49.17576 cm versus Ã¢Ë†â€™47.85008 cm and drainage
is 0.65557 cm versus 0.65540 cm on that day. The available frozen records
do not localize the cross-build difference within the day. This
comparison is separate from the exact same-build restart and isolation
results.

This daily reference-floor host returns the signed integrated and
terminal lower exchange through the existing kernel adapter. The
subdaily groundwater participant and its Cauchy interface remain
available for MODFLOW work. The day-15 refusal precedes any live
MODFLOW or full-project SWAP5 qualification.

See [the measured result](DAILY_KERNEL_RESULT_20261109.json) for exact
input and executable hashes and [the evidence archive](DAILY_KERNEL_EVIDENCE_20261109.zip)
for daily results, transaction dispositions and the original HeadCalc trace.

## Legacy restart negative control

After both commands above, run:

```sh
python research/hybrid-water01/probe_legacy_restart.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-legacy-restart
```

The fresh unmodified B0 control completes all 481 days, with the published
daily series exact to the frozen reference. The split diagnostic requests
the original binary `.end` at day 2 and reads it into a fresh process. Both
segments return normal success. Matrix, canopy, pond and snow stock match at
the boundary. The first macropore domain gains 0.04000136 cm and the remaining
domains lose 0.01962962 cm before the first resumed numerical step. The
day-3 drainage and groundwater outputs then diverge. B0's `inoutend` does
not transfer those macro fields and `Swap` calls `MacroPore(1)`/MacroInit on
the restored head. The binary legacy file cannot serve as a transparent
hybrid checkpoint. The measured stock jump is one necessary restoration
target, not a proof that these two totals are sufficient.

## Experimental macropore sidecar

```sh
python research/hybrid-water01/probe_macro_checkpoint.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-macro-restart
```

The probe preserves B0 initialization and adds a versioned, host-native
macropore stream alongside the day-2 legacy end file. It reads the stream
after MacroInit and before output or the first resumed step. Its schema is
specific to the verified GNU B0 research build. The stream includes
macropore storage, event history and module-owned calculation state. The
stored clock and grid/domain counts must match the initialized run. The
sidecar is an experimental input in a private run directory. It is not a
general restart format, nor is it paired to the end file by a content hash.

The continuous donor writes the day-2 checkpoint in place and continues to
day 4. The fresh process restores all five domain stocks and the previous
step size. The first resumed crop rotation resets the canopy reservoir even
though the legacy end file read it correctly. The sidecar preserves the
canopy stock and applies it once after that rotation, before forcing and
the first solve. This restores the wet-canopy branch and root uptake.

The two trajectories have 3,442 identical audited accepted steps over days
3 and 4, including time, step size, potential transpiration, pond and canopy
stock, and all nodal heads, water contents and temperatures at the audit
point. The daily standard series is exact. This does not compare all hidden
Fortran state or establish arbitrary-boundary or SWAP5 transaction restart.

## Andelst year boundary

Add `--year-boundary` to run an uninterrupted reference through day 367,
write its checkpoint at day 365, and replay days 366 and 367 in a fresh
process. The uninterrupted run retains the original forcing. The replay
input copy repeats the last Cauchy head on January 1. The original table
ends on December 31, and its interpolation returns that last head for
all later times. The duplicate value allows the legacy date validator to
accept a January-only window while retaining the same imposed head.

The year-only research build accepts the stored inactive crop calendar
at this checkpoint by ending the crop read when the serialized flag is
false. A calendar selected for the upcoming restart date does not imply
that crop state was present at the checkpoint. Normal daily crop setup
then activates the new crop. The probe compares unrounded daily water
ledgers and audited accepted steps. It also rejects a bad signature,
truncation and trailing bytes before normal model output.

## Isolated Cauchy head trials

```sh
python research/hybrid-water01/probe_head_transaction.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-head-transaction
```

The worker takes a constant external head in centimetres. It applies it
after tabular interpolation and before the original Cauchy condition,
including its implicit Richards contribution. Both head trials start
from one unchanged day-2 checkpoint. The original-boundary control
reproduces the historical records, while the altered trials yield
different lower fluxes. The repeated A trial after B matches in the
accepted-step audit, daily outputs, water residuals and endpoint file
digests. Only the selected A result and its day-4 checkpoint are
published to the committed directory. Positive lower flux denotes
water entering the soil column from below.

This is a process-isolated donor prototype with a fixed two-day window.
It does not exercise two resident donor states in one Fortran process,
a subdaily external window, or SWAP5 kernel transaction ownership. The selected day-4 endpoint is reopened in a fresh worker for days 5 and
6 at the same imposed head. A separate worker runs days 3 through 6 as one
window from the original checkpoint. All 3,539 audited steps of days 5
and 6, daily stocks, external fluxes and both day-6 checkpoint files match
exactly. The selected day-4 checkpoint remains byte-identical.

The experimental transaction schema S5MAC004 includes the cumulative
balance reset flag. Without this flag, restart resets the cumulative
macropore counters and their initial stock. The physical trajectory still
matches, but the next sidecar differs. The flag belongs to the checkpoint
because it determines the reporting state of the next window.

## Half-day Cauchy trials

```sh
python research/hybrid-water01/probe_subday_transaction.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-subday-transaction
```

The experimental worker caps the attempted step at the remaining time
to noon on day 5, including internal retries, and returns after the
accepted step reaches noon. It checks that the donor did not process
a day end. The existing stock and flux audit is sampled at that
endpoint for the half-day water ledger.

A clean trial at -50 cm precedes an independent rejected trial at -90 cm
and a selected repetition at -50 cm. The day-4 origin hashes remain fixed
and the clean and selected trajectories and endpoint bytes agree.
The selected result is atomically published by the research harness.
The resulting files provide endpoint comparison evidence. Reopening a
fractional endpoint, sharing one Fortran process between columns and
committing through the SWAP5 kernel API remain separate tests.

## Live handoff at noon

```sh
python research/hybrid-water01/probe_noon_handoff.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-noon-handoff
```

A single donor returns to its Fortran caller at noon on day 5, keeping
the initialized state live. The caller applies the second external head
and calls the donor again. The reference uses the same noon step cap and
applies the same head inside its uninterrupted call. A fixed-head run
provides an independent check that the new head changes only the
second half of the day.

The switched head is -50 cm before noon and -90 cm afterward. The
probe requires exact audited steps, unrounded daily stocks and fluxes,
daily records and both day-6 checkpoint files. It checks the water
residual for both days and verifies that the original day-4 checkpoint
was unchanged. This qualifies re-entry into one live donor. Fractional
restart from disk, multiple donor instances within one process and
SWAP5 transaction API ownership are outside this control.

## Two resident donors in one GNU process

This Linux/glibc research probe requires the verified B0 distribution and
position-independent objects. Build the ordinary reference with the
existing B0 runner through a compiler wrapper named `gfortran` that adds
`-fPIC` to each compiler invocation. Keep that wrapper on PATH for the
commands below. The unmodified reference input and audit are the same
as in the previous probes.

```sh
python research/hybrid-water01/probe_resident_donors.py \
  --reference-work /tmp/hybrid-b0-pic --day-return-work /tmp/hybrid-day-return \
  --noon-work /tmp/hybrid-noon-handoff --output /tmp/hybrid-resident
```

The probe links one shared library and loads it into two glibc loader
namespaces. Each namespace has its own Fortran runtime and donor state.
The host calls both instances serially within a single process, switching
directories and stdout around each call. Both instances remain live at
noon and receive a different external head. They must reproduce their
separate runs exactly, including daily stocks, fluxes, the accepted-step
audit and both day-6 endpoint files. A also matches the endpoint files of
the previous standalone -50 cm control. The water ledger closes for both.

This demonstrates resident isolation by loader namespace, with serial
process-wide directory changes. It is platform specific and does not
qualify threads, fractional disk restart, or transaction ownership
through the SWAP5 kernel API.

## SWAP5 owned acceptance and next day restart

```sh
python research/hybrid-water01/probe_kernel_donor.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --noon-work /tmp/hybrid-noon-handoff --output /tmp/hybrid-kernel-donor
```

The Fortran driver binds the real donor adapter to the existing SWAP5
kernel reference-floor executor. Two committed columns carry distinct
lineages and revisions. Each trial runs the Andelst solver in a fresh
worker. The executor checks the donor stock and external water ledger,
discards the first candidate for column 1 and commits four accepted
half-day candidates. The original checkpoint stays byte-identical.
The reference-floor path qualifies mass and state ownership. The normal
coupling participant's temporal controller and a MODFLOW call are outside
this test.

The afternoon trial replays the already accepted morning from the day-4
checkpoint and requires exact agreement for the full morning step audit
before accepting the afternoon ledger. This uses process isolation and
recomputation. It does not load a fractional checkpoint or use the
separate resident namespace prototype. At midnight, a fresh worker
starts from the actual selected checkpoint of each column. Day 6 must
match an independent continuous run, including audited states, the
water ledger and both endpoint files.

The donor build used by this adapter removes the local declaration that
shadows the module-owned previous wet-wall fraction in MacroIntegral.
That previous fraction is already in the macro checkpoint. The change
resolves two reporting-array discrepancies observed in otherwise exact
day-6 trajectories, while leaving the audited hydraulic behavior exact.
No canonical solver, input guard or runtime contract is modified.

## Regular coupling participant temporal check

Add `--temporal` to the kernel donor command to use the existing
groundwater SWAP participant and ordinary kernel interval executor.
The physical adapter supplies the real full window and both half
windows. For the second half it replays the first from the immutable
day-4 origin and requires exact agreement with the first-half audit.
A narrow research assessment compares maximum absolute nodal pressure
head at the endpoint against 0.05 cm. It is not a production tolerance.

At the -50 cm boundary, 0.5, 0.0625 and 0.000244140625 day windows
all close the water ledger within 1e-6 cm. The pressure head defects
are 0.328585 cm at node 77, 1.751306 cm at node 60 and 0.821688 cm
at node 57, respectively. The half-day integrated bottom exchanges
differ by about 3.03e-6 cm even though the pressure criterion fails.
The participant rejects all three with no live candidate or time,
revision or origin-checkpoint mutation. The run has zero automatic
retries so each tested window is separately observable. The test
does not establish an acceptable temporal metric or MODFLOW coupling.

## Experimental water-based temporal assessment

Use `--water-metric` with the kernel donor command. The regular
groundwater participant uses the larger of three sibling differences
in centimetres: total column water stock, the maximum water stock
difference across matrix, pond, snow, canopy and two macropore groups,
and integrated bottom exchange. The mass gate is still 1e-6 cm.
The research tolerance of 1e-4 cm is confined to this specific case,
head and origin. The original pressure diagnostic remains available
via `--temporal`.

At -50 cm, the 0.0625-day negative control is rejected because one
component differs by 5.50e-4 cm. From the unchanged origin, the 0.5-day
window is accepted: whole-column stock differs by 2.77e-6 cm, the
largest component by 5.38e-5 cm and the bottom exchange by 3.03e-6 cm.
The participant publishes the two-half candidate and converts its
bottom exchange to the signed groundwater interface flux. This
establishes an accepted normal SWAP5 participant window in the
experimental donor adapter. It does not qualify the tolerance across
other regimes, replace the pressure criterion in production, or run
MODFLOW.

## Live MODFLOW 6 corrector

Pass `--mf6 /path/to/mf6` to the kernel donor command with FloPy
installed. The tested binary is MODFLOW 6.8.0 from the F-GC44 release
archive (SHA-256 `33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e`).

The probe uses a confined, unit-area, unit-thickness cell with specific
storage 0.15 per metre and initial head -0.493 m. In each half-day
corrector the regular SWAP participant supplies the integrated bottom
exchange to a fresh MODFLOW 6 WEL trial. The host reads native heads,
WEL and STO-SS volumes, checks the native cell budget and stages the
equal-and-opposite exchange in the SWAP5 interface ledger. MODFLOW
starts each trial at the same accepted origin. This is a batch
corrector, not the prepared XMI live service.

The experimental water-metric tolerance stays at 1e-4 cm. A failed
SWAP candidate is retried halfway between the last feasible head and
the refused head. A successful but nonconverged candidate and its
staged interface entry are discarded. Publication requires head
agreement within 1e-8 m in at most fourteen correctors. The measured
run did not meet that target. Ten groundwater solves closed their
native budget, four Andelst correctors were refused, and no coupled
state or interface exchange was committed. The best head mismatch
was about 2.26e-6 m.

### Step-size and corrector sensitivity

Run the same command with `--max-step-days` set to 0.002, 0.001,
0.0005 or 0.00025. The probe sets the case's DTMAX and clips the
proposed step before weather processing, because the legacy restart
can otherwise retain an initial step above DTMAX. The worker checks
the cap again after the retry loop. For 0.002 and 0.001, repeat with
`--bracketed` to bisect between feasible opposite-sign residuals
when such a bracket exists. A sign bracket alone cannot authorize
publication. The same temporal and head criteria and 14-trial
budget apply. A refusal before the first feasible SWAP trial ends
without an MF6 solve or a commit.

All six runs ended at accepted revision zero. The best result was
3.54e-7 m with the bracket and 0.002 day cap, against 1e-8 m required.
At 0.0005 and 0.00025 days the initial trial already failed the
component-stock temporal check. The untuned two-column midnight
restart probe still reproduced both day-6 trajectories and files.

To reproduce the paired replay, use `run_worker` from
`probe_head_transaction.py` with each run's
`half/andelst_transaction_worker`, the same Andelst input and day-4
checkpoint, a fresh destination, dates 1998-01-05 through 1998-01-06,
`subday=True`, `fraction=35799.5`, `split_clock=35799.25`, the
recorded cap as `max_step_days` and each of the recorded heads in cm.
Pair each accepted trajectory record's clock and step size with the
following bottom-inward rate. Integrate by summing rate times step.
Compare the shared prefix only while both clocks and step sizes agree.

The two inputs differ by 2.90e-6 m. At the 0.002-day cap their first
149 accepted clocks and step sizes agree, but they have already
accumulated a 9.87e-5 cm difference in bottom exchange before the
grids separate. The result rules out different accepted time grids
as the sole explanation. It does not identify the upstream state
transition responsible for the growth. The donor's Cauchy flux uses
the modelled water table at the beginning of a step, and SoilWater(3)
updates that water table after each accepted solve. This feedback and
the matrix/macropore iterations are the next targeted comparison.

### One live volume handoff at the initial groundwater head

Add `--origin-predictor` to the MF6 command with `--max-step-days 0.002`.
The existing donor and SWAP5 participant perform one half-day trial
with the initial groundwater head (-0.493 m) as the imposed constant
head. The temporal gate remains active before any MF6 solve. After
the equal-and-opposite volume handoff the existing head and budget
criteria determine whether publication is possible. A failed head
check discards both trial entries and leaves the accepted origin intact.

The day-four checkpoint was rebuilt from the pinned original SWAP
archive with GNU Fortran 13.3.0 and reproduced the recorded hashes.
The native MODFLOW 6.8.0 run received -0.00118024830 m3 and closed the
one-cell budget to 1.42e-14 m3. All three SWAP temporal defects were
below 1e-4 cm. MODFLOW ended at -0.500868322 m, a head residual of
7.868 mm. The origin predictor therefore did not pass the strict head
criterion or commit. See `ORIGIN_PREDICTOR_RESULT.json`.

### Macropore rate reuse at provisional convergence

Use the day-453 inputs and checkpoints from the final-step experiment
above. With GNU Fortran on PATH, run these commands from the repository
root in PowerShell. The day-458 case uses the budget retry with the
corrected checkpoint and the original shared-pond treatment, matching
its earlier control.

```powershell
foreach ($trial in @(
    @{ Day = 457; Id = '00'; Mode = @() },
    @{ Day = 457; Id = '11'; Mode = @('--corrected') },
    @{ Day = 458; Id = '11'; Mode = @('--budget-only') }
)) {
    $case = "$env:TEMP/hy481-gwl-pair-$($trial.Id)"
    $mode = $trial.Mode
    foreach ($probe in @(
        @{ Name = 'event'; Flag = '--trace-reuse-event' },
        @{ Name = 'fresh'; Flag = '--check-fresh-residual' }
    )) {
        python -B research/hybrid-water01/replay_groundwater.py `
          --reference "$env:TEMP/hy481-local-b0-20261109" `
          --origin "$case/first" --prepared "$case/case" `
          --output "$env:TEMP/s5-gwl$($trial.Day)-$($probe.Name)-$($trial.Id)" `
          --solver-trace-day $trial.Day $probe.Flag @mode
        if ($LASTEXITCODE -ne 0 -and $probe.Name -eq 'event') {
            throw "Read-only Andelst replay failed"
        }
    }
}
```

### Grassgrowth conductive day ledger

Run from the repository root with GNU Fortran and GCC on PATH. Use new
directories for each build, uninterrupted run, cut and fresh restart.

```powershell
foreach ($opt in @('O0', 'O2')) {
    $b = "$env:TEMP/s5-closure-conductive-$opt"
    python -B tools/solute/build_grass_startup.py --output $b --optimization $opt --policy retained --numerical-profile thermal-control-1e-5C
    if ($LASTEXITCODE -ne 0) { throw "Grassgrowth build failed" }
    python -B tools/solute/run_water.py --model NATIVE_GRASSGROWTH_WATER --grass-build $b --output "$b-full" --days 4
    if ($LASTEXITCODE -ne 0) { throw "Grassgrowth control failed" }
    python -B tools/solute/run_water.py --model NATIVE_GRASSGROWTH_WATER --grass-build $b --output "$b-cut" --days 2
    if ($LASTEXITCODE -ne 0) { throw "Grassgrowth checkpoint run failed" }
    python -B tools/solute/run_water.py --model NATIVE_GRASSGROWTH_WATER --grass-build $b --output "$b-resume" --days 4 --restart "$b-cut/checkpoint.bin"
    if ($LASTEXITCODE -ne 0) { throw "Grassgrowth restart failed" }
}
```

### Grassgrowth mixture stock and liquid heat observation

The observer adds output inside the existing accepted thermal receipt
loop in a detached canonical worktree. It evaluates sensible endpoint
stock relative to 0 Ã‚Â°C. The exact product split separates the existing
conductive storage change from the water and air capacity changes
weighted by mean endpoint temperature. The water receipt independently
closes with the upward-positive face signs and the accepted nodal
source. Liquid outflow heat uses the final soil temperature as an
explicit estimate. The recorded positive net water inflows require donor
temperatures that the receipt does not supply.

Run from the research worktree with GNU Fortran and GCC on PATH.

```powershell
$source = (Get-Location).Path
$probe = "$env:TEMP/s5-grass-heat-observed-20261110"
git worktree add --detach --no-checkout $probe a57d7d532464ad89b7aca918263cf114b6b42185
git -C $probe sparse-checkout set src app tools reference integration/audits/evidence tests/support
git -C $probe reset --hard HEAD
python -B research/hybrid-water01/observe_grass_heat.py $probe
Push-Location $probe
try {
    foreach ($opt in @('O0', 'O2')) {
        $b = "$env:TEMP/s5-grass-heat-obs-$opt"
        python -B tools/solute/build_grass_startup.py --output $b --optimization $opt --policy retained --numerical-profile thermal-control-1e-5C --end 1
        if ($LASTEXITCODE -ne 0) { throw "Observed Grassgrowth build or day 1 failed" }
        python -B tools/solute/run_water.py --model NATIVE_GRASSGROWTH_WATER --grass-build $b --output "$b-resume4" --days 4 --restart "$b/original-interval/checkpoint.bin"
        if ($LASTEXITCODE -ne 0) { throw "Observed Grassgrowth continuation failed" }
        python -B "$source/research/hybrid-water01/audit_grass_heat.py" --build $b --resume "$b-resume4"
        if ($LASTEXITCODE -ne 0) { throw "Accepted heat audit failed" }
    }
} finally { Pop-Location }
```

### Grassgrowth replay of the original thermal clock

Rebuild only the original temperature provider with an observer and
link it to the retained B0 objects. Use the full original inputs for
initialization, including the dates outside the observed window. The
observer stops after the last heat solve on day 63 and does not issue a
full-project completion flag. An initial attempt to shorten TEND was
refused by the original lower-boundary date reader.

The native replay uses the heat-owner objects built for the four-day
observation above. It compares three trajectories with the legacy
profile at each step. The full-step replay preserves the exact original
accepted intervals. The frozen half-step replay preserves each
original interval's moisture-averaged coefficients. The interpolated
half-step replay additionally distributes the original moisture change
linearly over its two halves.

```powershell
$legacy = "$env:TEMP/s5-grass-b0-heat63-all-20261110"
python -B research/hybrid-water01/replay_grass_legacy_heat.py --reference "$env:TEMP/hy481-local-b0-20261109" --output $legacy --all-thermal-leaves
if ($LASTEXITCODE -ne 0) { throw "Original Grassgrowth thermal observation failed" }
foreach ($opt in @('O0','O2')) {
    $b = "$env:TEMP/s5-grass-heat-obs-$opt"
    $objects = @(2..6 | ForEach-Object { "$b/$_.o" })
    gfortran "-$opt" -fcheck=all -I $b research/hybrid-water01/replay_grass_heat_leaf.f90 @objects -o "$b/replay-grass-heat-history.exe"
    if ($LASTEXITCODE -ne 0) { throw "Native thermal replay build failed" }
}
python -B research/hybrid-water01/audit_grass_heat_history.py --legacy $legacy --native "$env:TEMP/s5-events-grass-367" --replay-o0 "$env:TEMP/s5-grass-heat-obs-O0/replay-grass-heat-history.exe" --replay-o2 "$env:TEMP/s5-grass-heat-obs-O2/replay-grass-heat-history.exe"
```

### Grassgrowth first hydraulic endpoint

Use the previous heat observation builds for the original TTUTIL
archives. The two native profiles use the same source and numerical
water tolerance. They differ by the existing registered thermal
profile, which includes its bounded small-drainage handling.

```powershell
$source = (Get-Location).Path
$probe = "$env:TEMP/s5-grass-water-start-20261110"
$legacy = "$env:TEMP/s5-grass-first-water-b0-20261110"
python -B research/hybrid-water01/replay_grass_legacy_heat.py --reference "$env:TEMP/hy481-local-b0-20261109" --output $legacy
git worktree add --detach --no-checkout $probe a57d7d532464ad89b7aca918263cf114b6b42185
git -C $probe sparse-checkout set src app tools reference integration/audits/evidence tests/support
git -C $probe reset --hard HEAD
python -B research/hybrid-water01/observe_grass_heat.py $probe
python -B research/hybrid-water01/observe_grass_water_start.py $probe
Push-Location $probe
try {
    foreach ($opt in @('O0','O2')) {
        $b = "$env:TEMP/s5-grass-water-start-$opt"
        $tt = "$env:TEMP/s5-grass-heat-obs-$opt/libttutil.a"
        python -B tools/solute/build_grass_startup.py --output "$b-thermal" --optimization $opt --input-archive $tt --policy retained --numerical-profile thermal-control-1e-5C --end 1
        if ($LASTEXITCODE -ne 0) { throw "Observed thermal profile failed" }
        python -B tools/solute/build_grass_startup.py --output "$b-water" --optimization $opt --input-archive $tt --reuse-build "$b-thermal" --policy retained --end 1
        if ($LASTEXITCODE -ne 0) { throw "Observed water-only profile failed" }
    }
} finally { Pop-Location }
python -B "$source/research/hybrid-water01/audit_grass_water_start.py" --legacy $legacy --build-root "$env:TEMP" --output "$env:TEMP/s5-grass-water-common-clock-20261110"
```

### Grassgrowth first full candidate before selection

The observer records the complete native full-step and half-step
candidates in the temporal assessment, before either is accepted.
Compile it only in a detached canonical worktree and retain the
original time and mass checks. The preceding common-clock water-only
runs provide the accepted output controls.

```powershell
$source = (Get-Location).Path
$probe = "$env:TEMP/s5-grass-full-trial-20261110"
$legacy = "$env:TEMP/s5-grass-first-candidate-b0-20261110"
python -B research/hybrid-water01/replay_grass_legacy_heat.py --reference "$env:TEMP/hy481-local-b0-20261109" --output $legacy
git worktree add --detach --no-checkout $probe a57d7d532464ad89b7aca918263cf114b6b42185
git -C $probe sparse-checkout set src app tools reference integration/audits/evidence tests/support
git -C $probe reset --hard HEAD
python -B research/hybrid-water01/observe_grass_full_trial.py $probe
Push-Location $probe
try {
    foreach ($opt in @('O0','O2')) {
        $b = "$env:TEMP/s5-grass-full-trial-$opt"
        $tt = "$env:TEMP/s5-grass-heat-obs-$opt/libttutil.a"
        python -B tools/solute/build_grass_startup.py --output $b --optimization $opt --input-archive $tt --policy retained --end 0.0002
        if ($LASTEXITCODE -ne 0) { throw "Observed native full candidate failed" }
    }
} finally { Pop-Location }
python -B "$source/research/hybrid-water01/audit_grass_full_trial.py" --legacy $legacy --build-root "$env:TEMP" --controls "$env:TEMP/s5-grass-water-common-clock-20261110"
```

### Grassgrowth committed LAI at the original first mowing

With checked O0/O2 builds from PR #1622 on the water-only retained
profile, run the following from its checkout. For the full run use the
unchanged original inputs and the O2 build.

```powershell
$b = "$env:TEMP/s5-grass-lai-O2"
$full = "$env:TEMP/s5-grass-lai-original-128"
python -B tests/dataqual15/run_original.py --bundle $b --output $full --end 128 --capture 126 127 --timeout 540
python -B tests/dataqual15/run_original.py --bundle $b --output "$full-resume" --end 128 --restart "$full/checkpoint-126.bin" --capture 127 --timeout 120
```

From the research worktree, verify the restart, archived comparison
and native crop snapshot.

```powershell
python -B research/hybrid-water01/audit_grass_committed_lai.py --full "$env:TEMP/s5-grass-lai-original-128" --resume "$env:TEMP/s5-grass-lai-original-128-resume" --predecessor "$env:TEMP/s5-events-default-140" --build "$env:TEMP/s5-grass-lai-O2"
```

The wet-event continuation uses the same native O2 executable.

```powershell
python -B tests/dataqual15/run_original.py --bundle "$env:TEMP/s5-grass-lai-O2" --output "$env:TEMP/s5-grass-oxygen-event-189" --end 189 --restart "$env:TEMP/s5-grass-lai-original-128/checkpoint.bin" --capture 187 188 --timeout 240
```
