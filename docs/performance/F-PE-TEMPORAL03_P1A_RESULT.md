# F-PE-TEMPORAL03 P1A result — dynamic-history coarse budget screen

Date: 2026-09-26

Status: `STATIONARY_FRONTIER_DOES_NOT_TRANSFER`

## Protocol

All six difficult PROFILE06 origins were converted into two physical dynamic-history states using the P0 +/-10% flux-imbalance construction.

For each dynamic history direction, signed corrector offsets were screened against the TEMPORAL02 stationary-frontier neighborhood:

- +/-0.001 cm: 2e-4, 5e-4, 1e-3 cm;
- +/-0.01 cm: 2e-3, 5e-3, 1e-2 cm;
- +/-0.05 cm: 2e-2, 5e-2, 1e-1 cm.

Each budget/magnitude group contains 24 dynamic signed-history points: six origins x two history directions x two corrector signs.

## Aggregate result

| |dh| (cm) | budget (cm) | completed |
| ---: | ---: | ---: |
| 0.001 | 2e-4 | 0/24 |
| 0.001 | 5e-4 | 0/24 |
| 0.001 | 1e-3 | 3/24 |
| 0.01 | 2e-3 | 8/24 |
| 0.01 | 5e-3 | 8/24 |
| 0.01 | 1e-2 | 9/24 |
| 0.05 | 2e-2 | 13/24 |
| 0.05 | 5e-2 | 20/24 |
| 0.05 | 1e-1 | 24/24 |

## Comparison with stationary TEMPORAL02

The stationary common frontiers were:

- |dh| 0.001 cm: 5e-4 cm;
- |dh| 0.01 cm: 5e-3 cm;
- |dh| 0.05 cm: 5e-2 cm.

Those values do not transfer to the dynamic histories.

In particular:

- at |dh| 0.001 cm, the stationary common frontier 5e-4 completes 0/24 dynamic points;
- at |dh| 0.01 cm, the stationary common frontier 5e-3 completes only 8/24;
- at |dh| 0.05 cm, the stationary common frontier 5e-2 completes 20/24, while 1e-1 is the first tested common completion budget.

## Interpretation

The temporal certificate is strongly sensitive to predecessor temporal history, not only to corrector displacement.

The P0 dynamic histories have predecessor head-rate magnitudes from roughly 20 to 1530 cm/day. That history enters the defect estimate through the difference between current and previous right derivatives.

Therefore a displacement-only budget rule is not scientifically supported.

The current evidence points toward a state/history-aware temporal acceptance scale or another exact temporal strategy.

## Decision

Do not advance the stationary TEMPORAL02 candidate budgets toward production.

Advance to P1B with an expanded budget sweep for the dynamic |dh| = 0.001 and 0.01 cm classes.

The purpose of P1B is to determine whether a bounded common frontier exists at all for small dynamic correctors, not to admit that frontier.

No production source change is authorized.