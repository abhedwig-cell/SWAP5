# PPA-WU05-A4 strict-versus-practical corrector trade-off

Date: 2026-09-30

Status: `LOCAL_RESEARCH_RESULT / PRACTICAL_CUTOFF_CHARACTERIZED / NOT_YET_POLICY_FREEZE`

## Purpose

Compare fixed outer-corrector counts against the converged strict-route result for representative coupled Richards/macropore regimes.

The converged reference is taken from the end of the already qualified real-Richards Picard/damping sequences.

## Cases

Four regimes:

1. mild fresh event;
2. aged event;
3. strong mid-wet fresh event;
4. dry fresh event with outer damping.

Metrics:

- relative exchange error;
- absolute matrix-theta error;
- relative bottom-flux error.

## 1 corrector

### Mild fresh

- exchange error: **3.11%**;
- theta error: **3.72e-4**;
- bottom-flux error: **0.0095%**.

### Aged

- exchange error: **0.061%**;
- theta error: **1.80e-7**;
- bottom-flux error: negligible.

### Mid fresh

- exchange error: **21.7%**;
- theta error: **8.22e-3**;
- bottom-flux error: **15.7%**.

### Dry fresh, damped reference

- exchange error: **75.8%**;
- theta error: **8.85e-2**;
- bottom-flux error: **80.1%**.

Conclusion:

`ONE_CORRECTOR_NOT_GENERAL`.

It is viable only in weakly coupled regimes.

## 2 correctors

### Mild fresh

- exchange error: **0.100%**;
- theta error: **1.19e-5**;
- bottom-flux error: **0.00031%**.

### Aged

- exchange error: **3.8e-5%**;
- theta error: negligible;
- bottom-flux error: negligible.

### Mid fresh

- exchange error: **4.50%**;
- theta error: **1.76e-3**;
- bottom-flux error: **3.14%**.

### Dry fresh, damped reference

- exchange error: **12.1%**;
- theta error: **2.95e-2**;
- bottom-flux error: **7.37%**.

Conclusion:

`TWO_CORRECTORS_GOOD_IN_MILD_REGIMES_BUT_NOT_ROBUST`.

## 3 correctors

### Mild fresh

- exchange error: **0.0032%**;
- theta error: **3.83e-7**;
- bottom-flux error: **9.8e-6%**.

### Aged

- exchange error: negligible;
- theta error: negligible;
- bottom-flux error: negligible.

### Mid fresh

- exchange error: **0.951%**;
- theta error: **3.70e-4**;
- bottom-flux error: **0.670%**.

### Dry fresh, damped reference

- exchange error: **1.68%**;
- theta error: **4.18e-3**;
- bottom-flux error: **1.00%**.

Conclusion:

`THREE_CORRECTORS_FIRST_ROBUST_PRACTICAL_CANDIDATE_IN_TESTED_SET`.

## Cost interpretation

With the current architecture:

- predictor + 1 corrector = 2 Richards solves;
- predictor + 2 correctors = 3 Richards solves;
- predictor + 3 correctors = 4 Richards solves;
- strict route runs until exchange convergence, potentially more.

Three correctors therefore increase per-step solve count relative to the one-corrector practical route, but substantially reduce strong-regime error.

## Provisional research policy

### Strict route

Continue outer Picard/damped iteration to the selected exchange-convergence criterion.

### Practical route candidate

Use at most three correctors, with early stop if the exchange-change criterion is already met.

This is preferred over a fixed one-corrector route because:

- weak cases stop early;
- stronger cases receive more correction;
- worst tested three-corrector errors are around 1–2% in exchange and ~1% in bottom flux.

This level is consistent with the broader SWAP5 practical-mode philosophy, but A4 does not yet admit it as production policy.

## Remaining question

The trade-off must still be tested over multi-step trajectories because:

- one-step error may accumulate or cancel;
- sorptivity history itself evolves;
- timestep retry can interact with corrector count;
- crack-history activation may alter coupling strength.

## Next step

Build a short multi-step strict-versus-practical trajectory comparison using the research controller:

- strict converged route;
- adaptive up-to-3-corrector practical route;
- optionally one-corrector route as a negative control.

Compare cumulative exchange, final matrix state, macropore state, bottom flux and total water balance.
