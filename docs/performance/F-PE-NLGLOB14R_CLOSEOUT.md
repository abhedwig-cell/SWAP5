# F-PE-NLGLOB14R closeout — accepted first-retreat TG handoff persistence

Date: 2026-09-29

Final status:

`NLGLOB14R_MIXED_HANDOFF_PERSISTENCE`

Qualification authority:

- run `36589388847`;
- job `109478292008`;
- conclusion: SUCCESS.

## Closure

NLGLOB14R closes the frozen two-interval handoff window without establishing stable TG ownership.

All 12 fixtures:

- accept the first TG interval after the qualified first-retreat handoff;
- remain finite and mass-clean through that accepted interval;
- retain 13 saturated nodes;
- keep saturated mode off;
- then enter the frozen immediate-following TG interval.

The immediate-following interval fails in all 12 with:

`ENDPOINT_SOLVE_FAILURE`.

No fixture records saturation-mode re-entry before that failure.

## Frozen classification

No fixture qualifies stable TG continuation or immediate saturated-mode re-entry.

The uniform second-interval failure falls on the preregistered otherwise surface.

Final aggregate status:

`NLGLOB14R_MIXED_HANDOFF_PERSISTENCE`.

## Scientific conclusion

First retreat is sufficient for one accepted full-column TG interval, but the current evidence does not support persistent TG ownership.

The limiting mechanism is now the second TG interval's endpoint solve, not release-event localization, route selection, immediate saturation re-entry, or accepted-state mass conservation.

## Direct successor

Open:

`F-PE-NLGLOB14R1 — post-handoff second-interval endpoint failure attribution`.

The successor must retain the exact NLGLOB14R handoff state and second interval and expose existing solver/predictor/route diagnostics before changing any solver or state-machine policy.

It should distinguish:

- retry-advised endpoint solve;
- nonlinear/backtracking exhaustion;
- predictor/domain failure;
- route inconsistency;
- other endpoint failure.

Do not change MAXIT, BALTOL, dt, forcing, provider capacity, release timing, or event semantics during attribution.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R

BRANCH: `research/f-pe-nlglob14r-accepted-tg-handoff-persistence`

STATUS: closed mixed persistence result

TEST STATUS: 12-case frozen two-interval handoff window PASS

QUALIFICATION STATUS: `NLGLOB14R_MIXED_HANDOFF_PERSISTENCE`

NEXT SAFE STEP: preregister second-interval endpoint failure attribution.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
