# F-PE-NLGLOB14C result — saturated-remainder KLAG regime switch

Date: 2026-09-29

Status:

`NLGLOB14C_MIXED_REGIME_SWITCH_SIGNAL`

Canonical base:

`integration/f-ci-canonical@31901d9bbb75d87e8723c09f6804dabbcc25c219`

Canonical rechecked before result write:

`integration/f-ci-canonical@262190047ff97399cb1368cf45d7965dedf6de86`

The intervening canonical delta does not modify the NLGLOB14C temporal, HeadCalc, event-localization, replay or mass dependency surface.

Qualification authority:

- workflow run: `36561512075`;
- job: `109383237953`;
- conclusion: SUCCESS.

## Frozen question

Can the exact remainder after the qualified TG saturation event be integrated once with the existing KLAG/head-based endpoint formulation, while leaving the no-event TG path unchanged?

## Smooth regression

PASS.

The no-event smooth bank remains strongly second order:

- 4/4 ladders complete;
- median refined top-head order about `2.048`;
- median refined top-theta order about `2.048`;
- 4/4 head ladders >=1.5;
- median deterministic work ratio versus KLAG BE: `1.0`;
- physical mass remains at roundoff.

Thus the event/regime-switch machinery is inactive and non-disruptive on the smooth TIMEINT16C bank.

## First event split

All five frozen O05/TG targets successfully:

1. localize the saturation event;
2. commit the admissible event state internally;
3. compute a positive exact remainder;
4. integrate that remainder with KLAG;
5. preserve nominal-interval and cumulative mass at roundoff scale.

Observed maxima:

- max accepted-interval ledger about `2.24e-14 cm`;
- max cumulative ledger about `1.35e-14 cm`;
- max split nominal ledger about `1.21e-14 cm`.

No KLAG remainder endpoint failure occurs.

No process failure occurs.

## Full target horizon

Despite successful first event split, none of the five target trajectories completes the requested horizon.

All five fail later with:

`SATURATION_ROOT_BRACKET_INVALID`.

The failure occurs in a subsequent nominal interval, after the first event split already succeeded.

## Frozen classification

The preregistered positive gate requires all five targets to complete the requested horizon.

The specific negative gates for KLAG remainder endpoint failure, physical safety failure and smooth-order regression do not apply.

Therefore the correct residual classification is:

`NLGLOB14C_MIXED_REGIME_SWITCH_SIGNAL`.

## Interpretation

NLGLOB14C establishes an important local result:

the TG-to-KLAG switch is a valid remainder formulation at the first saturation event.

The remaining failure is not:

- event localization;
- KLAG remainder convergence;
- physical mass;
- smooth temporal order.

The failure appears when the next nominal interval re-enters the unsaturated TG event machinery from a state that is already at or extremely near the saturation boundary.

That means the regime switch must persist beyond the single remainder if the accepted state remains in the saturated/near-saturated regime.

## Consequence

Do not alter the localized event time and do not recurse within the same remainder.

Open a separate successor:

`F-PE-NLGLOB14D — persistent saturated-mode continuation after first TG saturation event`.

The bounded candidate should:

- use the qualified TG event localization once;
- switch the first remainder to KLAG;
- keep subsequent nominal intervals on KLAG while the frozen target horizon remains in the saturated/near-saturated regime;
- not switch back to TG inside NLGLOB14D;
- leave all no-event trajectories on TG;
- preserve S0/R0 and physical mass authority;
- preserve smooth second-order behavior when the event path is inactive.

A later workunit may define an explicit desaturation/release event if persistent KLAG qualifies.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
