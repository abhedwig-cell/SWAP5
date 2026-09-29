# F-PE-NLGLOB14G result — forcing-reversal desaturation fixture

Date: 2026-09-29

Status:

`NLGLOB14G_NO_RELEASE_UNDER_FROZEN_REVERSAL`

Canonical base:

`integration/f-ci-canonical@e46985908b19f83cf2f17f86507aa3495df971a2`

Canonical rechecked before persistence through:

`integration/f-ci-canonical@e355dacf50fcc0cceb77e02f73b78eddebcbeced`

The intervening canonical delta does not alter the NLGLOB14G temporal policy, dynamic-top provider, forcing fixture or HeadCalc dependency surface.

Qualification authority:

- workflow run: `36564922905`;
- job: `109394454586`;
- conclusion: SUCCESS.

## Frozen question

Does the explicitly drying forcing reversal produce an accepted physical desaturation transition while persistent saturated temporal mode remains active?

## Coverage

PASS.

All 8 preregistered O05/TG fixtures:

- enter persistent saturated mode;
- execute the full 0.012 d horizon;
- apply the frozen dry forcing;
- remain finite;
- preserve physical mass.

Process failures:

`0`.

## Forcing authority

PASS.

After saturated-mode entry:

- precipitation = 0;
- potential bare-soil evaporation = original wet precipitation rate;
- potential pond evaporation = original wet precipitation rate.

No forcing multiplier was tuned.

## Result

Consistent release trajectories:

`0 / 8`.

Head/moisture saturation-indicator inconsistencies:

`0`.

Frozen classification:

`NLGLOB14G_NO_RELEASE_UNDER_FROZEN_REVERSAL`.

## Physical admissibility

PASS.

- max accepted-interval ledger about `2.36e-14 cm`;
- max cumulative ledger about `1.69e-14 cm`;
- forcing diagnostics pass in all cases.

## Interpretation

The absence of release is not caused by process failure, route/state invalidity or mass error.

The frozen drying interval is simply insufficient to move the original saturation-event node off the saturated constitutive manifold in any of the eight fixtures.

This result does not imply that desaturation cannot occur.

It establishes that a release rule still cannot be selected from observed accepted-state crossing evidence at the current 0.012 d horizon.

## Consequence

Do not invent a release threshold or force a mode switch.

The next bounded work should remain observational and determine whether the event-node state is:

1. stationary on the saturated manifold under the dry forcing; or
2. evolving monotonically toward desaturation but has not crossed within the frozen horizon.

Only the second outcome could justify a separately preregistered longer-horizon release-observation fixture.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
