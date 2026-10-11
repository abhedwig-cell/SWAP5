# F-PE-NLGLOB14H closeout — dry-phase saturation-manifold drift attribution

Date: 2026-09-29

Final status:

`NLGLOB14H_MIXED_DRY_MANIFOLD_DRIFT`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@c963cacfc86e3f0df5f318ac6a6ffce23bf92225`

Qualification authority:

- run `36565717503`;
- job `109397001318`;
- conclusion: SUCCESS.

## Closure

NLGLOB14H closes the event-node drift question as mixed under the frozen classifications.

The result does not support a longer-horizon release fixture based on monotone event-node drying.

Across all eight valid fixtures:

- profile storage decreases;
- ponding disappears;
- the surface route returns to surface-flux;
- bottom flux remains zero;
- the original event node is node 16;
- event-node theta remains exactly saturated;
- event-node pressure head increases to strongly positive values.

This is neither a pinned state nor a monotone approach to desaturation.

## Scientific conclusion

Release cannot be defined safely from the original saturation-event node alone.

The spatial saturated set must be examined explicitly.

The relevant next question is whether drying causes:

- retreat of saturation from upper nodes toward the lower boundary;
- persistence of a bottom saturated region while the surface is already unsaturated;
- or a physically inconsistent saturated-set pattern.

That attribution is needed before any release state machine can be defined.

## Direct successor

Open:

`F-PE-NLGLOB14I — dry-phase saturated-set migration attribution`.

The successor must remain observational and use the same eight forcing-reversal fixtures.

For every accepted dry-phase interval, derive:

- count of saturated nodes;
- shallowest and deepest saturated node;
- whether saturated nodes form one contiguous lower block;
- first interval where the top node is unsaturated;
- first interval where all upper nodes above the persistent lower saturated block are unsaturated;
- relationship to surface route and ponding;
- physical mass.

No release switch is implemented.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14H

BASELINE: `c963cacfc86e3f0df5f318ac6a6ffce23bf92225`

BRANCH: `research/f-pe-nlglob14h-dry-manifold-drift`

STATUS: closed mixed attribution

TEST STATUS: focused eight-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14H_MIXED_DRY_MANIFOLD_DRIFT`

NEXT SAFE STEP: preregister NLGLOB14I saturated-set migration attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
