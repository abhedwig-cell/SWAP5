# F-PE-DIR01 repair target 02 — remove accepted-half attempt-context round-trip

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Evidence authority:
- PROFILE04: bottom-head directional adds approximately 86-88% over Reference;
- DIR01 heap attribution before REPAIR01: +32 malloc, +4 calloc, +36 free per interval;
- REPAIR01 removes six malloc/free cycles and gives only about 0.8-0.9% runtime gain;
- after REPAIR01, directional still carries +26 malloc, +4 calloc and +30 free per interval;
- the largest remaining allocation payload is transaction attempt-context capture/restore.

## Exact hypothesis

For the external full-half transaction route, after successful `half2`:

1. `model%advance(...half2...)` leaves the model attempt-context at the accepted half2 endpoint;
2. the transaction core captures that state into `half_context`;
3. only read-only storage, accounting and temporal checks follow;
4. on acceptance, the same `half_context` is restored immediately before committing `half_state`.

The capture/restore round-trip appears redundant on the accepted route.

On rejection, the transaction core already restores `checkpoint_context`, so `half_context` is not required for rollback.

## Experiment

Before any production edit, build a test-local candidate copy of
`src/transaction/mod_transaction_reference.f90` that:

- removes the `half_context` local;
- removes the post-half2 `capture_attempt_context(half_context)`;
- removes the pre-commit `restore_attempt_context(half_context)`;
- changes nothing else.

Compare against the current DIR01 REPAIR01 postimage.

## Preservation requirements

The experiment must preserve exactly:
- physical checksum;
- accepted bottom-exchange derivative;
- accepted pressure-head and water-content direction vectors where exposed;
- accepted-step count;
- accepted backsolve count;
- transaction status, attempts, retries, commits and accepted route;
- mass residual;
- nonlinear, Jacobian and linear solve diagnostics.

The non-directional route must remain unchanged.

## Admission rule

Do not modify production transaction code unless:
1. paired runtime shows a stable gain beyond timing noise;
2. heap attribution confirms removal of the predicted context allocation/copy work;
3. all transaction and directional preservation gates pass.

If the gain is small or semantics are not provably preserved, abandon REPAIR02 without broadening it.
