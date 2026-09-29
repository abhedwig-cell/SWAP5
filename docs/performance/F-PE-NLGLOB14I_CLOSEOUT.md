# F-PE-NLGLOB14I closeout — dry-phase saturated-set migration attribution

Date: 2026-09-29

Final status:

`NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@cf0430071c060d29ee1346ee2f21142fdfe19438`

Qualification authority:

- run `36566315440`;
- job `109398993141`;
- conclusion: SUCCESS.

## Closure

NLGLOB14I closes the saturated-set migration question as mixed under the preregistered retreat/persistence classifications.

The actual spatial signal is nevertheless fully consistent across all eight fixtures:

- the saturated set is always one contiguous lower block;
- it begins with only node 16 saturated;
- it ends with nodes 3 through 16 saturated;
- the top two nodes remain unsaturated at the end;
- profile storage decreases and ponding vanishes;
- bottom flux remains zero;
- mass remains at roundoff.

Thus the lower saturated block expands upward during drying.

## Scientific conclusion

The current forcing-reversal fixture does not expose a release transition.

It also shows that release cannot be inferred from a retreating saturation front.

Before selecting release semantics, the upward saturated-block expansion must be reconciled with compartment-scale water redistribution.

## Direct successor

Open:

`F-PE-NLGLOB14J — dry-phase compartment redistribution attribution`.

The successor must remain observational.

For the same eight fixtures compare the first and final accepted dry-phase states and quantify:

1. per-node water-content change;
2. per-node storage-depth change;
3. total positive storage gain in wetting nodes;
4. total storage loss in drying nodes;
5. location of positive and negative storage changes;
6. change in saturated-node count;
7. net profile storage change;
8. top and bottom boundary contributions.

The first question is whether the upward saturated-block expansion is supported by explicit lower-profile storage gain that is balanced by larger upper-profile losses.

No internal flux reconstruction or release switch is authorized yet.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14I

BASELINE: `cf0430071c060d29ee1346ee2f21142fdfe19438`

BRANCH: `research/f-pe-nlglob14i-saturated-set-migration-r2`

STATUS: closed mixed attribution

TEST STATUS: focused eight-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`

NEXT SAFE STEP: preregister NLGLOB14J compartment redistribution attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
