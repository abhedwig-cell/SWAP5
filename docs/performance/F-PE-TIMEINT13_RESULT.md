# F-PE-TIMEINT13 result — extrapolated-conductivity BDF2

Date: 2026-09-29

Status: `SMOOTH_ORDER_PASS_DYNAMIC_TOP_ROBUSTNESS_FAIL`

Canonical base:

`integration/f-ci-canonical@2b6a82c4c89ba759a0c89df53971c725827d2b88`

Primary Actions authority:

- P0 smooth-order run: `36518477410`;
- P1 dynamic-top run: `36518594895`;
- dynamic-top job: `109246319045`.

## P0 — smooth fixed-flux mechanism

PASS.

The extrapolated-conductivity candidate uses:

`K_pred = K_n + r (K_n-K_{n-1})`

with conductivity fixed during Newton and BDF2 storage/history unchanged.

Observed:

- 4/4 ladders complete;
- median refined top-head temporal order: about 1.94;
- individual refined orders: about 1.98, 1.96, 1.91 and 1.77;
- all 4 individual orders exceed 1.5;
- no conductivity clamps;
- storage spread remains roundoff scale;
- candidate work per step is non-inferior to fully implicit BDF2.

This establishes that second-order temporal behavior does not require endpoint-fully-implicit conductivity on the smooth fixed-flux envelope.

## P1 — dynamic-top robustness/cost

FAIL.

Aggregate:

- candidate completion: 10/12;
- all POND completion gate: FAIL;
- median deterministic work ratio versus KLAG: about 1.01;
- maximum completed-case work ratio: about 1.21;
- no alternative-solver pathology;
- conductivity clamp fraction is bounded but nonzero;
- ordinary physical interval-ledger gate: FAIL.

Two candidate trajectories fail to complete:

- O05/POND fails immediately; the KLAG comparator also fails this same fixture, so this is not purely candidate-specific;
- O14/POND fails at step 2 while KLAG completes.

## Mass-accounting observation

The completed dynamic-top BDF2 trajectories show a systematic mismatch when evaluated with the ordinary one-step physical ledger:

`S_{n+1}-S_n - (in-out)`.

Representative maximum per-step mismatches are O(1e-3) to O(1e-2 cm), while the corresponding KLAG Backward-Euler paths remain roundoff-scale.

Examples:

- B01/POND: about 0.0377 cm;
- B12/MOIST: about 0.00492 cm;
- B12/WET: about 0.00439 cm;
- B12/POND: about 0.00363 cm;
- O14/MOIST: about 0.00247 cm;
- O14/WET: about 0.00551 cm.

This is too large to classify as floating-point noise.

The observation is consistent with a structural distinction between:

- the BDF2 multistep storage derivative used in the discrete Richards equation; and
- SWAP's current interval mass contract based on the physical storage difference between two consecutive accepted states.

TIMEINT13 does not yet prove the exact correction required, so this is recorded as a successor question rather than repaired post hoc.

## Scientific conclusion

The central TIMEINT13 hypothesis is partly confirmed:

- second-order smooth behavior can be obtained with history-predicted, Newton-fixed conductivity;
- the nonlinear-work cost is much closer to KLAG than to expensive KIMPL dynamic-top.

However, dynamic-top production qualification fails because:

1. not all target trajectories complete;
2. the current physical interval mass ledger is not preserved by the tested multistep formulation.

The second point is more fundamental than the original conductivity-cost question and must be resolved before adaptive BDF2 is considered for production.

## Decision

Final classification:

`SMOOTH_ORDER_PASS_DYNAMIC_TOP_ROBUSTNESS_FAIL`

Do not production-admit extrapolated-K BDF2.

Open a conservation-focused successor before further controller work.
