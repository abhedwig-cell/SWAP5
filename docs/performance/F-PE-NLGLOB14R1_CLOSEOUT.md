# F-PE-NLGLOB14R1 closeout — post-handoff second-interval endpoint failure attribution

Date: 2026-09-29

Final status:

`NLGLOB14R1_UNIFORM_SECOND_INTERVAL_RETRY_ADVISED`

Qualification authority:

- run `36591512007`;
- job `109485510278`;
- conclusion: SUCCESS.

## Closure

NLGLOB14R1 closes the uniform second-interval failure attribution.

All 12 frozen fixtures reproduce the same mechanism after one accepted first-retreat TG handoff interval:

- solver status `2`;
- retry advised = true;
- route `legacy-reference-retry`;
- nonlinear iterations = 8;
- Jacobian builds = 8;
- linear solves = 8;
- internal retries = 1;
- no alternative solver call;
- surface-flux origin and predictor route remain consistent.

Backtracking attempts range from 11 to 16.

## Scientific conclusion

The second TG interval is not a hard failure.

The Reference solver uniformly requests timestep reduction.

This is qualitatively different from immediate saturation-mode re-entry. NLGLOB14R therefore does not falsify first-retreat TG ownership through chatter; it exposes a temporal-step robustness requirement immediately after handoff.

## Direct successor

Open a separately preregistered successor that applies the repository's already-qualified transaction retry semantics to the same second-interval origin.

Do not invent a new retry scale.

The successor should:

1. preserve the accepted first TG handoff state;
2. execute the unchanged second interval at nominal dt;
3. on retry-advised, rollback exactly;
4. retry using the existing qualified transaction retry scale;
5. allow existing saturation-event re-entry;
6. record whether the retried interval is accepted and whether ownership remains TG or returns to saturated mode;
7. preserve physical mass and accepted-state authority.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R1

BRANCH: `research/f-pe-nlglob14r1-second-interval-failure-attribution`

STATUS: closed positive mechanism attribution

TEST STATUS: 12-case frozen attribution PASS

QUALIFICATION STATUS: `NLGLOB14R1_UNIFORM_SECOND_INTERVAL_RETRY_ADVISED`

NEXT SAFE STEP: identify the current qualified transaction retry scale/contract and preregister post-handoff retry execution.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
