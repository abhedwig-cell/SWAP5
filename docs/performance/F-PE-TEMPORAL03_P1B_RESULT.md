# F-PE-TEMPORAL03 P1B result — expanded dynamic-history budget frontier

Date: 2026-09-26

Status: `COMMON_DYNAMIC_FRONTIER_FOUND_AT_LARGE_BUDGET`

## Protocol

All six difficult origins, both physical history directions and both corrector signs were screened.

Each budget row therefore contains 24 dynamic signed-history points.

## Result

### |dh| = 0.001 cm

| budget (cm) | completed |
| ---: | ---: |
| 2e-3 | 8/24 |
| 5e-3 | 8/24 |
| 1e-2 | 10/24 |
| 2e-2 | 18/24 |
| 5e-2 | 21/24 |
| 1e-1 | 23/24 |
| 2e-1 | 24/24 |

First tested common completion budget: `0.2 cm`.

### |dh| = 0.01 cm

| budget (cm) | completed |
| ---: | ---: |
| 2e-2 | 16/24 |
| 5e-2 | 20/24 |
| 1e-1 | 24/24 |
| 2e-1 | 24/24 |

First tested common completion budget: `0.1 cm`.

## Non-monotone local behavior

Individual points can be non-monotone in completion as budget changes. For example, some O14 dynamic cases complete at one intermediate budget, fail at the next, and complete again at a larger budget.

This is consistent with the transaction policy changing accepted/retry paths, which can move the subsequent Richards solves into different nonlinear regimes.

Therefore the budget cannot be treated as a simple monotone scalar accuracy knob at the point level.

## Comparison with stationary origins

Stationary TEMPORAL02 common frontiers were:

- |dh| 0.001 cm: 5e-4 cm;
- |dh| 0.01 cm: 5e-3 cm.

Dynamic common frontiers are therefore roughly:

- 400x larger at |dh| 0.001 cm;
- 20x larger at |dh| 0.01 cm.

The predecessor derivative dominates the certificate scale in these dynamic tests.

## Decision

Replicate the dynamic frontier boundaries in P1C:

- |dh| 0.001 cm: compare 0.1 and 0.2 cm;
- |dh| 0.01 cm: compare 0.05 and 0.1 cm.

Do not consider these large absolute budgets for production admission before independent refined-oracle error is available.

No production source change is authorized.