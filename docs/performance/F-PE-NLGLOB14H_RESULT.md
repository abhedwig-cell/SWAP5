# F-PE-NLGLOB14H result — dry-phase saturation-manifold drift attribution

Date: 2026-09-29

Status:

`NLGLOB14H_MIXED_DRY_MANIFOLD_DRIFT`

Canonical base:

`integration/f-ci-canonical@c963cacfc86e3f0df5f318ac6a6ffce23bf92225`

Qualification authority:

- workflow run: `36565717503`;
- job: `109397001318`;
- conclusion: SUCCESS.

## Coverage

PASS.

All 8 frozen O05/TG forcing-reversal fixtures:

- enter persistent saturated mode exactly once;
- execute the full 0.012 d horizon;
- satisfy the frozen dry forcing;
- remain finite;
- preserve physical mass.

Process failures:

`0`.

## Aggregate result

Frozen classification:

`NLGLOB14H_MIXED_DRY_MANIFOLD_DRIFT`.

Counts:

- moving-toward-desaturation fixtures: `0`;
- pinned fixtures: `0`;
- saturation-indicator inconsistencies: `0`.

All eight profiles exhibit net drying.

Physical mass remains near roundoff:

- max accepted-interval ledger about `2.36e-14 cm`;
- max cumulative ledger about `1.69e-14 cm`.

## Structured observed pattern

The result is mixed only relative to the preregistered two-way classification. The observed behavior itself is highly consistent.

Across all 8 fixtures:

- the original saturation event node is node 16;
- event-node water content remains exactly at `theta_s` throughout the dry phase;
- event-node pressure head increases strongly rather than decreasing;
- ponding falls to zero;
- the provider route changes from ponded HEAD/RUNOFF to surface-flux;
- profile storage decreases materially;
- bottom flux remains zero.

Event-node pressure-head change is positive in every fixture:

- HEAD fixtures: roughly +124 to +125 cm;
- RUNOFF fixtures: roughly +126 to +127 cm.

Final event-node pressure head is about 131 to 132 cm.

Thus the dry forcing removes profile water while the bottom event node remains on the saturated constitutive manifold and becomes more positively pressurized.

## Interpretation

The absence of release is not explained by an insufficiently long monotone approach toward negative pressure head.

Nor is the event node representationally pinned.

The remaining question is spatial.

The original event node is the bottom node. A whole-profile release criterion tied to desaturation of that original node may therefore remain false while the upper profile has already dried and the surface route has returned to flux control.

The next bounded attribution should examine movement of the saturated set through the full profile, rather than extending the horizon or inventing a release threshold.

## Consequence

Do not extend the drying horizon yet.

Do not infer a release criterion from the original event node alone.

Open a separately preregistered full-profile saturated-set migration attribution.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
