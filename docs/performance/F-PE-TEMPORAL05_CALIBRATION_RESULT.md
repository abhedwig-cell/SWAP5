# F-PE-TEMPORAL05 calibration result — history-scale coefficient frontier

Date: 2026-09-26

Status: `COEFFICIENT_0P65_FROZEN_FOR_BLIND_HOLDOUT`

## Calibration set

Origins:

- B01 wet;
- B12 wet;
- O14 mid.

Both +/-10% dynamic-history directions and offsets +/-0.001 and +/-0.01 cm were used, giving 24 calibration points per coefficient.

All candidates used:

`budget(c) = max(1e-5 cm, c * dt * ||h_dot_previous||_inf)`.

## Result

| c | completed | retries | temporal rejections | physical envelope |
| ---: | ---: | ---: | ---: | --- |
| 0.50 | 24/24 | 24 | 24 | PASS |
| 0.55 | 24/24 | 16 | 16 | PASS |
| 0.60 | 24/24 | 16 | 16 | PASS |
| 0.65 | 24/24 | 8 | 8 | PASS |
| 0.70 | 24/24 | 8 | 8 | PASS |
| 0.75 | 24/24 | 0 | 0 | FAIL |
| 0.80 | 24/24 | 0 | 0 | FAIL |
| 0.90 | 24/24 | 0 | 0 | FAIL |

The c>=0.75 arms fail the unchanged TEMPORAL04/P1 physical envelope because max |dtheta| reaches about 1.176e-5, above the fixed 1e-5 limit.

c=0.65 and c=0.70 have the same retry count. Under the preregistered tie-break rule the smaller coefficient is selected.

## Frozen selection

`c_selected = 0.65`

Calibration envelope at c=0.65:

- 24/24 complete;
- retries = 8;
- temporal rejections = 8;
- solver rejections = 0;
- max |dh| = 3.369e-3 cm;
- max |dtheta| = 6.427e-6;
- max relative terminal-flux error = 0.640%;
- max relative integrated-exchange error = 0.253%.

## Decision

The coefficient 0.65 is frozen before blind holdout execution.

No other coefficient may replace it based on holdout results.