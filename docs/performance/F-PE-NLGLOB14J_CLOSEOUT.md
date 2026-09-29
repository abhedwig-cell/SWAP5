# F-PE-NLGLOB14J closeout — dry-phase lower-block mass redistribution attribution

Date: 2026-09-29

Final status:

`NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@6fe778ffb5a55f6fb3cc13b9c1a43b71a4641096`

Qualification authority:

- run `36567115728`;
- job `109401658928`;
- conclusion: SUCCESS.

## Closure

NLGLOB14J closes positively.

All eight dry-phase fixtures show physically consistent downward redistribution supporting the upward expansion of the contiguous lower saturated block.

Across all fixtures:

- lower-region storage increases;
- upper-cap storage decreases;
- total profile storage decreases;
- every block-expansion interval carries downward flux across the moving block edge;
- bottom flux remains zero;
- physical mass remains at roundoff scale;
- no state or saturation-indicator inconsistency appears.

## Scientific conclusion

The expanding saturated lower block is not a hidden mass defect.

It is an internally conservative redistribution pattern under persistent saturated-KLAG evolution.

This resolves the main physical concern raised by NLGLOB14I and removes the prohibition on extending the drying horizon for release attribution.

## Direct successor

Open:

`F-PE-NLGLOB14K — extended drying full-profile desaturation attribution`.

The successor must remain observational.

Use the same eight forcing-reversal fixtures and persistent saturated-KLAG policy, but extend the dry horizon to a single preregistered longer duration.

The primary release-state quantity is threshold-free:

`SATURATED_SET_EMPTY`

meaning zero active nodes satisfy both existing saturation indicators.

No TG release switch is implemented in NLGLOB14K.

Only after a stable empty saturated set is observed may a separately preregistered state-machine replay switch back to unsaturated TG.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14J

BASELINE: `6fe778ffb5a55f6fb3cc13b9c1a43b71a4641096`

BRANCH: `research/f-pe-nlglob14j-block-redistribution-r2`

STATUS: closed positive attribution

TEST STATUS: focused eight-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`

NEXT SAFE STEP: preregister NLGLOB14K extended-drying full-profile desaturation attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
