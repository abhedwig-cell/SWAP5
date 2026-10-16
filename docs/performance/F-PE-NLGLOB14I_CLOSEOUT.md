# F-PE-NLGLOB14I closeout — dry-phase saturated-set migration attribution

Date: 2026-09-29

Final status:

`NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@19478ed94d3161fcd2b95a91bab6100a228d6c75`

Qualification authority:

- run `36566195803`;
- job `109398591216`;
- conclusion: SUCCESS.

## Closure

NLGLOB14I closes the saturated-set migration question under the frozen 0.012 d forcing-reversal fixture.

All eight valid trajectories show the same structured behavior:

- saturated nodes remain a contiguous lower block;
- saturated-node count grows from 1 to 14;
- no count decrease occurs;
- the top remains unsaturated at the end;
- profile storage decreases;
- mass remains at roundoff scale;
- no head/theta saturation-indicator inconsistency occurs.

This is neither the preregistered retreat case nor the constant persistent-block case, so the formal classification remains:

`NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`.

## Scientific conclusion

Drying does not release the persistent saturated mode by retreat of the lower saturated set.

Instead, the lower saturated block expands upward while net profile water is removed.

That behavior must be explained by internal redistribution before a physically defensible release state machine can be defined.

Do not infer a release threshold from:

- the original event node;
- saturated-node count alone;
- surface route alone;
- ponding disappearance alone.

## Direct successor

Open:

`F-PE-NLGLOB14J — dry-phase lower-block expansion mass-redistribution attribution`.

The successor must remain observational.

For every accepted dry-phase interval, quantify at least:

1. moving saturated-block edge;
2. storage change above the edge;
3. storage change inside the saturated block;
4. vertical flux across the edge;
5. top evaporative removal;
6. bottom flux;
7. local and global mass closure.

The primary question is whether downward redistribution from drying upper nodes accounts for the expanding saturated lower block.

No longer-horizon fixture and no release switch should be opened before that attribution.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14I

BASELINE: `c963cacfc86e3f0df5f318ac6a6ffce23bf92225`

CANONICAL RECONCILED THROUGH: `19478ed94d3161fcd2b95a91bab6100a228d6c75`

BRANCH: `research/f-pe-nlglob14i-saturated-set-migration`

STATUS: closed mixed attribution

TEST STATUS: focused eight-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`

DEPENDENCIES / BLOCKERS: physical release semantics remain unqualified

NEXT SAFE STEP: preregister NLGLOB14J mass-redistribution attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
