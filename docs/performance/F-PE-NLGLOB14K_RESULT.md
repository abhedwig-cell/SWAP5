# F-PE-NLGLOB14K result — mixed-profile temporal-mode ownership attribution

Date: 2026-09-29

Status:

`NLGLOB14K_SPATIALLY_SPLIT_TEMPORAL_OWNERSHIP_SIGNAL`

Canonical base:

`integration/f-ci-canonical@e803842a434d792ba5209f71e3681bd78be90560`

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@667c4b76768f760403e0b58383c386686baa3784`

The intervening canonical delta is outside the NLGLOB14K temporal-policy dependency surface.

Qualification authority:

- workflow run: `36567914264`;
- job: `109404337417`;
- conclusion: SUCCESS.

## Coverage

PASS.

All 8 frozen O05/TG dry forcing-reversal fixtures:

- complete the requested horizon;
- remain finite;
- preserve physical mass;
- retain consistent saturation indicators;
- retain a contiguous lower saturated block after mixed-profile onset.

Process failures:

`0`.

## Mixed-profile onset

Every fixture reaches a state where:

- actual surface route is `surface-flux`;
- ponding is zero within the frozen onset criterion;
- the top node is unsaturated;
- a nonempty contiguous lower saturated block remains;
- at least one unsaturated node lies above that block.

Observed onset depends on route and dt, but occurs in all 8 fixtures.

## Upper-region TG admissibility

From mixed-profile onset through the final dry-phase accepted state, every upper unsaturated-region node in every fixture satisfies the preregistered TG-admissibility checks:

- pressure head < 0;
- theta < theta_s;
- finite positive constitutive capacity;
- finite accepted state;
- constitutive theta(h) roundtrip <= 1e-12;
- finite chain-rule `h_dot = theta_dot/C`;
- finite endpoint head predictor `h_tilde = h + dt*h_dot`.

Observed maximum constitutive roundtrip error:

`0.0` in the logged precision.

The lower saturated block remains physically persistent and contiguous.

## Frozen classification

All 8/8 fixtures classify:

`UPPER_TG_LOWER_SATURATED_SPLIT`.

Aggregate classification:

`NLGLOB14K_SPATIALLY_SPLIT_TEMPORAL_OWNERSHIP_SIGNAL`.

## Scientific interpretation

The persistent saturated state is spatially mixed.

After drying has removed ponding and restored surface-flux control:

1. the upper region is fully compatible with the existing TG unsaturated temporal mechanism;
2. a contiguous lower block remains saturated and physically mass-consistent;
3. whole-column persistent saturated KLAG therefore owns more of the profile than the local state requires.

This does not imply that the whole column can simply switch back to TG.

The lower saturated block still violates the unsaturated TG head-space predictor assumptions because capacity there belongs to the saturated regime.

The evidence therefore points to a spatially split temporal-ownership problem, not a scalar release-threshold problem.

## Consequence

A separately preregistered successor may test a research-only split temporal policy in which:

- upper unsaturated nodes use the provider-consistent TG temporal construction;
- the lower saturated block retains saturated/KLAG temporal treatment;
- the internal moving interface remains mass-conservative;
- no accepted-state clipping or empirical release threshold is introduced.

Such a test must define the interface storage/flux contract before result exposure.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No release switch or numerical default changed.

`LEGACY_NUMERICS` remains production default.
