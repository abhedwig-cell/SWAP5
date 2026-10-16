# F-PE-DIR01 post-Repair03 rebaseline

Date: 2026-09-26

Status: `MEASURED`

Current DIR01 postimage:
- Repair01 retained;
- Repair02 rejected and reverted;
- Repair03 retained.

## Current bottom-head directional timing

A fresh current-postimage bottom-head measurement gave:
- Reference median: `6226.8946 ns/interval`;
- directional median: `11838.9322 ns/interval`;
- directional / Reference ratio: `1.901257844`;
- incremental cost: approximately `+90.1%`.

This ratio is **not** interpreted as evidence that Repair03 increased cost. The pre-Repair03 and post-Repair03 ratio measurements were taken on different hosted runners and the absolute Reference timing shifted substantially. The paired pre/post Repair03 qualification remains authority for Repair03 itself.

The robust conclusion is only that a large directional overhead remains after Repair01 + Repair03.

## Current heap delta: directional minus Reference

Per application interval:

- malloc: `+20`;
- calloc: `+4`;
- free: `+24`;
- malloc bytes: approximately `+2210 bytes`;
- calloc bytes: `+128 bytes`.

This is down from the original DIR01 map:
- +32 malloc;
- +4 calloc;
- +36 free;
- +2594 malloc bytes;
- +128 calloc bytes.

Thus Repair01 + Repair03 together have removed 12 directional-only malloc/free cycles per interval and 384 bytes of repeated malloc traffic.

## Remaining callsite map

Largest remaining directional-only allocation sources:

1. `fmr_serialized_capture_attempt_context`
   - two allocations per interval;
   - approximately 872 bytes each for the full serialized attempt-context object;
   - by far the largest remaining byte-volume source.

2. `solve_with_accepted_step_direction`
   - two outgoing direction-vector allocations per internal step;
   - six allocations per full-half application interval.

3. `begin_or_continue_trajectory`
   - pressure-head and water-content trajectory vectors are allocated after transaction context restoration;
   - four allocations per application interval in the measured path.

4. publication / kernel-result transfer
   - final direction-vector publication still allocates/copies two arrays per interval;
   - additional small result-carrier copies remain.

## Decision

The next exact target should not touch generic transaction semantics.

The next measured target is the oversized serialized attempt-context representation used when the only active rollback feature is accepted-trajectory direction.

A dedicated compact trajectory-only context can be tested without changing:
- transaction core;
- rollback protocol;
- accepted physical state;
- mass accounting;
- tangent equations.

This target is preregistered separately as Repair04.
