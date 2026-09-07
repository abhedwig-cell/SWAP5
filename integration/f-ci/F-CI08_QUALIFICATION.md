# F-CI08 Qualification — Physical Process Continuation State

## Decision

**PASS_PHYSICAL_PROCESS_CONTINUATION_HUPSEL_WHOLE_DAY_SUBDAY_BLOCKED**

F-CI08 admits a compact persistent B1.10 process-continuation state and keeps legacy trial bookkeeping in worker-local attempt context. It does not admit generic physical sub-day continuation.

## Qualified boundaries

- Water, soil temperature, solute, configured irrigation continuation, crop continuation including `rdpot`, and WOFOST continuation are persistent only when their physics is active.
- Meteorological/thermal forcing cursors, numerical time control, reporting, accounting, irrigation event workspace and mutable `schedule` projection remain worker-local rollback context.
- WOFOST state is captured for an active WOFOST crop before emergence as well as after emergence. WOFOST rates are not persistent state.
- Restore is fail-closed when active physics/configuration does not match the optional state carried by the checkpoint.
- `noddrz_old` is not admitted as persistent state for the qualified whole-day route because it is refreshed before use on that route; arbitrary sub-day checkpoints remain unqualified.

## Executed gates

| Gate | Result |
|---|---|
| Canonical F-CI03–F-CI08 CI, run `34088797066` | PASS |
| F-CI08 O0/O2 attempt-context + process/capsule gate | PASS |
| Exact B1.10 source manifest, 63 files / 1,863,575 bytes | PASS |
| Hupsel restore/rerun offsets 499, 520, 760, 800 at O0 | 4/4, zero process diff |
| Same offsets at O2 | 4/4, zero process diff |
| O0 versus O2 replay outcome | identical zero-diff result |

The source-bound physical replay uses the F-CI06-qualified GNU compile-equivalent B1.10 source-port representation. The transaction algorithm itself is qualified independently by the exact canonical CI gate; the physical replay binary uses only an ABI-compatible transaction-state type seam and therefore does not claim transaction-algorithm coverage.

## Harness correction

An initial local replay reported false failures at offsets 499 and 520. Raw state inspection showed no state difference. The cause was Fortran logical precedence in an unparenthesized `.neqv.`/`.or.` expression in the comparison harness. Parenthesizing each equivalence test removed the false positive. No production source was changed for this correction.

## Open qualification items

1. Generic physical sub-day continuation.
2. `noddrz_old` and any state relevant only when checkpoints can occur inside a legacy day.
3. Binding the B1.10 physical backend to the canonical `transaction_model_t`/attempt-context interface.
4. Canonical unrounded accepted-interval mass inputs/outputs and B2 result admission.
