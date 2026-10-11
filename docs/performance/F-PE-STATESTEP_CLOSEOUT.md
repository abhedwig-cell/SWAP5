# F-PE-STATESTEP01-03 closeout — accepted-state adaptive timestep controller

Date: 2026-09-28

Final status:

`CLOSED_NO_ACCEPTED_STATE_CONTROLLER_GAIN`

Canonical base:

`integration/f-ci-canonical@0714438bbb248e8056b0ad096dc02ceae8e48e22`

## Research question

Can the BOFEK numerical-policy speed/accuracy tradeoff be captured by a cheap causal state-aware timestep controller, avoiding static soil/regime classes?

## STATESTEP01 — absolute head movement

Signal:

`max|dh|`.

Result:

Strongly negative. Fixed absolute head-change targets over-refine dry profiles and increase solver work, in the worst arms by several-fold.

Conclusion:

Absolute pressure-head movement is not a portable timestep-difficulty measure.

## STATESTEP02 — normalized head movement

Signal:

`max_i(|dh_i| / max(10 cm, |h_i|))`.

This materially improves the picture.

Best arm:

- target R=0.40;
- post ponding/runoff safeguard;
- about 34.3% median deterministic work reduction on passing cases;
- 14/16 P-C1 pass.

Failures remain in a ponding case and a transition-to-ponding case.

Conclusion:

Relative state movement carries useful performance information, but one accepted-step scalar history is not sufficient for robust wet-transition control.

## STATESTEP03 — pre-ponding safeguard

Added causal top-head thresholds at -20, -10 and -5 cm.

All three returned exactly the same aggregate result as the parent controller:

- 14/16 P-C1;
- about 34.3% median work reduction;
- wet/ponding gate failure.

Conclusion:

A simple accepted top-head proximity threshold does not detect the sensitive transition early enough.

## Final decision

No production numerical-policy change.

Do not add:

- absolute head-change timestep control;
- relative accepted-head-change control by itself;
- accepted ponding/runoff-only safeguard;
- static pre-ponding top-head thresholds.

## What the line did establish

There is a large potential performance signal in adaptive timestep selection.

The normalized controller reaches roughly one-third less deterministic solver work where it remains within P-C1. Therefore the earlier BOFEK result is not evidence that timestep policy has no value.

The blocker is prediction quality near hydrologic regime transitions.

A successful successor should use information available before or during the candidate step, such as:

1. a dynamic-top compatible temporal defect/error indicator;
2. a predictor of surface-boundary regime transition;
3. multi-step history rather than only the last accepted state;
4. an embedded step-doubling or cheap local error estimator selectively invoked near suspected transitions.

The current production Reference temporal indicator cannot simply be reused because its admitted envelope requires an explicit fixed-flux top boundary.

## Production boundary

No `src/**` changes are authorized.

Final classification:

`CLOSED_NO_ACCEPTED_STATE_CONTROLLER_GAIN`.
