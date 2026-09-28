# F-PE-TIMEINT03 P1 preregistration — fully implicit BDF2 order test

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_P1_RESULTS`

Parent:

F-PE-TIMEINT03 P0, which established that ordinary fully implicit Backward Euler is usable in the smooth explicit fixed-flux provider envelope.

## Candidate

Use exactly the P0 test-only explicit binding that admits `conductivity_implicit_mode=1`.

Materialize HeadCalc test-only with the TIMEINT02 BDF2 storage operator:

after one ordinary BE bootstrap step,

`storage_rate = (1.5 theta^{n+1} - 2 theta^n + 0.5 theta^{n-1}) / dt`

and storage Jacobian:

`1.5 C(h^{n+1}) / dt`.

Conductivity and conductivity derivatives are endpoint-updated through `SWKIMPL=1`.

No other physical term or convergence tolerance changes.

## Matrix

Same four smooth cases as P0:

- B01, infiltration 2 cm/day;
- B01, infiltration 4 cm/day;
- O05, infiltration 2 cm/day;
- O05, infiltration 4 cm/day.

Same fixed dt ladder:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

Horizon:

`0.04 d`.

Comparator:

fully implicit BE from P0.

## Frozen gate

BDF2_KIMPL advances only if:

1. 4/4 cases complete over the full ladder;
2. median refined top-head order >=1.6;
3. at least 3/4 individual refined top-head orders >=1.5;
4. no mass/finite-state failure;
5. median deterministic work per step <=1.5 times fully implicit BE.

No threshold may change after result exposure.

## Boundary

This remains a smooth fixed-flux mechanism study.

No dynamic-top, variable-step or production BDF2 claim is allowed from P1 alone.
