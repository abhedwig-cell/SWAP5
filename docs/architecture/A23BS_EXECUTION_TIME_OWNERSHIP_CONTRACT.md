# A23BS Execution-Time Ownership Contract

## Decision

SWAP5 kernel time remains a generic interval `[t0,t1]`. A day, month, year or midnight is not a fundamental kernel step. A23BS therefore does not replace generic time with a calendar object.

A23BS separates two concerns that legacy SWAP mixes in module globals:

1. **execution window, worker-owned and attempt-local**: requested `t0`, `t1` and the temporary legacy projection used by the B1.6 adapter;
2. **legacy calendar projection, adapter-only**: `t1900`, `t`, `tcum`, `timjan1`, `daynr`, `daycum`, `iyear`, `imonth`, `date`.

The legacy projection is captured/restored per logical column only because the B1.6 singleton still reads those variables. It is migration state, not the intended SWAP5 kernel API.

## Day-boundary events

`variables%fldaystart` and `variables%fldayend` are removed from the transformed source. `TimeControl` derives `worker%time%day_start_event` and `worker%time%day_end_event`. Only legacy processes that really require a calendar boundary receive those events. `HeadCalc`, `integral` and `swap` no longer consult global day flags.

The events are not checkpointed as persistent column state. They are recomputed within the execution attempt from its time progression.

## Transactional rule

Before each physical trial the adapter restores the column's explicit legacy time projection and seeds the worker execution window. Rejected trials cannot commit calendar/progression mutation. A later trial starts from its own committed projection.

## Qualification

- B1.6 full continuation endpoint is byte-identical.
- O0 and O2 physical logs are byte-identical.
- Poisoned legacy time globals and poisoned worker day events do not affect either of two interleaved logical columns.
- `jacobian_F()` is byte-identical to A23BR.
- Eight worker time contexts pass 8,000 parallel isolation checks with zero failures.

## Explicit boundary

A23BS does **not** claim that the legacy backend is calendar-free. Many B1.6 routines still read `t1900`, `tcum` and calendar counters. They remain adapter/backend projection until those process APIs are migrated. This is compatible with invariant 9 because the new transaction/kernel contract itself remains `[t0,t1]`, and calendar events stay process-specific.
