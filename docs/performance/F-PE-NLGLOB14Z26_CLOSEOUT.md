# F-PE-NLGLOB14Z26 closeout — event-window nonlinear work

Date: 2026-09-30

Final status:

`QUALIFIED_Z26_EVENT_WINDOW_SOLVER_WORK_CHARACTERIZED`

Qualification authority:

- workflow run `36723523142`;
- HEAD segment-B job `109921171191`;
- RUNOFF segment-B job `109921171246`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

## Closure

Z26 closes the first operation-level chatter-cost question.

For both fine O05 fixtures, both qualified chatter bursts reproduce exactly under observer-only instrumentation.

Every chatter interval requires exactly two Newton iterations.

Relative to matched post-settlement stable windows:

- burst 1 mean ratio is 0.8 in both fixtures;
- burst 2 mean ratio is about 0.783 for HEAD and 0.769 for RUNOFF.

Relative to matched pre-event stable windows for burst 2:

- pre-event mean is 1.0 iteration;
- chatter mean is 2.0;
- post-event mean is about 2.56 to 2.6.

Thus the deeper transition shows a monotone change in local solver work across the ownership regimes, with chatter in between the pre- and post-transition costs.

## Mechanistic conclusion

The current evidence does not support the hypothesis that direction-flip chatter itself creates a nonlinear-solver work spike.

The stronger remaining hypothesis is that work changes primarily with split/block geometry and the evolving physical state.

This also aligns with Z25: chatter introduces no retries, substeps or extra physical intervals.

## Direct successor

Preregister a block-size-normalized work attribution study.

It should separate:

1. Newton iteration count;
2. nonlinear unknown count / upper-block size;
3. approximate dense numerical-Jacobian work implied by the research harness;
4. ownership-change bookkeeping.

The purpose is to determine whether any residual cost can actually be attributed to chatter after accounting for block size and state regime.

Do not introduce an anti-chatter production mechanism unless that successor demonstrates a material implementation burden or another non-performance requirement emerges.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z26

BRANCH: `research/f-pe-nlglob14z26-event-window-work`

RESEARCH POSTIMAGE BEFORE CLOSEOUT: `19513df05948d01fcebfe08169f79bdd9db7fe9a`

QUALIFICATION RUN: `36723523142`

QUALIFICATION STATUS: `QUALIFIED_Z26_EVENT_WINDOW_SOLVER_WORK_CHARACTERIZED`

NEXT SAFE STEP: block-size-normalized operation attribution using the qualified Z26 event/control windows.

## Production boundary

No production source/default change.

`LEGACY_NUMERICS` remains production default.
