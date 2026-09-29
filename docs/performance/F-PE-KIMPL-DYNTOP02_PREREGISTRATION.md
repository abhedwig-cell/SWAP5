# F-PE-KIMPL-DYNTOP02 preregistration — iteration-budget sensitivity

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent:

F-PE-KIMPL-DYNTOP01.

## Question

Does a bounded increase in nonlinear iteration capacity recover the TIMEINT12A failing fully implicit dynamic-top cases without introducing pathological work cost?

This is not a production MAXIT recommendation.

## Cases

Use the six KIMPL failures from TIMEINT12A:

- B01/WET;
- B01/POND;
- B12/POND;
- O05/POND;
- O14/MOIST;
- O14/WET.

Fixed:

- dt = 0.005 d;
- horizon = 0.12 d;
- SWKIMPL=1;
- qualified test-only fully implicit dynamic-top derivative;
- all current convergence tolerances unchanged;
- BALTOL02 unchanged.

## Arms

- MAXIT 8 baseline;
- MAXIT 12;
- MAXIT 16;
- MAXIT 24.

No other solver control changes.

## Metrics

Per case/arm:

- completion;
- first failing step when incomplete;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- deterministic work;
- max ledger;
- terminal state when complete.

## Frozen decision rules

Classify `ITERATION_CAP_RECOVERABLE` only if:

1. all six cases complete by MAXIT <=16;
2. no new alternative-solver pathology;
3. max ledger <=5e-8 cm;
4. median work ratio of the smallest all-completing arm versus MAXIT8 completed-prefix-equivalent work is not used for admission; instead report absolute added nonlinear work;
5. no case requires >16.

If any case still fails at MAXIT24, classify `NOT_SIMPLE_ITERATION_CAP`.

If all complete only at MAXIT24, classify `RECOVERABLE_BUT_TOO_DEEP_FOR_DEFAULT`.

No production change in KIMPL-DYNTOP02.
