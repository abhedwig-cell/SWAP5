# Original Hupsel potato scheduled irrigation binding

The existing `mod_tcs1_dcs2_sprinkling_irrigation_process` owns the complete source timing, DAYFIX filtering, DCS2 depth and event rate/duration. The adapter binds that already implemented owner directly. No physical law is duplicated or extended.

SWAP4.3.1 `swap.f90` day-start sequence is Meteo -> croprotation -> Irrigation(3) before daily integral reset. `irrigation.f90`473-485 uses `1-(iqreddry_day+iqredsol_day)/iptra_day`, with1 when potential<=1e-10. Oxygen reduction deliberately does not enter this source trigger. Its inputs are the preceding accepted day's original process integrals. Selection and event/policy state are staged and published only with the completed water day.

The original input binds TCS1/DCS2/sprinkler, DAYFIX, tabulated threshold/depth, source dates and rate. The source fixed-depth option does not deduct rainfall; the rain threshold belongs to DCS1 and is retained as immutable input. Original DCS2 gift20mm is2cm; IRR_RATE15mm/h is36cm/day and the2cm event lasts1/18day. The water source interval must split at this event endpoint. No source process or parameter is disabled.

Executed checks: existing TCS1 process and complete110 original Hupsel active-irrigation/Rutter interval composition in O0/O2; native original potato input binding;143 actual donor season receipts with exact gift dates584/591/603, source rates/durations, staged DAYFIX and accepted-observation native restart replay. O0/O2 transcripts are identical; maximum donor gift difference4.55e-13cm is endpoint-clock rounding. No historical SWAP5 project day is claimed by this component driver.
