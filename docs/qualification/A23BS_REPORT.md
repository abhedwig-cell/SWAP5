# A23BS Qualification Report

Status: `PASS_GENERIC_TIME_CONTEXT_AND_WORKER_CALENDAR_EVENTS / LEGACY_CALENDAR_PROJECTION_REMAINS_ADAPTER_ONLY / PHYSICAL_BACKEND_SERIAL_ONLY`

## Scope
A23BS continues A23BR without changing physics or numerical policy. It removes global day-start/day-end control, introduces an explicit worker execution-time context, and makes the remaining legacy calendar progression replayable per logical column. The transaction model continues to receive generic `[t0,t1]`.

## Source ownership result
- Removed: `variables%fldaystart`, `variables%fldayend`.
- Worker-derived: `day_start_event`, `day_end_event`.
- Worker execution-time layout (GNU Fortran 14): 40 B.
- Hupsel legacy calendar projection: 59 B raw payload per logical column.
- The 59 B projection is adapter migration state, not intended target kernel state.

The transformed source contains zero active `fldaystart` or `fldayend` references. Remaining legacy references include t1900=136, tcum=20, timjan1=18, daynr=45, daycum=31.

## Physical reference gate
O0/O2 physical logs are byte-identical with SHA-256 `a01fa12b34777546cb4ec2c3da03169e12fd9d3d4c428768fa83b68e1203cc93`.

- B1.6 endpoint: `4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9`
- accepted storage: 7.7011710672204643E+01 cm
- mass residual: -1.7872350177583485E-07 cm
- total/accepted internal retries: 20 / 10
- total/accepted Newton iterations: 956 / 478
- total/accepted HeadCalc calls: 162 / 81

The mass residual remains below the qualified B1.6 hard criterion of 1e-6 cm.

## Time-projection poison/interleaving gate
Before each interleaved logical-column advance, legacy `dt`, `t1900`, `t`, `tcum`, `timjan1`, day counters, year/month/date and worker day events are deliberately poisoned. Both columns still reproduce their independent serial state and diagnostics exactly. Gate: `A23BS_TIME_PROJECTION_POISON PASS`.

## Jacobian
`jacobian_F()` SHA-256 is `9ba4ada31fe629a006d47f30d77b8c6f8a200b232a91483b31735a6b53fb38cb`, byte-identical to A23BR.

## Worker isolation
8 workers x 1000 checks = 8000 checks, zero failures. Solver scratch remains 3292 B per worker. The separate execution-time control object is 40 B per worker.

## Architectural interpretation
A23BS advances invariants 7, 9 and 29: rejected trials cannot leak time progression, time is represented by the kernel as `[t0,t1]`, and day-boundary semantics are derived process events rather than global assumptions. It also keeps I/O/calendar conversion inside the legacy adapter/backend boundary.

## Remaining limitations
The B1.6 physical backend remains serialized and still contains many direct calendar/time references. The Hupsel verification bridge currently accepts integer-day windows. No selective step-doubling change is included.
