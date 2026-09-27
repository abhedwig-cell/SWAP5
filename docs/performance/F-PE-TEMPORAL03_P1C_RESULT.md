# F-PE-TEMPORAL03 P1C result — replicated dynamic frontier boundary

Date: 2026-09-26

Status: `DYNAMIC_FRONTIER_CONFIRMED`

## Protocol

Three fresh-process repetitions were run for every signed-history point at the candidate frontier and its immediately stricter tested budget.

Each arm contains 24 unique dynamic signed-history points: six origins x two history directions x two corrector signs.

## Result

| |dh| (cm) | stricter budget | stricter pass | frontier budget | frontier pass |
| ---: | ---: | ---: | ---: | ---: |
| 0.001 | 0.1 cm | 23/24 | 0.2 cm | 24/24 |
| 0.01 | 0.05 cm | 20/24 | 0.1 cm | 24/24 |

All three repetitions were deterministic at every point.

## Interpretation

The large dynamic-history frontier from P1B is real and not a single-run artifact.

The result also shows how little safety margin exists at |dh|=0.001 cm: 0.1 cm misses only one of 24 points, while 0.2 cm recovers the full set.

These absolute budgets are extremely large relative to the corrector displacement itself. That is further evidence that the current certificate scale is dominated by predecessor-history mismatch rather than by corrector displacement alone.

## Decision

Do not admit either 0.1 or 0.2 cm as a production tolerance.

Proceed to P2 independent fixed-substep oracle qualification. The central question is now whether the certificate is conservative relative to actual refined temporal error, not whether a sufficiently large absolute budget can force completion.

No production source change is authorized.