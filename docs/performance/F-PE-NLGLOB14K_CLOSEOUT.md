# F-PE-NLGLOB14K closeout — mixed-profile temporal-mode ownership attribution

Date: 2026-09-29

Final status:

`NLGLOB14K_SPATIALLY_SPLIT_TEMPORAL_OWNERSHIP_SIGNAL`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@667c4b76768f760403e0b58383c386686baa3784`

Qualification authority:

- run `36567914264`;
- job `109404337417`;
- conclusion: SUCCESS.

## Closure

NLGLOB14K closes positively.

All eight frozen dry forcing-reversal fixtures enter a mixed-profile state in which:

- surface route has returned to `surface-flux`;
- ponding is absent;
- the upper profile is unsaturated;
- a contiguous lower saturated block persists.

From mixed-profile onset onward, every upper-region node in every fixture remains compatible with the existing provider-consistent TG temporal mechanism, while the lower block remains saturated and physically valid.

## Scientific conclusion

Persistent saturated KLAG no longer has a physically exclusive claim on the whole column once mixed-profile onset has occurred.

The evidence supports spatially split temporal ownership:

- unsaturated upper region: TG-admissible;
- saturated lower block: still requires saturated temporal treatment.

A single whole-column release switch would discard this spatial distinction.

The next research step should therefore test a split-ownership temporal composition with an explicit conservative interface contract, not invent a scalar desaturation threshold.

## Direct successor

Open:

`F-PE-NLGLOB14L — split temporal ownership conservative interface experiment`.

The successor must preregister before implementation:

1. how the upper TG region and lower saturated/KLAG region partition storage;
2. the exact moving internal interface flux sign and ownership;
3. how the interface moves when the saturated block edge changes;
4. how no water is duplicated or lost at region transitions;
5. how accepted-state continuity and rollback remain transactional;
6. how smooth unsaturated TIMEINT16C second-order authority is preserved when no split is active.

The first implementation must remain research/test-only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14K

BASELINE: `e803842a434d792ba5209f71e3681bd78be90560`

CANONICAL RECONCILED THROUGH: `667c4b76768f760403e0b58383c386686baa3784`

BRANCH: `research/f-pe-nlglob14k-mixed-profile-ownership`

STATUS: closed positive

TEST STATUS: focused 8-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14K_SPATIALLY_SPLIT_TEMPORAL_OWNERSHIP_SIGNAL`

NEXT SAFE STEP: preregister NLGLOB14L split temporal ownership conservative interface experiment

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
