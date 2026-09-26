# F-PE-DIR01 Repair04 preregistration — compact trajectory-only attempt context

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Evidence authority:
- post-Repair03 directional heap delta remains +20 malloc, +4 calloc and +24 free per interval;
- the largest remaining byte-volume source is `fmr_serialized_capture_attempt_context`;
- two full `fmr_serialized_attempt_context_t` allocations per interval account for approximately 1744 bytes;
- in the qualified bottom-head fixture, attempt context is required by trajectory direction while drainage and thermal attempt-context owners are inactive.

## Exact hypothesis

The serialized backend currently allocates the full attempt-context type even when only accepted-trajectory direction requires rollback state.

A smaller dynamic attempt-context type containing only the trajectory rollback state should preserve generic transaction semantics while avoiding copying and allocating unrelated carrier fields.

## Experiment boundary

Before any production edit:

1. create a test-local backend source variant;
2. add a compact `fmr_serialized_trajectory_attempt_context_t` extending `transaction_attempt_context_t`;
3. use it only when all of the following are true:
   - trajectory direction is requested;
   - drainage response is inactive;
   - bottom thermal carrier is inactive and valid;
   - top sensible boundary carrier is inactive and valid;
4. otherwise retain the existing full `fmr_serialized_attempt_context_t`;
5. restore the trajectory state from the compact context without changing generic transaction-core code.

## Required preservation

Require exact agreement for:
- physical checksum;
- accepted bottom-exchange derivative;
- accepted pressure-head/water-content direction publication where exposed;
- accepted-step count;
- backsolve count;
- nonlinear/Jacobian/linear diagnostics;
- transaction status and accepted route;
- mass residual;
- non-directional behavior.

The compact route must fail closed to the existing full context whenever any non-trajectory attempt-context owner is active.

## Performance admission

Production changes are allowed only if:
- the expected attempt-context byte reduction is observed;
- paired same-run timing is stably speed-positive;
- no additional heap allocation class is introduced;
- all preservation checks pass.

If the gain is not material, keep the full context and move to the next measured local target.
