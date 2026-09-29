# F-PE-NLGLOB14F result — saturated-mode release attribution

Date: 2026-09-29

Status:

`NLGLOB14F_NO_RELEASE_IN_FROZEN_HORIZON`

Canonical base:

`integration/f-ci-canonical@0324f5dac58444aa956ecb1031022e99e8c1f170`

Canonical rechecked before result persistence through:

`integration/f-ci-canonical@fb8e5fc203dffc7f102165d01cd0374a6366ba82`

The intervening canonical delta does not change the NLGLOB14F temporal harness, qualified NLGLOB14E policy, dynamic-top provider, constitutive provider or frozen 96-case bank.

Qualification authority:

- workflow run: `36563904887`;
- job: `109391081460`;
- conclusion: SUCCESS.

## Frozen question

Does the already qualified full dynamic-top bank contain a natural accepted-state transition from persistent saturated mode back to an unsaturated constitutive state?

No release rule or forcing change was introduced.

## Coverage

PASS.

The TG half of the full frozen bank was observed:

- cases: 48;
- process failures: 0;
- all saturated-entry trajectories complete;
- saturated-entry trajectories: 8;
- event node identity: node 16 in all 8.

## Result

Natural release trajectories:

`0 / 8`.

Safe release trajectories:

`0 / 8`.

Head/moisture indicator inconsistencies:

`0`.

For every trajectory that enters persistent saturated mode, the original saturation-event node remains on the saturated constitutive manifold throughout the frozen horizon:

- `h_event >= 0`;
- `theta_event == theta_s`.

No accepted state shows the preregistered paired release signature:

- `h_event < 0`;
- `theta_event < theta_s`.

## Frozen classification

`NLGLOB14F_NO_RELEASE_IN_FROZEN_HORIZON`.

## Interpretation

The qualified NLGLOB14E bank is sufficient to establish entry and persistence of saturated temporal mode, but it contains no natural desaturation event from which a release rule can be identified.

This is not evidence that release should never occur.

It means the existing wet/near-saturation bank contains no information that can qualify the leaving transition.

The accepted-state head and moisture indicators remain mutually consistent throughout the observed saturated intervals.

## Consequence

Per preregistration, the next workunit must introduce a separate, physically explicit forcing-reversal fixture before any release criterion is selected.

That fixture should:

- first reproduce qualified saturation entry;
- then apply a drying boundary forcing through the existing dynamic-top provider;
- keep saturated mode active observationally;
- record when the accepted physical state leaves the saturated constitutive manifold;
- not switch back to TG until release evidence is qualified.

No empirical threshold or hysteresis rule is authorized by NLGLOB14F.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
