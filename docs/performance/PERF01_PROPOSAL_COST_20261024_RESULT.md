# Remaining native proposal cost

Bounded research on canonical `22cdf5700dbea526c2ef217db20b738048e3eebe`.
Production, defaults, tolerances and every acceptance gate remain unchanged.
PR1389 saturated-flux repair and PR1394 optional native proposal are already
canonically admitted. The later PR1396 detailed-rain caller is preserved, not
enabled in these constructed four-cell, zero-tracer, simple-crop/ETref97-day
1x/4x cases. This is not the original full Andelst model or equivalent-accuracy
performance against4.3.1.

## Current route

Fresh ordinary and generated instrumented current applications run at checked
O0/O2, reusing193 hash-verified provider objects. The recovered GNU13.3 compiler
version is checked and every ordinary/profile physical output is byte-exact to
the admitted PR1394 oracle: budget, state, endpoint and complete restart.
O2 has three serial alternating repetitions per arm; O0 has one. All work,
including failed proposals before a whole-day retry, is counted.

| Native measurement, seconds | 1x proposal ON | 4x proposal ON |
| --- | ---: | ---: |
| Ordinary native median |0.570|0.687|
| Instrumented native median |0.622|0.726|
| HeadCalc |0.395|0.482|
| Physical provider/adapter/state outside HeadCalc |0.147|0.171|
| Transaction controller/state outside physical trials |0.018|0.023|
| Chemistry/joint orchestration outside transactions |0.045|0.038|
| Input parsing, validation and initialization |0.0023|0.0021|
| Output serialization, writes and endpoint collection |0.0025|0.0021|
| Rejected attempts, overlapping the computational rows |0.426|0.555|

The nested computational rows are disjoint. Independently computed medians,
remaining application/accepted-diagnostic work, process launch and final research
reporting need not sum exactly to native wall time. The input timer includes
initialization, not pure file reading; the output timer includes serialization
and snapshots, not pure disk latency. The older separately measured Python
preparation/publication envelope, about0.15s, is not remeasured here and must not
be added to native components as a new observation.

Rejected attempts still consume69%/76% of instrumented native time. Direct
controller instructions take about3%; the controller's choice of attempted
interval creates much more solver work than its own arithmetic costs.

| Work counter, OFF to ON | 1x | 4x |
| --- | ---: | ---: |
| Attempts |37,371 to19,635|32,702 to22,382|
| Temporal rejects |31,041 to13,459|27,528 to16,460|
| Solver rejects |1,352 to1,386|1,597 to1,695|
| HeadCalc calls |109,826 to56,528|95,709 to64,480|

There are no mass rejects. Retaining proposals reduces temporal waste, but does
not reduce solver rejects in this comparison.

Generated runtime accounting distinguishes initial proposals, active proposals,
the remainder of an interval after a solver rejection permanently disables
proposals, and the application's ordinary whole-day retry. The disabled regime
costs0.325/0.181s,59%/27% of transaction time. Ordinary day retries cost
0.126/0.406s,23%/60%. The initially abandoned proposal day itself costs only
0.0083/0.0336s. These are overlapping views of the nested timing, not additional
costs to sum. Incumbent fallback days remain83 and7/74/92.

## Three generated policy discriminators

No production runtime is edited. Each generated runtime retains all mass,
solver, temporal full/two-half and retry checks, plus the unchanged application's
atomic whole-day ordinary-policy fallback. Both rain series complete at O0/O2;
three O2 pairs, default-OFF byte preservation and actual day48 restart pass.
The following are within-study ordinary-policy/probe native medians, not values
to compare across separate cohorts.

| Research policy | 1x ordinary to probe, s | 4x ordinary to probe, s | Decision |
| --- | ---: | ---: | --- |
| Hold accepted dt after solver rejection, no growth |0.613 to8.346|0.810 to9.781|Reject for performance |
| Same, temporal safety factor with growth capped at1.1 |0.642 to2.883|0.752 to0.782|Reject as a general speedup |
| Same recovery, ordinary day fallback after1,024 internal transactions |0.697 to0.745|0.799 to0.745|Research only; no consistent overall win |

The fixed cap accepts23,264 halfsteps on1x day89. Worse, days18/61/68 reach
the unchanged100,000 internal-step limit before fallback, with about300,000
HeadCalc calls each. Limited growth still hits that limit on day18. Thus merely
keeping proposals alive after solver trouble is not an adequate fix.

The1,024 guard is above the incumbent maximum506/489 daily transactions for
1x/4x. It only rejects earlier; it never admits a larger error. Its18 actual
failed joint generations are byte-identical before/after failure. Every final
physical byte also exactly equals the corresponding unbounded1.1-recovery
result. It removes that research policy's long abandoned tail, but gives about
7% slower1x and7% faster4x versus the incumbent in its O2 cohort. It is not a
production recommendation or a broad performance guarantee.

Independent reconstruction from original daily rain and bottom forcing closes
below1e-9mm for all research policies. Maximum runoff difference is zero at1x
and7.8e-12mm at4x; maximum storage difference is8.1e-12mm. Total evaporation and
transpiration meet the original proposal contract. Individual soil/pond
evaporation allocation shifts up to0.03781mm/day and0.04635mm seasonally are
reported rather than hidden. Final head differences are about0.00112/0.00072cm.
These tests do not establish general trajectory or global-error equivalence.

## Evidence and next target

The existing work-unit status is
`benchmarks/performance/PERF01_PROPOSAL_COST_20261024_STATUS.json`; its result and
manifest-bound capsule retain120 native processes,32 compile/link events,
generated sources, original forcing oracle, full streams and physical outputs.
`seal_perf01_proposal_cost.py` independently reconstructs the physical checks,
timing medians and eight evidence-corruption controls. The current original
detailed-rain owner and all17 controls also pass without source changes.

The fixed-cap study took173s including builds/validation orchestration events,
above its initial60s estimate because the newly exposed accepted-step tail was
expensive. No process was timed out or silently excluded. The other two probe
event totals are56s/49s; profiling is separate. These are child-event sums,
not an independently measured total controller wall time.

The next useful question is the cause and cost of individual solver rejections
on incumbent fallback days7/74/92 and83, including the near-saturated and tiny-dt
limit. Preserve existing proposal compatibility, hard water/runoff and atomic
restart semantics. Output tuning is not the leading native opportunity. No new
1e-6 run, RossFast extension, highest-low-air test or unrelated full F-CI was
selected. Affected invariants2,5,7,13,23,24,26 are preserved. Production admission
of a different numerical policy is outside this research result.
