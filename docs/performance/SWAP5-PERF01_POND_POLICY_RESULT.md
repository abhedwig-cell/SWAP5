# PERF01 completed infiltration day: work, accuracy and cost

The remaining large cost in this32-cell case is repeated temporal/solver work
and constitutive evaluation. A solver-capped proposal fails the hard chemical
budget and is rejected. The exact prepared-origin cache preserves this case but
does not establish a general performance improvement. Varying the existing
explicit temporal input gives a much larger measured cost/error tradeoff while
all hard physical balances remain unchanged.

This is completed generated-only research under the
[preregistered contract](SWAP5-PERF01_POND_POLICY_CONTRACT.md).
`integration/diagnostics/PERF01_POND_POLICY_STATUS.json` records source binding,
qualification and integration separately. The production source tree remains
`d33b91286c478708e2a7db41bee4c3c0eb141c19`. Measurement baseline is
`fcea7f0e016bb840749d5b5565574dadde9d4733`; source registration composes the
descriptive NUT receipt `242a733aaab49bf173b52313bfa9af01cbecdc7b` without changing
any executed model input. No production default, physical option, numerical
policy, restart format or master disposition changes.

## Complete-day profile

A fresh189-provider GNU13.3 production O2 closure with `-pg` completes all64
windows through day1 in124.07s wall /123.94s user CPU,144944KiB peak RSS.
Budget, final state, endpoint and restart bytes equal the admitted actual
production day. Raw gmon, normalized symbols, complete gprof tables and every
compile/link/tool/native stream are retained.

| Attributed model work | Measurement |
| --- | ---: |
| HeadCalc including descendants | 83.4% of model samples |
| HeadCalc calls | 2,945,576 |
| Same-branch MvG storage increments | 371,171,136 |
| Tri-diagonal solves | 11,599,098 |
| Trace append self samples | 3.49% |
| Checkpoint capture + restore self samples | 0.31% |
| Accepted internal transactions | 101,014 |
| Temporal rejections | 710,966 |
| Solver rejections | 290,399 |

There are1,102,379 attempts and202,028 accepted chemical flux substeps. HeadCalc
sample calls equal the independently recorded production diagnostic counter.
The flat table attributes51.60s of self time; it does not account for all shared
math-library time or profiling overhead. The83.4% is a call-graph attribution of
model samples, not83.4% of complete uninstrumented CPU. Earlier short-case trace
profiles describe another workload and cannot be treated as a matched before/
after profile for this completed day.

## Rejected capped numerical proposal

The private runtime retains an accepted step after solver rejection, caps its
growth factor at1 for that transaction, and otherwise uses the existing bounded
temporal controller. Exact endpoints, interval-private reset, nonlinear/temporal
criteria and hard physical budgets are retained. The observing main removes only
the production application's exclusion of this unadmitted combination.

It fails in requested window2, after one externally committed window. First-window
accepted internal steps rise from238 to8979 and HeadCalc calls from5232 to32101;
temporal rejections fall, but solver rejections rise from457 to4640. Lower
temporal-rejection count alone therefore does not establish lower work.

A separate observation inserts only a print at the unchanged aggregate chemical
guard. All53730 second-window chemical substeps finish, but the aggregate residual
is3.4243373790789246e-11mg/cm2 against the unchanged2.0716411739740200e-11 limit.
The receipt's before/after/input/output values independently reproduce both
residual and threshold. No guard is relaxed. The second external budget row,
completed endpoint and restart are absent; both external clocks stay at0.015625
day. The capture reproduces the original failure's physical prefix and work.
Full-day, refinement and O0 follow-ups of this failed policy are not selected.

## Exact prepared-origin cache counterfactual

The existing rejected patch is applied only in a separate source worktree.
Because it changes the Richards workspace layout, its dependent provider closure
is rebuilt fully at checked O0 and production O2. Replacing two old objects would
not prove ABI compatibility. Exact two-file overlays and full build receipts are
retained; repository production files are unchanged.

The existing real module driver passes28800 bitwise increment pairs at each of
O0/O2/O3, including changed origins, branch crossings and elastic storage. Checked
O0 and production O2 prefixes and the complete O2 day reproduce all physical
files, reporting trajectories, restart bytes and deterministic work exactly.
A separate counter capture proves407474 prepared selections in407475 solver
calls, rather than an inactive cache. That capture is excluded from timings.

Three serial pairs use the same observing main, source input, GNU production
flags and one available CPU. Pair order is control/cache, cache/control,
control/cache. Compilation and Python work are outside native measurements.

| Pair | Control user CPU (s) | Cache user CPU (s) | Observed CPU reduction |
| --- | ---: | ---: | ---: |
| 1 | 16.492 | 14.045 | 14.84% |
| 2 | 14.885 | 13.485 | 9.41% |
| 3 | 14.567 | 14.517 | 0.34% |

The separate complete cache day takes100.01s user CPU under its own execution
conditions. It is a physical-preservation observation, not a matched full-day
speed ratio. The variable paired results and earlier nonuniform short-case
measurements do not justify general production activation or a portable gain.

## Existing temporal input: full-day accuracy/cost curve

Each arm uses the current unmodified production objects and identical observing
main, the admitted explicit pond physics, the default numerical route and the
same CPU. Only `temporal_tolerance` changes. Each completes all64 reporting
windows. Values below are single native observations; work-count reductions are
independent of timing noise. No physical or mass tolerance is relaxed.

Water errors use the same independently converged continuous finite-volume/BDF
reference from the prior physical qualification. Relative theta error is the
maximum pointwise absolute error divided by reference theta, across all32 nodes
and64 reporting times. It is not the relative error in a small moisture change.

| Explicit local tolerance | User CPU (s) | HeadCalc calls | Max head error (cm) | Max theta error | Max relative theta error |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1e-6 | 98.263 | 2,945,576 | 0.011665 | 1.78576e-6 | 0.0006685% |
| 1e-5 | 27.723 | 812,691 | 0.035427 | 5.54435e-6 | 0.0020647% |
| 1e-4 | 7.837 | 223,836 | 0.116413 | 1.79061e-5 | 0.0067499% |
| 1e-3 | 1.774 | 52,275 | 0.408943 | 6.06234e-5 | 0.0236588% |

The observed1e-4 and1e-3 user-CPU ratios to1e-6 are12.54 and55.38 respectively.
These are changed-accuracy comparisons, not equivalent-accuracy implementation
speedups. Pressure, moisture, cumulative evaporation and cumulative runoff errors
are recomputed from the raw CSVs; all increase with the looser values in this
case. At1e-3 cumulative evaporation/runoff errors are1.31701e-6cm /6.84478e-5cm.

| Local tolerance | Max solute concentration spread (mg/cm3) | Max relative concentration spread |
| --- | ---: | ---: |
| 1e-6 | 1.94460e-6 | 0.0003663% |
| 1e-5 | 7.75792e-6 | 0.0014744% |
| 1e-4 | 2.72471e-5 | 0.0051043% |
| 1e-3 | 1.00173e-4 | 0.0179266% |

The chemical comparison is against the retained finer1e-7 native research
trajectory. It is discrete-run spread, not independent chemical truth. Whole
water/solute residual maxima across all four runs are9.54e-14cm /2.70e-13mg/cm2.
Hard conservation therefore remains satisfied while numerical accuracy changes.
The strictest arm also reproduces the immutable admitted physical artifacts.

This32-cell prescribed-sink day has fixed material, one forcing pattern and no
live crop/heat/regional orchestration. It establishes an error/cost curve for this
case. It does not select a universal tolerance, establish annual/HRU accuracy,
compare matched SWAP4 physics, or change the production Reference default.

## Reproduction and owning checks

`study_perf01_pond_policy.py` retains every build input, generated source, linked
object digest, native command, timeout, per-process resource use and raw output.
Executed helper versions are retained separately by SHA, including the exact
intermediate balance-capture version. The frozen rejected patch remains unchanged.
The existing production owner receives only an exact neutral-registration hook;
its scientific assertions and native oracles remain intact. Its own checksum is
the only changed field in the existing owning record. The current27 production
corruption controls and the separate research evidence controls are selected.

The new verifier checks profile physical identity, source overlays, actual cache
activation, failed policy classification, exact paired work, complete accuracy/
cost points and raw-reference error arithmetic. It does not turn a failed native
policy into a qualified production policy. Exact qualification and actual
canonical integration receipts are recorded in the owning status.
