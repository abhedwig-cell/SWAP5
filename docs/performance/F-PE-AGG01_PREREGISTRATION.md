# F-PE-AGG01 — single-tile aggregation allocation elimination

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Canonical parent:
`integration/f-ci-canonical@933ea3824c9fbfe74c551d6d6fe8144f39b6c378`

Branch:
`work/f-pe-agg01-single-tile-allocation`

## Trigger

In `application_context_trial_cell_heads`, each groundwater cell currently allocates and deallocates a temporary `exchanges(:)` array before calling `aggregate_groundwater_cell_tiles`.

For a one-tile groundwater cell this means:
- allocate length-1 array;
- populate one exchange record;
- aggregate;
- deallocate;

for every cell, every trial.

At large N with one tile per cell this produces O(N) heap allocation/deallocation operations per trial.

## Candidate

For `tile_count == 1` only:
- use a fixed local `single_exchange(1)` array;
- populate it with the same fields;
- call the existing `aggregate_groundwater_cell_tiles` unchanged;
- preserve all existing validation and Kahan aggregation semantics.

For `tile_count > 1`:
- keep the current allocate/populate/aggregate/deallocate path unchanged.

Apply the same bounded branch in both serial and parallel application-context aggregation paths.

## Qualification

Paired baseline/candidate production-shaped groundwater trial at:
- N=1,000;
- N=10,000;
- N=40,000.

Primary:
- 4 workers.

Secondary:
- 1 worker at N=10,000.

Five repetitions after warm-up.

Semantic requirements:
- exact q checksum;
- exact tangent checksum;
- deterministic repeated output;
- same success/failure behavior.

## Performance gates

Advance only if:
- N=1,000 candidate <=1.02 * baseline;
- N=10,000 worker=4 speedup >=1.05x;
- N=40,000 worker=4 speedup >=1.10x.

If it helps less than these bounds, close the allocation route as low return.

## Production boundary

Research-only compiled source copy.
No production `src/**` change before qualification.
No physics, aggregation mathematics, tolerances, temporal policy, tangent mathematics, scheduling, transaction or publication semantics change.


## Preregistration amendment before measurement

This amendment is made before any AGG01 performance result is observed.

Instead of a special fixed array only for `tile_count == 1`, use one reusable temporary `exchanges` buffer per `trial_cell_heads` call:

- allocate once to the maximum tile_count across the active cells;
- populate only `exchanges(1:tile_count)` for the current cell;
- call the existing `aggregate_groundwater_cell_tiles` on that slice;
- do not allocate/deallocate inside the per-cell loop;
- keep the aggregator itself and all validation semantics unchanged.

This is strictly more general than the original candidate and targets the same preregistered cost mechanism: repeated per-cell heap allocation/deallocation. The performance gates remain unchanged.
