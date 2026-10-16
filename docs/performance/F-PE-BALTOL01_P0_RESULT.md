# F-PE-BALTOL01 P0 result — broad dynamic Reference tolerance matrix

Date: 2026-09-26

Status: `FIXED_RATE_TOLERANCE_RECOVERY_CONFIRMED_BUT_DT_SCALING_REMAINS`

## Protocol

1200 certificate-free Reference-floor solves were executed:

- six difficult origins;
- two accepted dynamic-history directions;
- four signed prescribed-head corrector offsets;
- five step durations from 1e-4 to 6.25e-6 day;
- five compartment/total balance-rate tolerances from 1e-12 to 1e-10 cm/day.

Head tolerances and all other numerical/physical controls were unchanged.

## Aggregate completion

| balance-rate tolerance (cm/day) | completed | recovered 1e-12 failures | lost 1e-12 successes |
| ---: | ---: | ---: | ---: |
| 1e-12 | 113/240 | 0 | 0 |
| 2e-12 | 156/240 | 43 | 0 |
| 5e-12 | 209/240 | 96 | 0 |
| 1e-11 | 236/240 | 123 | 0 |
| 1e-10 | 240/240 | 127 | 0 |

## Physical overlap

No looser tolerance loses a point that succeeds at the strict 1e-12 control.

Across successful arms, maximum differences versus the strictest successful arm for each physical point remain negligible:

- at 2e-12: max |dh| ≈ 4.05e-13 cm, max |dtheta| ≈ 1.67e-16, max terminal-flux difference ≈ 4.44e-12 cm/day;
- at 5e-12: max |dh| ≈ 5.95e-13 cm, max terminal-flux difference ≈ 1.78e-11 cm/day;
- at 1e-11: max |dh| ≈ 5.95e-13 cm, max terminal-flux difference ≈ 3.55e-11 cm/day;
- at 1e-10: max |dh| ≈ 9.93e-13 cm, max |dtheta| ≈ 2.22e-16, max terminal-flux difference ≈ 3.55e-11 cm/day.

Successful mass accounting remains complete.

## Remaining fixed-tolerance failures

The four points that still require 1e-10 all occur at the smallest tested step duration, 6.25e-6 day.

This is consistent with the admitted PUB-P2E06/P2E07 authority that the Reference residual is a rate in cm/day and that `dt * numerical_floor` remains on an approximately fixed integrated-depth scale.

## Historical reconciliation

PUB-P2E07 found an estimated numerical floor dominated by theta input representation with:

`dt * estimated_floor ≈ 2.8e-16 to 1.1e-15 cm`

in its frozen Reference failure domain.

The BALTOL01 P0 result therefore does not support selecting 1e-10 cm/day merely because it is the first fixed arm with 240/240 completion.

A dt-scaled integrated-floor policy is the more principled next hypothesis.

## Decision

Advance to P1.

P1 will compare fixed-rate tolerances with preregistered integrated-floor scaling of the form:

`tol_rate = max(1e-12 cm/day, floor_depth / dt)`

using depth scales anchored to the admitted P2E07 range.

No production tolerance change is authorized.