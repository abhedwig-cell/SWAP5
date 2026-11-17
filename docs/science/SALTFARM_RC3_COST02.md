# SaltFarm RC3 bounded cost investigation

**No safe speedup qualified; RC3 and production code remain unchanged.** The
owner requested reduction of the measured SaltFarm overhead. This investigation
does not achieve an admitted performance improvement. It preserves the tested
negative outcomes instead of weakening physics, iteration limits, tolerances,
mass, restart or output/state contracts. The fixed RC3 source/ZIP is immutable.

## Reused evidence and actual cost

The [earlier performance investigation](RC1_CROSSPLATFORM_PERF01.md) already
identified native donor work as dominant, rejected an ineffective hydraulic
format change, and admitted invocation-local compiler checks and prepared
durable-publisher reuse. Those experiments are not repeated. The current
[physical-growth policy](PHYSICAL_ITERATION_POLICY01.md) is retained; its
rejected generic Hupsel shortcut is not resurrected.

A private365-day current RC3 phase profile preserves every unrounded daily
physical record and native109 endpoint exactly. Aggregate native phase wall
times are0.627s water solve,0.189s solute,0.171s roots,0.084s water update and
0.056s heat. Total instrumented model/controller is2.825s. Per-call CPU clock
quantization and profiling overhead make these diagnostics, not headline costs
or an additive complete CPU/wall decomposition.

Actual complete original/RC3 log counters confirm:

| Work | Original431 | RC3 |
| --- | ---: | ---: |
| Converged solves |38772 |38065 |
| Newton iterations |77664 |138089 |
| Backtracking cycles |77664 |138090 |

RC3 uses about78% more Newton iterations despite slightly fewer converged
solves. Its original Newton work includes the retained stricter mass/polishing
contract. This is demonstrated extra work, not proof that it explains every
second of overhead or permission to skip iterations.

## Bounded discriminators and decisions

| Private candidate | Actual result | Decision |
| --- | --- | --- |
| Selective water-block link-time optimization | Paired365-day CPU/wall benefit unresolved | Not admitted |
| Per-call exact repeated-head evaluator reuse | Exact physical/CSV/native, but slower | Rejected |
| Decimal word relay and reply-boundary transcript flush | Short apparent gain not retained over full1461-day controls | Rejected; production restored |
| Reassessed complete original Fortran block at O3 | Exact365-day physics/native but no reliable speedup | Not admitted |

The boundary full controls are baseline9.580/8.434s, candidate10.058/9.144s;
thus the short apparent8% benefit is not promoted. These are private
model/controller controls with unchanged workers and two native endpoints,
not literal public CLI wall measurements. Lower unchanged baseline times than
the prior public cohort's12.195s are **not code speedup**. A single same-session
original431 control is7.647s, with byte-identical executed inputs and exact
printed CSV to its preserved reference. It is an ordered observation, not a
randomized paired or accuracy-matched benchmark. The earlier apparent factor2
from measurements at different times is not a stable performance estimate.

The private boundary protocol probe preserves528964 actual/edge binary64 words
through the real Fortran parser at O0/O2; that correctness result alone does not
make the slower full candidate useful. Original source/compiler/input/binary
identities remain explicit. Initial source-binding/setup refusals occurred
before any model and are retained separately, not reported as numerical failure
or PASS. Frozen-source validation was used rather than rebinding foreign builds.

All model calls keep15s caps. The selected wall-cost study has25 private model
calls (short365-day controls and4 full boundary controls), plus one original
control; it starts no new reference ladder, macro or broad CI campaign. After
two failed local candidates the strategy was reassessed, then stopped when the
simpler boundary and whole-block alternatives did not justify admission.

## Preserved qualification and recovery

No production app/src delta remains. All compared observed physical/printed CSV
and native endpoints are exact to RC3, with its unchanged1e-10 water/solute
guards. The existing complete exact own-restart, rollback, external and
independent-instance evidence remains valid under unchanged dependencies;
there is no reason to repeat it after rejecting all production candidates.
O3/compiler and private memoization variants never become supported bundles.
Original scientific FAILs, reference limits and incomplete physical energy
remain unchanged. The requested performance reduction is still unresolved.

`integration/f-ci/saltfarm-rc3-cost02/RESULT.json` records all timings, actual
work counts and decisions. SELECTION/STATUS own the bounded investigation.
The raw archive/index preserve actual sources, inputs, CSV/journals, native
endpoints, logs/commands, diagnostics and failed setup evidence; compiler
products are excluded but their build identities/commands remain. Reproduction
recipes in `tests/saltfarm_cost02/` are explicitly private diagnostics. Rejected
boundary probes require the archived candidate source; they do not silently
select current production code as the old prototype.

Next work requires a genuinely distinct native-cost hypothesis rather than
repeating these candidates or treating a stricter balance guard as optional.
No additional numerical campaign or modification is selected by this closeout.
