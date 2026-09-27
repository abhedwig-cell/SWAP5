# F-PE-TEMPORAL04 P0 result — dynamic temporal policy versus refined oracle

Date: 2026-09-26

Status: `HISTORY_AWARE_HALF_SCALE_DOMINATES_SCREEN`

## Candidate policies

- CURRENT_FIXED: 1e-5 cm;
- HIST_HALF: `max(1e-5 cm, 0.5 * dt * ||h_dot_previous||_inf)`;
- HIST_ONE: `max(1e-5 cm, dt * ||h_dot_previous||_inf)`;
- FIXED_0P2: 0.2 cm high-completion benchmark.

Each policy was evaluated on 48 difficult dynamic-history corrector points against the independent N=32 fixed-substep Reference oracle recovered through BALTOL01/BALTOL02.

## Completion

| policy | completed |
| --- | ---: |
| CURRENT_FIXED | 16/48 |
| HIST_HALF | 48/48 |
| HIST_ONE | 48/48 |
| FIXED_0P2 | 48/48 |

Both displacement classes show the same completion split:

- CURRENT_FIXED: 8/24 at |dh|=0.001 cm and 8/24 at |dh|=0.01 cm;
- all three larger/history-aware arms: 24/24 at both magnitudes.

## Oracle error envelope

### CURRENT_FIXED, successful subset only

- max |dh| = 6.34e-6 cm;
- max |dtheta| = 1.06e-8;
- max relative terminal-flux difference = 2.42e-4;
- max relative integrated-exchange difference = 1.90e-4.

### HIST_HALF

Budget range:

- minimum 1.025e-3 cm;
- median 3.062e-2 cm;
- maximum 7.652e-2 cm.

Across all 48 completed points:

- max |dh| = 6.565e-3 cm;
- max |dtheta| = 6.427e-6;
- max terminal-flux difference = 9.111e-2 cm/day;
- max relative terminal-flux difference = 7.199e-3, about 0.72%;
- max integrated-exchange difference = 2.336e-6 cm;
- max relative integrated-exchange difference = 1.677e-3, about 0.17%.

### HIST_ONE

Completes the same 48/48 but with a looser budget envelope and larger state/exchange differences:

- max |dh| = 1.268e-2 cm;
- max |dtheta| = 1.176e-5;
- max relative terminal-flux difference = 7.447e-3;
- max relative exchange difference = 2.898e-3.

FIXED_0P2 produces the same worst-case error envelope as HIST_ONE and is retained only as a high-completion benchmark.

## Interpretation

HIST_HALF is the dominant P0 candidate:

- complete on all difficult dynamic-history points;
- materially stricter than HIST_ONE and fixed 0.2 cm;
- lower state and exchange error;
- derived directly from the temporal defect formula rather than fitted to oracle endpoints.

The current fixed 1e-5 cm policy remains substantially more accurate where it completes, but its 16/48 completion makes it unusable as the sole dynamic-history coupling policy in this qualification domain.

## Decision

Advance only HIST_HALF to P1.

No production temporal-policy change is authorized by P0.