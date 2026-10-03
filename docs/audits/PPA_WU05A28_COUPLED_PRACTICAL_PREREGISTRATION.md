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
