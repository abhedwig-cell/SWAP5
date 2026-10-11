# F-PE-NLGLOB14J closeout — dry-phase lower-block mass redistribution attribution

Date: 2026-09-29

Final status:

`NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`

Canonical authority rechecked before closeout through:

`integration/f-ci-canonical@6fe778ffb5a55f6fb3cc13b9c1a43b71a4641096`

The intervening canonical delta is outside the NLGLOB14J temporal-policy and forcing-reversal dependency surface.

Qualification authority:

- run `36567029032`;
- job `109401365959`;
- conclusion: SUCCESS.

## Closure

NLGLOB14J closes positively.

All eight dry forcing-reversal fixtures show the same mass-consistent redistribution pattern:

- the lower saturated block expands upward;
- nodes 3:16 gain about 0.112 to 0.117 cm storage;
- nodes 1:2 lose substantially more storage;
- total profile storage decreases;
- bottom flux remains zero;
- every one of the 13 expansion intervals per fixture has downward edge flux.

The saturated-block expansion is therefore physically supported by internal redistribution.

## Scientific conclusion

The unresolved release problem is not a conservation or saturated-set consistency problem.

It is now a mode-ownership question.

Persistent saturated KLAG currently remains active for the whole column after the surface has returned to flux control and the upper profile has become unsaturated, because a lower saturated block remains.

Whether that is the intended temporal policy must be evaluated explicitly before introducing a release switch.

## Direct successor

Open:

`F-PE-NLGLOB14K — mixed-profile temporal-mode ownership attribution`.

The successor must remain observational first.

For the same eight dry fixtures, identify the first accepted interval where:

1. surface route is `surface-flux`;
2. ponding is zero;
3. top node is unsaturated;
4. a contiguous lower saturated block still exists.

At and after that state compare:

- full-column persistent KLAG work and state evolution;
- the unsaturated upper-region state;
- saturated lower-block extent;
- physical mass;
- whether the existing TG admissibility conditions would be satisfied in the upper region.

No switch back to TG is implemented in the first phase.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14J

BASELINE: `00583ebb0ff8820c8c5ba9c5ba00d5bec7fc5a3a`

BRANCH: `research/f-pe-nlglob14j-block-redistribution`

STATUS: closed positive

TEST STATUS: focused eight-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`

NEXT SAFE STEP: preregister NLGLOB14K mixed-profile temporal-mode ownership attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
