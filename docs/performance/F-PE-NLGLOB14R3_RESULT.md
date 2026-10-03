# F-PE-NLGLOB14R3 result — bounded recursive post-handoff retry-depth attribution

Date: 2026-09-29

Status:

`NLGLOB14R3_MIXED_RETRY_DEPTH`

Qualification authority:

- workflow run: `36593940226`;
- job: `109493925577`;
- conclusion: SUCCESS.

## Frozen question

Starting from the exact accepted second-interval origin after first-retreat TG handoff, does the existing transaction policy with retry scale 0.5 and at most 8 retries find accepted internal progress?

## Coverage

PASS.

All 12 fixtures:

- reproduce the nominal retry-advised second interval;
- restore the same accepted checkpoint before every retry;
- use the exact retry ladder `dt * 0.5^r`;
- preserve finite accepted state and roundoff-scale accepted mass before rejected attempts.

No rejected retry candidate contributes accepted ledger.

## Retry-depth result

No fixture produces accepted internal progress at retry depths 1..8.

Three fixtures remain retry-advised through all eight bounded retries and classify:

`RETRY_BUDGET_EXHAUSTED`.

The other nine eventually stop before depth 8 with:

`SATURATION_ROOT_BRACKET_INVALID`.

These classify under the frozen R3 surface as:

`RECURSIVE_RETRY_HARD_FAILURE`.

No fixture reaches:

- accepted TG progress;
- accepted saturated-mode re-entry.

Aggregate classification:

`NLGLOB14R3_MIXED_RETRY_DEPTH`.

## Pattern

The bracket-invalid termination appears only after several retry reductions.

Examples:

- HEAD dt 2.5e-4: invalid at retry depth 7;
- HEAD dt 1.25e-4: invalid at depth 8;
- HEAD dt 6.25e-5: invalid at depth 8;
- RUNOFF dt 2.5e-4: invalid at depth 5;
- RUNOFF dt 1.25e-4: invalid at depth 7.

Other fixtures exhaust all eight retry-advised attempts without reaching the bracket-invalid path.

Across all fixtures the lower saturated block remains 13 nodes at the observed failed attempts.

## Physical admissibility

Accepted state remains clean throughout:

- max accepted-interval ledger about `2.68e-14 cm`;
- max cumulative accepted ledger about `9.12e-14 cm`.

Rollback before retry remains exact.

## Scientific interpretation

First-retreat release is not yet numerically supportable as persistent full-column TG ownership under the current bounded retry authority.

The failure mechanism bifurcates:

1. continued retry advice through the full budget;
2. transition from retry advice to `SATURATION_ROOT_BRACKET_INVALID` at very small retry dt.

The second mechanism is especially informative because it indicates interaction between post-release TG ownership and saturation-event localization, not merely nonlinear solve effort.

## Consequence

Do not alter retry scale, retry budget, solver tolerances or release timing.

Open a separate attribution of the post-release `SATURATION_ROOT_BRACKET_INVALID` path.

The next workunit must determine whether the invalid bracket means:

- the event is already present at the retry origin;
- the predictor and accepted endpoint lie on the same side of the root while saturated nodes remain;
- the selected event node/manifold is inappropriate after release;
- or the event detector is being invoked on a state that should already be owned by saturated mode.

## Production boundary

Research only.

No production `src/**` change.

No numerical default or production temporal-mode ownership changed.

`LEGACY_NUMERICS` remains production default.
