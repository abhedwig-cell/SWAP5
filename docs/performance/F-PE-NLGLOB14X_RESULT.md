# F-PE-NLGLOB14X result — further saturated-block retreat and disappearance control exposure

Date: 2026-09-29

Status:

`QUALIFIED_FURTHER_MONOTONE_RETREAT_CONTROL_EXPOSURE`

Qualification authority:

- workflow run: `36605738694`;
- job: `109534152914`;
- conclusion: SUCCESS.

An earlier run `36605557218` misclassified the known pre-retreat saturation growth as a post-retreat reversal. Commit `698908b68ecd3d839f7073e6ea3d07626de85109` repaired only that attribution, so reversal is evaluated after the independently established second retreat, as preregistered.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

## Frozen question

Does the persistent saturated-KLAG control continue to retreat beyond the NLGLOB14V second-retreat state `5:16`, and does the saturated block disappear within the staged horizon up to 0.80 d?

## Coverage

PASS.

All 8 HEAD/RUNOFF x four-dt fixtures:

- complete the staged 0.80 d horizon;
- remain finite;
- preserve paired h/theta saturation indicators;
- preserve contiguous lower saturated geometry;
- preserve physical mass;
- show further accepted retreat beyond node 5;
- show no post-second-retreat reversal;
- show no skipped retreat node.

Aggregate classification:

`QUALIFIED_FURTHER_MONOTONE_RETREAT_CONTROL_EXPOSURE`.

Complete saturated-block disappearance is not observed in any fixture by 0.80 d.

## Further physical retreats

After the qualified second retreat `4:16 -> 5:16`, every fixture shows:

1. `5:16 -> 6:16`;
2. `6:16 -> 7:16`.

### Third retreat

HEAD:

- dt 2.5e-4 d: 0.25050 d;
- dt 1.25e-4 d: 0.250625 d;
- dt 6.25e-5 d: 0.25050 d;
- dt 3.125e-5 d: 0.2504375 d.

RUNOFF:

- dt 2.5e-4 d: 0.24750 d;
- dt 1.25e-4 d: 0.24750 d;
- dt 6.25e-5 d: 0.2474375 d;
- dt 3.125e-5 d: 0.247375 d.

### Fourth retreat

HEAD:

- dt 2.5e-4 d: 0.73125 d;
- dt 1.25e-4 d: 0.731375 d;
- dt 6.25e-5 d: 0.7313125 d;
- dt 3.125e-5 d: 0.73125 d.

RUNOFF:

- dt 2.5e-4 d: 0.72800 d;
- dt 1.25e-4 d: 0.728125 d;
- dt 6.25e-5 d: 0.728125 d;
- dt 3.125e-5 d: 0.72809375 d.

These are accepted-state exposure times, not separately root-localized event-time qualifications.

## Geometry and monotonicity

After the second retreat, all accepted changes are one-node retreats of the contiguous lower saturated tail.

No fixture shows:

- reverse expansion after retreat;
- skipped retreat node;
- noncontiguous saturated set;
- indicator inconsistency.

At 0.80 d all fixtures have final saturated set:

`nodes 7:16`.

Thus the lower saturated block is still present but continues to retreat physically.

## Physical mass

The control remains roundoff-clean over the extended horizon.

Across the selected 0.80 d records:

- maximum accepted-interval ledger: about `2.36e-14 cm`;
- maximum cumulative ledger: about `5.87e-13 cm`.

No process failure occurs.

## Scientific interpretation

The moving saturated lower edge is not a one-off event.

Under unchanged dry forcing the physical control exhibits a sustained sequence:

`4:16 -> 5:16 -> 6:16 -> 7:16`.

The event spacing grows substantially with depth/time, so full disappearance is not justified by simple extrapolation and is not observed by the preregistered 0.80 d limit.

The immediate research question is therefore whether accepted split ownership can follow both newly exposed physical transitions without chatter, interface duplication or loss of mass conservation.

## Consequence

A separately preregistered successor may carry the accepted split trajectory through 0.80 d and require state-derived ownership moves:

- face 4/5 -> 5/6;
- face 5/6 -> 6/7;

with the persistent-KLAG times used only as comparators.

Complete disappearance remains unqualified and must not be assumed.

## Production boundary

Research only.

No production `src/**` change.

No production temporal ownership or numerical default changed.

`LEGACY_NUMERICS` remains production default.
