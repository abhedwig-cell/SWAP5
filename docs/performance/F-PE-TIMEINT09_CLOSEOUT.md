# F-PE-TIMEINT09 closeout — exact final-Newton BDF2 truncation response

Date: 2026-09-29

Final status:

`CLOSED_EXACT_NEWTON_RESPONSE_NOT_CONSERVATIVE`

## P0 mechanism qualification

Calibration on B01/O05 passed every frozen gate:

- 96 complete labels;
- zero unavailable labels;
- no alternative-solver use;
- overall Spearman about 0.959;
- all pattern correlations above 0.94;
- median actual/E9 about 0.717;
- max actual/E9 about 1.495;
- zero false-safe points at E9 <=0.01 cm;
- about 94.7% safe coverage.

This qualifies the exact final Newton response mechanism on the exposed calibration bank.

## Blind validation

Blind B12/O14 validation preserves the strong correlation and bounded scale:

- 36/36 full trajectories complete;
- 143 complete local labels;
- overall Spearman about 0.928;
- all per-pattern Spearman values above 0.91;
- max actual/E9 about 1.925;
- all ratios within the preregistered [0.25,2.0] scale envelope.

But the fixed classification threshold produces five false-safe points.

Therefore the estimator does not qualify as a conservative direct timestep-acceptance indicator.

## Scientific conclusion

TIMEINT08 had left open the possibility that the missing conductivity-derivative terms in the simplified response matrix caused the remaining blind underprediction.

TIMEINT09 answers that question.

Those omitted terms matter for fidelity, but they are not the complete cause of the classification failure.

Even the exact final Newton linear response is not identical to the nonlinear local temporal error map.

The remaining discrepancy is small in scale, but it is systematic enough to cross a strict 0.01 cm decision boundary in five blind points.

## Architectural implication

This is still a major improvement over legacy timestep heuristics.

The work has established:

1. variable-step fully implicit BDF2 is a credible second-order temporal mechanism;
2. accepted ratio 0.5 <= r <=2 is qualified research authority;
3. the final Newton factorization can be reused cheaply;
4. one-backsolve LTE response is highly predictive;
5. but a response-estimator alone is not conservative enough for zero-false-safe timestep authority without a fitted safety factor.

The preregistered stop rule deliberately forbids fitting that factor after seeing the holdout.

## Required successor

`F-PE-TIMEINT10 — embedded BDF2/BE integrator-pair feasibility`.

The next study should test whether a lower-order solution can be embedded using the same converged BDF2 Newton information with materially less cost than a second full nonlinear solve.

Priority options:

1. defect-corrected embedded BE endpoint using the existing final Jacobian;
2. one Newton correction toward the BE equation from the BDF2 endpoint;
3. another genuinely embedded implicit pair only if it reuses matrix/factorization and does not require two independent nonlinear trajectories.

The research target is:

- a direct local error estimate from two discretization orders;
- zero false-safe on blind material holdout;
- no more than one additional linear backsolve or bounded single Newton correction per accepted step;
- no full second nonlinear solve in normal operation.

If an embedded pair cannot meet that cost envelope, the modernization path should reconsider whether strict local error control is worth the runtime cost and may instead use bounded practical acceptance at coupling level.

## Production boundary

No production `src/**` change.

LEGACY_NUMERICS remains production default.

Variable-step BDF2 remains qualified research authority, not production-admitted.
