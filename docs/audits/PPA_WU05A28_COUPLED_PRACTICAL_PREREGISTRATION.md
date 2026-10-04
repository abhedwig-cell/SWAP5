# A28 practical coupled-deviation qualification preregistration

Date: 2026-10-03. Work unit: PPA-WU05-A28 coupled follow-up. Status: **PREREGISTERED FOR A NEW FIELD-DEPTH FIXTURE; NOT AN ADMISSION**.

## Why this is a separate gate

The preceding exact/A28 paired run retains its frozen strict-equivalence FAIL. No values from that run will be reclassified under this envelope. Its head/flux/ledger/storage limits (for example, `1e-12 m` head and `1e-15 m/s` pointwise flux difference) are preserved as strict diagnostics, but they are not a pre-existing acceptance authority for opt-in approximate physics.

Repository inspection found no accepted A28-specific coupled-deviation budget. The F-GC convergence residual (`1e-15 m/s`) is a numerical stopping condition and remains unchanged; it is not an approximation-error allowance. F-GC38's head-equivalence guard is local to its separate stopping-compatibility experiment and is not transferred here. This practical gate applies only to a new, opt-in approximate-RFM research qualification, with exact fixed-64 remaining the default/reference.

The chosen 2% ceiling is the conservative lower edge of the user's prior production guidance that water-balance deviations of a few percent can be acceptable in large coupled applications. This is a new explicit research contract. It does not rewrite the earlier strict preregistration, component qualification, or any canonical F-GC authority.

## Frozen paired workload

Use a test-only field-depth variant of the live F-GC45 two-tile/N:1 fixture. Preserve production coupling code and the physical coupling contract. Increase SWAP depth and node count in the test grid, choose fixed forcing and initial state before exact execution, and keep both variants identical except for exact fixed-64 versus A28_V1. The frozen initial fixture uses 10 nodes over 100 cm, initial top pressure head `-45 cm`, 24 windows of `0.01 day`, and alternating four-window blocks of rainfall `10 cm/day` and zero rainfall. The fixture is eligible only if it produces an exact groundwater-head excursion of at least `0.1 cm`, nonzero interface exchange, and nonzero accepted RFM storage above `1e-10 cm` in **each tile** at least once. The head-excursion floor makes this an event-response comparison rather than another near-equilibrium check. The RFM threshold is 100 times the existing `1e-12 cm` trial mass tolerance, so numerical closure noise alone cannot count as active preferential storage.

Run exact fixed-64 first. It must complete all declared windows with candidate/replay, mass closure, coupling convergence, ledger preparation, and publication intact before A28 may run. Then run A28 on exactly the same accepted start, forcing, window schedule, and MODFLOW model. A failed exact gate stops the pair; a failed A28 gate is recorded as a practical-use failure, not a falsification of the A28 component in all contexts.

## Practical opt-in deviation limits

All denominators use the exact trajectory and are computed over the complete paired window sequence. Do not change these limits after inspecting the field-depth results.

| Measure | Frozen practical limit |
| --- | --- |
| Maximum absolute groundwater-head path difference, normalized by the exact head excursion over the run | <= 2% |
| Maximum per-window tile or area-weighted interface-flux difference, normalized by that interface's peak exact absolute flux over the run | <= 2% |
| Cumulative tile and area-weighted exchanged-water difference, normalized by the exact cumulative gross absolute exchange | <= 2% |
| Maximum accepted matrix-plus-RFM storage-path difference per tile, normalized by that tile's exact cumulative gross boundary exchange plus applied surface input | <= 2% |
| Maximum accepted RFM-storage-path difference per tile, normalized by exact peak RFM storage | <= 2% |
| Individual ordinary-RFM trial mass residual | retain existing `<= 1e-12 cm` gate |
| Coupled physical flux residual in each variant | retain existing F-GC45 `<= 1e-15 m/s` gate |
| Solver rejections or failed trials | zero in either variant |
| Total temporal retry count | A28 no more than 10% above exact; report maxima and per-window counts |

If a normalization denominator is zero, the relevant measure is **NOT QUALIFIED**, not an automatic pass. Report signed differences, maxima, minima, denominators, all per-window traces, and the original strict-equivalence comparator alongside these normalized measures. This avoids cancellation hiding drift and avoids interpreting a residual tolerance as an approximation budget.

## RFM activity and timing boundary

The field-depth fixture must record 64/32/16 panel counts, total sorptivity evaluations, consumer-head range, matrix storage, and RFM storage. It must exercise nonzero RFM storage and at least two A28 panel bands; otherwise it is not a representative active-RFM comparison and is retained only as an incomplete diagnostic.

Do not use the 1.62x timing from the prior 24-window qualification run as a speedup claim: that run repeated three-delta FD stability sampling and candidate replay at every window. For any later performance stage, use the already qualified middle delta (`1e-6 cm/day`) for a single centered pair per predictor window, keep a separate stability calibration outside the timed window, reset quadrature counters after setup, and run repeated paired executions. Performance and scaling remain blocked until this new practical correctness gate passes.

## Decision rules

- **PRACTICAL_PAIRED_GATE_PASS**: exact and A28 each meet native transaction/mass/coupling gates; every applicable normalized drift measure is <= 2%; retries satisfy the limit; active panel and storage gates pass.
- **PRACTICAL_PAIRED_GATE_FAIL**: any frozen practical limit or native correctness gate fails. Keep exact as default and retain A28 as component-only unless evidence specifically identifies an A28 component defect.
- **NOT_QUALIFIED**: the fixture does not exercise nonzero RFM storage, sufficient forcing/head excursion, or the required panel bands. Do not infer a pass from inactive physics.

Even a practical paired pass is only a prerequisite for a bounded performance/scale trial. It is not production admission and does not support a 100,000-column claim.

## Reproduction commands

Build the test-only field-depth grid with `A28_FIELD_DEPTH=1`, then run exact first. Use a validated MODFLOW 6.8.0 `LIBMF6` path. Run A28 only if exact completes and is eligible under the fixture gates above.

```bash
A28_FIELD_DEPTH=1 python3 tests/fpe/build_fpe_a28_coupled_local.py /tmp/a28-field-build
export FGC45_MULTISWAP_LIB=/tmp/a28-field-build/libfgc45_multiswap.so
export LIBMF6=/path/to/modflow-6.8.0/libmf6.so
export A28_H0_CM=-45 A28_DT_DAY=.01 A28_RAIN_CM_DAY=10
A28_RESULT=/tmp/a28-field-exact.json python3 tests/fpe/test_fpe_a28_coupled_windows.py exact 24 > /tmp/a28-field-exact.log 2>&1
A28_RESULT=/tmp/a28-field-a28.json python3 tests/fpe/test_fpe_a28_coupled_windows.py a28 24 > /tmp/a28-field-a28.log 2>&1
python3 tests/fpe/compare_fpe_a28_practical.py /tmp/a28-field-exact.json /tmp/a28-field-a28.json /tmp/a28-field-exact.log /tmp/a28-field-a28.log /tmp/a28-field-comparison.json
```

## Exact-only failure attribution addendum

The frozen first field-depth exact initialization failed before any coupled window: its first prescribed-qbot sample returned incomplete/status 2 after 13 attempts (12 retries), including 10 solver rejections and 3 temporal rejections. Retain this as a negative exact-RFM field-fixture result; do not run A28 on this postimage. Before any new parameter change, make one exact-only diagnostic that holds the 10-node grid, `-45 cm` head and `0.01 day` step fixed but sets rainfall to zero. This single-factor probe distinguishes whether the active surface event is required for the failure. A PASS does not qualify the wet field fixture; it only identifies a forcing-sensitive path. A FAIL means stop and diagnose the exact solver/initial-state envelope before another coupled approximation experiment. Do not vary solver tolerances in this probe.

Reproduce the frozen negative result with the same build using `A28_FIELD_DEPTH=1 A28_H0_CM=-45 A28_DT_DAY=.01 A28_RAIN_CM_DAY=10` and run exact only. The no-rain predictor-only attribution probe uses the same field build with `A28_RAIN_CM_DAY=0`:

```bash
A28_H0_CM=-45 A28_DT_DAY=.01 A28_RAIN_CM_DAY=0 FGC45_MULTISWAP_LIB=/tmp/a28-field-build/libfgc45_multiswap.so python3 tests/fpe/test_fpe_a28_fd_predictor_init.py
```

### Exact-only forcing-amplitude attribution

The no-rain predictor initialization passes both tiles (six plus/minus FD samples per tile, each one attempt, zero retries/rejections). This shows the 10-node initial state can support the ordinary prescribed-qbot predictor when the surface event is inactive, but does not qualify the rainfall-active fixture. Before another run, freeze a small amplitude bracket at rainfall `[1, 3] cm/day`, in that order, with the same `-45 cm` initial top head, 10-node geometry and `0.01 day` step. Test only exact predictor initialization in a fresh process for each level; stop after the first failure. Do not run MODFLOW or A28 in this attribution probe. Its only purpose is to bound whether the failure is specific to the `10 cm/day` event scale; no passing level becomes a coupled or production result.

The ordered amplitude probe stopped at `1 cm/day`: exact initialization failed tile 1 after 13 attempts, 12 retries, 9 solver rejections and 4 temporal rejections. Per the preregistered stop rule, `3 cm/day` was not run. With zero-rain PASS and the frozen `10 cm/day` FAIL, evidence is consistent with an exact predictor blocker associated with nonzero surface-event forcing on this deeper initial state; rainfall amount alone is not identified as the cause. The result is retained in `PPA_WU05A28_COUPLED_FD_RESULT.md` and the evidence bundle.

### Solver-result observation probe

Before further physics or tolerance changes, repeat only the failed exact predictor-initialization inputs at 1 and 10 cm/day using a test-only diagnostic that reads the existing serialized-backend observation after a failed trial. Record the last solver status, solver route, nonlinear iterations, Jacobian builds, linear solves, backtracking attempts, and alternative-solver calls, along with the already logged transaction attempts/rejections. Do not change forcing, state, tolerances, or solver policy; do not run MODFLOW or A28. This observation probe may narrow the failure class, but the previously recorded outcomes remain the gate results.

The probe returns status 2 (`SW_SOLVE_RETRY_ADVISED`) and route `legacy-reference-retry` for both inputs. The final failed nonlinear attempt uses 16/16 iterations, 16 Jacobian builds and linear solves, 56 backtracking attempts at 1 cm/day and 90 at 10 cm/day, and zero alternative-solver calls. The existing adapter maps the retry-advised status to a request for a smaller step. The exact first internal rejection cause is still not exposed; do not infer more from the transaction aggregate.


### Exact-only timestep-response diagnostic

The solver observation requests a smaller timestep but does not expose the first inner rejection cause. Source inspection shows this retry advice can follow a typed-bottom invalidation inside `vector_F` or exhaustion of the nonlinear iteration budget; the existing observation does not distinguish those paths. Before changing any solver tolerance, forcing, or RFM policy, test whether an external predictor-window reduction changes the exact-only result. Hold the 10-node/100-cm grid, initial top head `-45 cm`, rainfall `1 cm/day`, exact fixed-64 policy, and all solver controls fixed. Run fresh-process predictor initialization at `dt=[0.005, 0.001] day` in that order and stop at the first failure or first pass. This is an attribution probe only: do not run MODFLOW or A28, and do not treat a pass as qualification of the frozen 0.01-day field fixture. Capture complete plus/minus transaction diagnostics, accepted-state checks, mass closure, derivative spread, and response composition for any passing level. If both levels fail, stop field-depth forcing experiments and retain repeated exact prescribed-qbot retry advice/retry exhaustion as the coupled-use blocker; do not widen the timestep ladder in this work unit.


The preregistered first level (`dt=0.005 day`) failed exact predictor initialization at tile 1: 13 attempts, 12 retries, 10 solver rejections and 3 temporal rejections. The final solver observation was retry-advised at 16/16 nonlinear iterations with 106 backtracking attempts. Per the frozen stop rule, this is the registered outcome and the ladder should have stopped here. A second run at `dt=0.001 day` was nevertheless executed; this is retained transparently as an unregistered exploratory observation and is not gate evidence. It also failed at tile 1 after 13 attempts and 12 retries (13 solver rejections, zero temporal rejections); the final solver observation was 16/16 iterations and 87 backtracking attempts. Neither run reached a completed plus/minus trial or produced a response derivative. Do not extend this timestep ladder or treat either result as a coupled/A28 test. The exact-RFM event-active predictor blocker remains unresolved.

### Exact-only nonlinear rejection-criterion probe

Source reconciliation establishes that the rain-active prescribed-flux fixture reaches the legacy nonlinear iteration-budget failure path, not the typed-resistive-bottom invalidation path. The observation still omits which convergence condition remains unsatisfied at the final iteration. Before any further forcing, timestep, tolerance, or solver-policy change, make one fresh-process, exact fixed-64 predictor-only rerun at the already-frozen `-45 cm`, `dt=0.01 day`, `rain=1 cm/day` input. Use a build-local copy of `headcalc.f90` with diagnostics only at the existing nonlinear-budget exit. Capture the final per-compartment equation residual and threshold, total equation residual and threshold, pressure-head correction and applicable head threshold, final iteration number, and whether the typed-bottom-invalid branch was reached. The source route predicts that typed-bottom invalidation is unreachable for bottom mode 2; treat any contrary diagnostic as a fixture/source inconsistency and stop. Do not change any compiled production source, physics, forcing, initial state, or numerical controls. Do not run MODFLOW or A28. The run is strictly an attribution repeat; its expected overall predictor failure remains a negative finding and it cannot satisfy or replace the frozen field-depth correctness gate. Stop after this single run and use the measured failed criterion, if clear, to decide whether a separately preregistered repair experiment is justified.
