# F-PE-TEMPORAL03 P0 result — dynamic-origin construction

Date: 2026-09-26

Status: `DYNAMIC_ORIGIN_AUTHORITY_ESTABLISHED`

## Protocol

For each of the six difficult PROFILE06 origins, two history directions were constructed using a test-only Reference-floor physical step:

- top/bottom flux imbalance = -10%;
- top/bottom flux imbalance = +10%.

The history step:

- bypassed the candidate temporal certificate;
- used the exact Reference physical backend;
- required complete mass accounting;
- generated the predecessor right derivative as `(h_end - h_start) / dt`;
- re-materialized the resulting physical state as a temporal-history committed state at the new origin time;
- re-captured the participant origin from that committed state.

Three fresh-process repetitions per origin/history direction were deterministic.

## Result

All 12 dynamic-origin configurations succeeded.

Mass residuals were at roundoff scale, roughly 1e-17 to 2e-16.

Maximum absolute predecessor head-rate magnitudes were clearly nonzero:

- B01 mid: about 43 cm/day;
- B12 wet: about 20.5 cm/day;
- B01 wet: about 803 to 805 cm/day;
- O05 wet: about 806 to 813 cm/day;
- O14 mid: about 422 cm/day;
- O14 wet: about 1523 to 1530 cm/day.

The two imbalance signs produce opposite physical history directions while remaining deterministic and mass-conservative.

## Interpretation

TEMPORAL03 is no longer restricted to the stationary zero-history origin used by TEMPORAL02.

The constructed origins provide explicit nonzero accepted predecessor derivatives derived from a physical Reference step rather than from an artificial seed.

These origins are suitable authority for the dynamic-history budget-frontier phase.

## Decision

Advance to P1 dynamic-origin temporal-budget characterization.

No production source change is authorized.