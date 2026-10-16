# F-PE-NLGLOB14C result — saturated-remainder temporal regime switch

Date: 2026-09-29

Status:

`CLOSED_TG_EVENT_KLAG_REMAINDER_STATE_FAILED`

Canonical base:

`integration/f-ci-canonical@31901d9bbb75d87e8723c09f6804dabbcc25c219`

Qualification authority:

- workflow run: `36561331156`;
- job: `109382644629`;
- conclusion: SUCCESS.

## Frozen question

Can the exact post-saturation remainder be completed by switching from TG to the existing implicit head/KLAG formulation while leaving the no-event TG path unchanged?

## Smooth regression

PASS.

The no-event smooth bank remains second order:

- 4/4 ladders complete;
- median refined head order about `2.048`;
- median refined moisture order about `2.048`;
- 4/4 head ladders >=1.5;
- median deterministic work ratio versus KLAG BE: `1.0`;
- physical mass at roundoff.

## First event-split behavior

The localized saturation event and immediate KLAG remainder are successful in all five target trajectories.

For all five:

- `SWITCH_OK=1`;
- event state remains finite;
- event and final routes remain consistent;
- event and nominal ledgers remain near roundoff.

Observed nominal ledgers are at most about `1.21e-14 cm`.

## Full trajectory result

Completed requested horizons:

`0 / 5`.

However, the terminal reason is not a failed KLAG remainder.

All five later terminate as:

`SATURATION_ROOT_BRACKET_INVALID`.

The failure occurs on a later nominal TG step started from a state that is already on, or numerically indistinguishable from, the saturation boundary.

At that point no new interior crossing fraction exists in `(0,1)`, so the NLGLOB14A event bracket is intentionally unavailable.

## Frozen classification

The preregistered generic residual class is:

`CLOSED_TG_EVENT_KLAG_REMAINDER_STATE_FAILED`.

The mechanistic attribution is narrower:

`POST_EVENT_SATURATED_MODE_NOT_PERSISTED`.

## Interpretation

The first saturation-event transition works.

The missing mechanism is persistence of the post-event temporal regime across subsequent nominal intervals.

After the first saturation event, the outer trajectory currently returns to the ordinary TG path. That path assumes an unsaturated accepted origin and therefore attempts to detect a new saturation crossing from a state already at saturation.

This is not a root-localization failure and not a KLAG remainder failure.

## Consequence

A successor should introduce a test-only persistent saturated temporal mode:

- enter saturated mode after the first qualified saturation event;
- while the accepted origin remains on the saturation boundary / saturated branch, advance the nominal interval with the existing head/KLAG formulation;
- reevaluate the dynamic-top provider each interval;
- exit saturated mode only under a separately defined, physically admissible release condition;
- leave the ordinary unsaturated TG path unchanged.

The entry condition is already qualified by NLGLOB14A.

The exit condition must be preregistered before result exposure.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
