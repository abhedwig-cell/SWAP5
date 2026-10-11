# F-PE-NLGLOB14C closeout — saturated-remainder temporal regime switch

Date: 2026-09-29

Final status:

`CLOSED_TG_EVENT_KLAG_REMAINDER_STATE_FAILED`

Mechanistic attribution:

`POST_EVENT_SATURATED_MODE_NOT_PERSISTED`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@31901d9bbb75d87e8723c09f6804dabbcc25c219`

Qualification authority:

- run `36561331156`;
- job `109382644629`;
- conclusion: SUCCESS.

## Closure

NLGLOB14C closes the one-interval event plus KLAG-remainder candidate negatively as a full-trajectory mechanism.

The first event transition itself succeeds in all five targets:

- saturation root localizes;
- KLAG remainder completes;
- route remains consistent;
- physical mass remains near roundoff.

The trajectories fail later because the next nominal interval re-enters ordinary TG from an already saturated origin and cannot construct a new interior saturation-event bracket.

## Scientific conclusion

The missing element is persistent temporal regime state.

Saturation is not merely a one-interval event. Once the accepted trajectory reaches the saturation boundary, subsequent nominal intervals require a temporal formulation valid on that saturated branch until a physically defined release occurs.

Repeatedly asking the unsaturated TG path to rediscover the same event is semantically wrong.

## Direct successor

Open:

`F-PE-NLGLOB14D — persistent saturated temporal mode and release attribution`.

The successor must preregister before results:

1. entry into saturated mode only after a qualified NLGLOB14A event;
2. saturated-mode nominal intervals use existing head/KLAG integration;
3. dynamic-top provider reevaluates every interval;
4. no accepted-theta clipping;
5. no change to unsaturated no-event TG;
6. an explicit release condition must be defined from physical state/provider evidence, not from iteration count.

First phase may conservatively keep saturated mode active for the whole frozen target horizon if no release criterion is yet qualified, provided this is preregistered as an attribution test and not production semantics.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14C

BASELINE: `31901d9bbb75d87e8723c09f6804dabbcc25c219`

BRANCH: `research/f-pe-nlglob14c-saturated-remainder`

STATUS: closed negative with positive first-event mechanism evidence

TEST STATUS: focused run PASS

QUALIFICATION STATUS: full trajectory not qualified

NEXT SAFE STEP: preregister NLGLOB14D persistent saturated temporal mode

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
