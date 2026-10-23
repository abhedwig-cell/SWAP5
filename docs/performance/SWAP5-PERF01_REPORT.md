# SWAP5-PERF01 runtime investigation

23 October2026 update: the [current matched-kernel comparison](PERF01_CURRENT_431_20261023_RESULT.md)
rebuilds original4.3.1 and current SWAP5 at O0/O2 and executes96 native processes.
It retains near-roundoff physical agreement and broadly similar kernel costs;
the later wet4/retry/accuracy improvements do not establish a complete
weather/crop job ratio against4.3.1. Earlier tables below retain their original
historical measurement scope.

**Status:** bounded exact implementation admitted through PR #1335 at `5eec6ae73d3187630f244109380ef6adfadfe631`. Hosted canonical, PERF01, application, NUT and FSI35 checks pass; the merge tree exactly matches the qualified source and final evidence receipt. Baseline `b0c2e94b69d7d21519611af92866fb4dbf713ea2`; reconciled canonical `5ce0f1115a5ea89be54aacaae02ed61ab2ca2696`. The later canonical PR1337 changes two NUT input providers, outside all 178 application and age/preservation build inputs. The actual reactive runner was requalified on their combination with PERF01. See `integration/performance/SWAP5-PERF01_STATUS.json` for the live admission disposition.

## Main finding

The real file-driven application repeatedly deep-copied its growing accepted flux history on append, attempt capture and rollback. This made trace maintenance quadratic in the substep count. The retained implementation replaces those copies with an immutable worker-local arena, constant-size branch cursors and one validated flat publication. The numerical solver, error estimator, tolerances, accepted state and restart layouts are unchanged.

Seven alternating paired native runs on one CPU compare the exact original SWAP5 canonical source and the candidate, with identical GNU 13.3 production O2 flags. Compilation, conversion, Python preparation and profiling are excluded. CPU includes native input/output; wall time is measured separately. All budget/state/endpoint/restart files and numerical work are identical.

| Cells | Days | Flux substeps | CPU before s [min–max] | CPU after s [min–max] | Wall before / after s | Speedup | CPU reduction |
|---:|---:|---:|---|---|---|---:|---:|
| 4 | 0.008 | 2034 | 2.342829 [2.171732–2.527490] | 0.171901 [0.157632–0.236416] | 2.343765 / 0.172752 | 13.63× | 92.7% |
| 32 | 0.008 | 1246 | 1.131964 [1.066246–1.235688] | 0.332404 [0.316252–0.363838] | 1.133882 / 0.334291 | 3.41× | 70.6% |
| 256 | 0.008 | 304 | 0.467254 [0.445582–0.535358] | 0.369843 [0.344355–0.410991] | 0.469195 / 0.371801 | 1.26× | 20.8% |

These are short synthetic positive-pond/solute columns with prescribed roots, drainage and bottom flux. They are deliberately sensitive to retry/trace costs. They are not calibrated crops, historical meteorological runs or a regional HRU throughput claim. An independent seven-pair isolation of the arena alone gave 13.79×, 3.45× and 1.22×; the table above uses the exact original canonical baseline, rather than attributing compiler or smaller HeadCalc changes to the arena. Timing variation includes host load; differences of a few percent are not established improvements.

## Original SWAP4.3.1 versus SWAP5

The archived original B1.11 SWAP4.3.1 and TTUTIL sources are actually compiled, linked and executed. The native legacy HeadCalc and boundtop use their real global grid, MvG, root/drain and boundary procedures; no legacy physics routine is stubbed. The SWAP5 driver uses the production Full Richards/HeadCalc closure. Both use 50 cells, identical explicit physical parameters, fixed 0.005-day steps and requested state/flux trace fields. Prescribed sink arrays do not constitute a live crop model. These direct kernels exclude the outer transactional/solute application. Their ratios must not be multiplied by the application speedups.

| Synthetic regime | Days | Legacy core CPU s | SWAP5 before s | SWAP5 after s | Original T5/T431 | New T5/T431 | Accepted steps | NL iterations legacy / SWAP5 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| bare | 30 | 0.157291 | 0.207132 | 0.209069 | 1.317 | 1.329 | 6000 | 18001 / 18001 |
| prescribed_roots | 30 | 0.183712 | 0.199150 | 0.216384 | 1.084 | 1.178 | 6000 | 18001 / 18001 |
| dry | 1 | 0.005692 | 0.006800 | 0.006298 | 1.195 | 1.106 | 200 | 632 / 632 |
| shallow_head | 1 | 0.008193 | 0.009705 | 0.009663 | 1.185 | 1.179 | 200 | 700 / 700 |
| rain_pulse | 3 | 0.023116 | 0.025096 | 0.024872 | 1.086 | 1.076 | 600 | 1948 / 1948 |
| prescribed_drainage | 30 | 0.194159 | 0.197211 | 0.200911 | 1.016 | 1.035 | 6000 | 18001 / 18001 |
| long_balanced | 365 | 1.358244 | 1.320827 | 1.268500 | 0.972 | 0.934 | 73000 | 102573 / 102571 |
| layered_column | 30 | 0.160429 | 0.191835 | 0.189911 | 1.196 | 1.184 | 6000 | 18000 / 18000 |

Eleven interleaved repetitions per arm at O2; full per-run CPU, core wall and total wall ranges are in `three-way/CONTROL.json`. The direct kernel is approximately at parity to 33% slower than the legacy kernel in these O2 cases. The small HeadCalc change has no robust broad speed claim: some medians regress within the observed spread. It avoids inactive macropore scratch allocation/zeroing and resolves immutable matrix scaling once per call; dynamic source-freezing remains residual-synchronous. The large gain is in the common trace architecture, which these direct-kernel ratios do not exercise.

O0 and O3 each have three interleaved repetitions for all eight regimes. O0 retains SWAP5 compiler runtime checking/FPE traps and the historical GNU compatibility/initial-zero requirements; it is a diagnostic comparison, not the production speed claim. O2/O3 use comparable optimization and the same compiler family. Exact flags/source hashes, all 408 three-way run observations and 336 additional O0/O2/O3 SWAP5 preservation observations are retained. At O0, contract/debug overhead is larger; see the complete matrix rather than extrapolating the O2 ratios.

All SWAP5 before/after direct trajectories are byte-identical, including work counters. The largest historical head difference is below 5.81e-12 cm, theta below 6.8e-15; the largest bottom flux difference is below 6.4e-12 cm/day. Independent per-step water residuals satisfy the unchanged 1e-12 cm assertion. Historical migration roundoff is reported separately from the exact implementation regression. The long case is a balanced synthetic 365-day sequence. An earlier 1000-day net-inflow pilot failed near saturation around day154; that censored run is not counted as a successful historic simulation.

## Work, rejection and step doubling

| Cells | CPU per accepted trace record before / after (s) | CPU per simulated day before / after (s/day) |
|---:|---|---|
| 4 | 0.00115183 / 0.00008451 | 292.854 / 21.488 |
| 32 | 0.00090848 / 0.00026678 | 141.495 / 41.550 |
| 256 | 0.00153702 / 0.00121659 | 58.407 / 46.230 |


| Cells | Accepted transactions / half-step trace records | Attempts / rejected | HeadCalc calls | NL iterations / Jacobians / solves | Mean / min / median / p90 / max accepted trace dt (day) |
|---:|---|---|---:|---|---|
| 4 | 1017 / 2034 | 6784 / 5767 | 20352 | 65316 / 65316 / 65316 | 3.93314e-06 / 2.70188e-06 / 3.70228e-06 / 5.23459e-06 / 6.05273e-06 |
| 32 | 623 / 1246 | 3705 / 3082 | 11115 | 36598 / 36598 / 36598 | 6.42055e-06 / 4.50205e-06 / 6.26669e-06 / 8.05816e-06 / 9.17808e-06 |
| 256 | 152 / 304 | 624 / 472 | 1872 | 5851 / 5851 / 5851 | 2.63158e-05 / 1.79334e-05 / 2.57492e-05 / 3.53063e-05 / 3.53063e-05 |

Every attempt uses one full and two half solves (HeadCalc calls = 3 × attempts). The published accepted trajectory contains two half steps per accepted transaction. All observed rejections in this matrix are temporal, with zero mass or solver rejections; eight outer checkpoint uses and zero workspace full resets/zeroed bytes are reported. The accepted counters, complete step durations and all physical files are identical before/after. Thus the retained optimization removes cost per numerical operation (explanation B), with no reduction of numerical work (A). CPU per accepted trace record and per simulated day can be obtained directly by dividing the table CPU by the trace count and 0.008 respectively; these short horizons are not annual cost forecasts.

The default canonical interval policy starts each transaction from the remaining requested interval, repeatedly rediscovering a small accepted step. A visibility-neutral diagnostic main enables the already existing opt-in `retain_accepted_step_proposal`, leaving all error/mass/rollback safeguards active. Attempts fall from 6784 to835, 3705 to541 and624 to160; HeadCalc calls from20352 to2505,11115 to1623 and1872 to480. At four cells the endpoint head changes by1.14e-4 cm, theta1.18e-7, and solute concentration3.47e-8 mg/cm3. This is a causal experiment only. It is not part of the production change, no tolerance is relaxed, and no broad seasonal/crop/HRU qualification is inferred. Reusing a previous half-solve as a new full trial would require a separate deterministic replay contract for model state, boundary proposals and historical attempt context; no generic purity or cache validity is assumed here. Safe general admission of a changed temporal route requires its own trajectory/restart and accuracy study.

## Profile interpretation and memory

PROFILE04 remains valid for its short fixture, but cannot attribute the growing-trace application. Before optimization, the actual eight-window file application samples 37.18% in trace append,19.23% context capture,17.95% context restore and6.41% context finalization. Together these dominate the sampled model code. GNU gprof misses substantial shared-library CPU: these percentages must not be called inclusive wall/CPU shares. Local internal symbols are included using `nm -n`, normalizing local `t` to `T`, then `gprof -S symbols.txt`; omitting this misattributes internal routines.

Twenty repeated candidate profile runs produce the exact same four physical files as the uninstrumented application. Candidate model samples: advance11.96%, dynamic top boundary10.87%, append10.33%, HeadCalc10.33%, MvG log1p5.43%, linear solve2.72%; capture and restore are below sample resolution (0.00%), finalization0.54%, flat materialization0.54%. The append sampled time falls from0.29s/run to0.19/20=0.0095s/run, roughly30×; capture/restore no longer deep-copy the prefix. These are sample estimates on separate profile runs. Individual mass-check and ordinary physical-state checkpoint costs are below this method's reliable resolution: UNKNOWN, not zero. No portable cache/memory-bandwidth or maximum-RSS guarantee is made.

The arena retains immutable trial branches until the outer call ends. Storage is O(successful trial records × node payload), instead of repeated quadratic prefix copies. Peak RSS is measured with a small native fork/exec/wait4 helper, avoiding Python launcher RSS inheritance. One bounded run per arm gives:

| Cells | Old peak RSS KiB | New peak RSS KiB |
|---:|---:|---:|
| 4 | 6696 | 7820 |
| 32 | 5940 | 8596 |
| 256 | 6560 | 8828 |

The memory increase is explicit. Arbitrarily long outer windows with many rejected branches remain a memory risk; existing retry/substep limits and fail-closed publication are retained. The native observer records core CPU only around the actual `run_pond_joint_interval`; counter/step output is outside it. Its own timing is not substituted for the seven-pair release speed measurement.

## Scientific preservation and admission

- Original file application:86 process observations at checked O0 and production O2, 2/4/8/32/256-cell inputs, independent budgets, frozen original restart, valid/rejected inputs, atomic generations and fresh-process restart: PASS. Current hosted run39496676035 passes the complete numeric and successor source-owner checks.
- Original transaction/sensitivity, active macropore donor, lower-boundary application and progress/restart drivers:all eight O0/O2 runs PASS with unchanged assertions. The shared resolver repairs only stale explicit build selection.
- Original age process/physical/surface runner and reactive N runner:O0/O2 PASS; native admitted mineral endpoints remain exact and decoder/rejection corpora retained. Reactive O0 requires an unlimited Linux process stack; the initial8MiB-stack segmentation failure is retained. A matched original-canonical run at the same8MiB limit fails at the same native event343, signal11 and byte-identical pre-failure stdout. See `SWAP5-PERF01_STACK_CONTROL.json`. This is a pre-existing execution constraint, not a new default-stack portability claim.
- Immutable alternate-branch restoration, replay, stale generation and invalid cursor:PASS using visibility-only access to the real private methods. No production API is widened.
- Newly reconciled canonical32-cell dry case:100 windows,0.002day,4366 accepted flux substeps; original same-horizon budget/inventory/restart assertions pass O0/O2, and all four model files match the prior canonical evidence byte for byte.
- No physical formula, dK/dh policy, nonlinear criterion, step-doubling criterion, mass assertion, public accepted-state/restart schema or RossFast qualification changes. A geometry-copy trial and prepared MvG origin cache were rejected on measured cost; the cache is absent from production and retained only as a rejected patch/diagnostic.

The registered bounded successor re-runs the original atmosphere/source authority unchanged in an exact clean current canonical predecessor and its original authority chain, validates current executed provider hashes and raw evidence, and rejects missing/corrupt/current-source drift controls. The original scientific assertions are not edited. Only an explicit entry handoff selects the successor. A source-bound pass qualifies this exact implementation scope, not a whole-master or full physical migration promotion. Hosted compile-selection failures in unrelated/stale lists are recorded separately; no failed gate is relabelled PASS. Merge requires the actual owning admission checks to succeed.

The original FSI35/FKT15 typed-solver owner additionally passes its full O0/O2 native immutable oracle, including standalone/worker dispatch, hard mass, surface regimes and rejected trials. Its original assertions remain unchanged; exact HeadCalc registration selects the new bound proof. The original EB-I25 outflow fixture is a retained limitation: repairing only its compile dependency selection reaches the same failing outflow assertion on original canonical b0c2e94b and PERF01. This previously nonadmitted route is not given a PASS or hidden by the performance change. Frozen publication byte-lock and stale build-list failures are itemized in `SWAP5-PERF01_HOSTED_4238.json` separately from the current owning numeric/source checks.

## Reproduction and evidence

The selected evidence capsule is `integration/performance/evidence/perf01-current-20261020/INDEX.json`:concatenate its base64 parts, decode, and open the xz tar. `MEMBERS.json` binds every selected member. It contains every timing observation, compiler/provider receipt, original test output, all application states/budgets/restarts, failed/censored logs, step/counter CSVs, model profiles, complete short dry/wet hydraulic traces and hashes of every complete long sequence. Large repeated binary trajectories and object/executable files are omitted; regenerate them with the versioned drivers. The uncompressed full hydraulic sequences remain available in the local run directory for this session.

```bash
# GNU13 compiler, Python3 and NumPy for the direct hydraulic comparison
git worktree add --detach /tmp/perf01-baseline b0c2e94b69d7d21519611af92866fb4dbf713ea2
python tools/solute/build_column.py --source-tree /tmp/perf01-baseline --build-profile production --output /tmp/perf01-before
python tools/solute/build_column.py --build-profile production --output /tmp/perf01-after
python tools/performance/benchmark_perf01_build_profiles.py --before /tmp/perf01-before --after /tmp/perf01-after --output /tmp/perf01-timings --repeat 7
python tools/performance/observe_perf01_column.py --before /tmp/perf01-before --after /tmp/perf01-after --benchmark /tmp/perf01-timings --output /tmp/perf01-observe
python tools/performance/run_swap5_perf01.py --baseline-tree /tmp/perf01-baseline --output /tmp/perf01-kernels --repeat 7 --optimizations O0 O2 O3
python tools/performance/build_swap431_perf01.py --help
# Build legacy at O0/O2/O3; compare using compare_swap431_perf01.py --help.
python -B integration/performance/authority.py
python -B integration/performance/authority.py --self-test
```

Build, link, preparation, native execution and validation timings are retained by category in the manifests; unavailable subcategories remain UNKNOWN. Interrupted disk-full historical repeats and the initial failed default-stack nutrient run are not included as successes. The bounded rerun completed after retaining repeated hashes and removing only duplicate trajectory payloads.

## Remaining suitability boundary

The [fresh temporal proposal study](SWAP5-PERF01_TEMPORAL_STUDY.md) retains 170
native observations including two deliberately reproduced strict-endpoint
failures. Wet/pulse cases gain 3.60 to 7.22 times, while the dry route remains
2.27 times slower even with an isolated diagnostic endpoint correction. No
production default or runtime module changes. The optional policy is not
generally admitted; solver-aware stepping and exact endpoint semantics require
their own scientific qualification. These fresh measurements replace a lost
unpushed temporal-study bundle and must not be confused with the originally
admitted exact implementation evidence above.

The measured multi-fold trace bottleneck is removed without changing model outcomes. For equal fixed-step hydraulic work, SWAP5 is near the legacy speed but does not consistently match it. Excess temporal retry/full-half work remains a separate major cost. A real regional reference was found in LWKM commit `a6787b9d9620f037332b2dd2babbdd9a778ecd1f`, Work C2:101 original Intel-engine runs over354 days. The content-addressed archive was inspected and HRU7866 input hashes recovered. Its active crop, PM meteorology, rain duration, drainage, BBC lower boundary and heat route cannot be executed equivalently by the current benchmark application: the SWP probe fails closed at its required column namelist, and the documented application supplies prescribed sinks/qbot rather than the full seasonal orchestration. The selected archive also omits the hash-identified MET bytes, which require their parent source archive. See `SWAP5-PERF01_REGIONAL_ASSESSMENT.json`. The earlier `control_runs(2).zip` contains NHI/MODFLOW meteorological control data, not a complete SWAP package. Existing Intel runtime measurements are not compared with the GNU benchmark. No real regional or historical-meteorological SWAP5 run is qualified here. Prescribed sinks and a synthetic annual column do not meet that missing envelope. SWAP5 therefore cannot yet receive an unconditional large-scale HRU/regional performance qualification from these results; use the existing admitted physical scope and qualify representative regional jobs before capacity planning. No single favorable benchmark stands for every model.
