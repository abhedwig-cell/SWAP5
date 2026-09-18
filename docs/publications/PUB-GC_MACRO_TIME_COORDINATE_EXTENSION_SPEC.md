# PUB-GC macro-window temporal-coordinate extension specification

Status: **frozen before implementation**

Publication owner: `PUB-GC`

Qualification ID: `PUB-GC-MACRO-WINDOW-QUAL-0002`

Decision authority:
`docs/publications/decisions/PUB-GC_MACRO_TIME_COORDINATE_ADJUDICATION.md`

Baseline qualified component:
`research/pub-gc-macro-window-response@32d1e9ae1bb3f0cda7a26e114eca0fe5fd900d12`

Baseline module blob:
`920b93b943ead1187887e683c50a84e0f4cb3a46`

Frozen production source tree:
`d7ef6c045263de821db7800459289efcd8a6420b`

## Required implementation delta

The research macro component shall:
1. validate nominal native-duration closure using compensated relative summation;
2. construct each native absolute boundary from `macro_t0 + elapsed` rather than chained absolute additions;
3. set the final native end boundary exactly to supplied `macro_t1`;
4. expose `actual_native_dt_day(:)` and `max_abs_native_dt_representation_error_day`;
5. require every represented interval to be finite and positive;
6. require the final disposable committed time to be bitwise equal to supplied `macro_t1`;
7. retain every existing state/origin/isolation/conservation behavior.

No production file may change.

## Qualification

Re-execute all existing Q0-Q7 oracles unchanged.

Add Q8A:
- origin 4200.125 d;
- duration 0.04 d;
- 16 x 0.0025 d;
- constant qualification-only forcing;
- bottom head -80 cm.

Add Q8B:
- same, 32 x 0.00125 d.

Add Q8C:
- origin 14200.125 d;
- duration 0.04 d;
- 32 x 0.00125 d;
- same relative qualification-only schedule.

For Q8A/B/C require:
- completed response;
- expected native contribution count;
- all actual represented durations finite and positive;
- final disposable time exact to macro_t1;
- authoritative origin unchanged;
- nominal/actual duration telemetry available;
- no production source drift.

Q8 telemetry is qualification-only and may not be used to tune NATIVE-TIME-0002 or H2/H3 cases.

O0/O2 scientific-output identity remains mandatory.

## Allowed mutations

Create branch:
`research/pub-gc-macro-time-coordinate`

from:
`32d1e9ae1bb3f0cda7a26e114eca0fe5fd900d12`.

Allowed paths:
- `tests/publication/pub_gc/macro_window_response/**`
- `.github/workflows/pub-gc-macro-time-coordinate-qualification.yml`

All `src/**` and all other qualified publication components are immutable.

## Pass meaning

PASS qualifies the revised **research-only temporal representation** for macro-window response evaluation.

PASS does not establish H2, H3, MODFLOW transfer, production admission or solver-performance claims.
