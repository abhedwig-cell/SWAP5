# F-PE-DIR01 post-Repair05 rebaseline

Date: 2026-09-26

Status: `QUALIFIED_POSTIMAGE_BASELINE`

Postimage:
Repair01 + Repair03 + Repair05 on `work/f-pe-dir01-bottom-head-tangent`.

## Bottom-head directional runtime

Current non-profiled bottom-head measurement:

- Reference median: `8737.9084 ns/interval`;
- directional median: `15105.8220 ns/interval`;
- directional / Reference ratio: `1.728768638`;
- directional increment: approximately `+72.88%`.

The physical solve diagnostics remain unchanged:

- nonlinear iterations per solve: `1`;
- constitutive evaluations per physical solve: `2`.

Compared with the pre-DIR01 PROFILE04 result of approximately +86-88%, DIR01 has materially reduced the directional surcharge while preserving the physical solve.

The percentages are not subtracted as an additive performance accounting claim because the measurements were made on different hosted runners. The valid conclusion is directional: the same qualified route is materially cheaper on the new postimage.

## Repair05 mechanism

Current gprof attribution shows:

- Reference default-MvG `evaluate_demand`: approximately `1,500,303` calls;
- directional default-MvG `evaluate_demand`: approximately `1,500,303` calls.

Before Repair05, directional carried approximately 1.5 million additional calls on the same 500,000-interval workload, corresponding to three extra value-provider passes per interval.

Repair05 therefore removes the intended repeated constitutive value pass exactly.

## Remaining heap traffic

Directional minus Reference on the current postimage:

- malloc: `+20` per interval;
- calloc: `+4` per interval;
- free: `+24` per interval;
- malloc bytes: approximately `+2210` bytes per interval;
- calloc bytes: `+128` bytes per interval.

Largest allocation groups:

1. `solve_with_accepted_step_direction`
   - two sites × three allocations per interval;
   - outgoing directional vectors.

2. `fmr_serialized_capture_attempt_context`
   - largest byte volume;
   - generic rollback/commit ownership.

3. `begin_or_continue_trajectory`
   - trajectory vector initialization for independent transaction branches.

4. publication/kernel result transfer
   - small final accepted-result vector copies.

Repair01 and Repair03 have already removed twelve directional malloc/free cycles per interval relative to the original DIR01 baseline.

## Current function profile

On the post-Repair05 directional workload, notable self-time includes:

- `fmr_serialized_advance`;
- physical `headcalc`;
- fused `evaluate_b110_default_mvg_state_direction`;
- `solve_with_accepted_step_direction`;
- final `evaluate_b110_default_mvg_water_content_direction`;
- transaction and temporal-indicator work.

The raw tangent tridiagonal backsolve remains small.

Publication and accepted-result transfer are visible but small relative to the full directional increment.

## Exact-headroom assessment

The remaining ~73% directional increment must not be interpreted as ~73% removable overhead.

It contains:

- actual exact tangent mathematics;
- accepted-trajectory composition across full/half/half solves;
- rollback-safe transaction context;
- derivative publication semantics;
- a smaller residual of repeated allocation/copy work.

DIR01 tested the main exact-removal classes:

- result/pending ownership duplication: Repair01, retained;
- generic accepted-half context shortcut: Repair02, rejected;
- incoming request-vector allocation: Repair03, retained;
- context payload compaction: Repair04, rejected as not material;
- duplicated default-MvG base-value pass: Repair05, retained;
- reuse of accepted candidate capacity: Repair06, rejected because workspace provenance is stale.

The remaining local allocation opportunities are individually smaller than already-tested Repair03 and comparable to or smaller than the rejected Repair04 class.

## Decision signal

The post-Repair05 map no longer identifies a clearly large exact-P0/P1 repair that is both:

- semantically local and safe; and
- likely to yield more than a few percent.

Further exact work would therefore become increasingly speculative and fragmented.

This postimage supports closing DIR01 and moving the performance program to a separately preregistered practical / approximate MultiSWAP phase.
