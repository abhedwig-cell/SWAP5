# F-PE-MIQUAL04 closeout — dynamic-top runoff/ponding qualification

Date: 2026-10-01

Final status:

`MIQUAL04_REFERENCE_COVERAGE_INSUFFICIENT`

MIQUAL04 is closed without adaptive manager exposure.

The five-day dynamic-top bank is not a viable manager qualification domain because WET/PONDING full-reference trajectories fail before 4,000 intervals.

The provider does reach real ponding and linear runoff before those failures, so the next useful question is bounded event-window equivalence, not retuning the manager.

Direct successor:

`F-PE-MIQUAL05 — dynamic-top pre-failure event-window qualification`

Freeze 64 intervals (0.08 d at dt=0.00125 d), preserving all MIQUAL04 numerical and physical settings.

This horizon is below the earliest exposed WET reference failure (after 81 accepted intervals) and is long enough for at least the B12 WET/PONDING cases to exercise ponding/runoff.

Production boundary unchanged:

- moving-interface manager explicit opt-in;
- `LEGACY_NUMERICS` remains production default.
