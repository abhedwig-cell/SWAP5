# ROM-PURPOSE P4: extended representation frontier

## Scientific question

P4 asks where the purpose-aligned vertical representation frontier lies beyond the eight-state limit tested in P3, and when remaining Layer-ROM error can first be distinguished from error caused by using the same coarse spatial partition in conventional Richards.

P3 remains closed. P4 does not reinterpret or replace its evidence.

## Why P4 exists

P3 established two facts that must be kept separate:

1. purpose-aligned placement contains more response-relevant information than equal-dimension uniform placement;
2. neither the S8 nor G8 Layer-ROM representation reached the frozen R512_T32 versus R2048_T32 comparator for B01 or B14.

For groundwater, conventional Richards on the same G8 partition also missed the comparator. Therefore a Layer-ROM closure deficit could not be identified at eight states. For surface response, the S8 same-partition Richards diagnostic was outside the frozen numerical qualification domain.

The next falsifiable question is therefore not which new closure to use. It is whether additional prospectively placed vertical information or spatial resolution first makes the comparator reachable.

## Frozen representation ladders

### SURF_P

The P3 S8 partition is inherited unchanged. S12 and S16 add nested support along the near-surface and surface-to-80-cm propagation path while retaining the P3 boundaries.

- S8: 0, 10, 20, 30, 40, 50, 60, 80, 160 cm
- S12: 0, 5, 10, 20, 30, 40, 50, 60, 70, 80, 100, 120, 160 cm
- S16: 0, 5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 70, 80, 100, 120, 140, 160 cm

### GW_LB

The P3 G8 partition is inherited unchanged. G12 and G16 retain progressively fine support near the lower boundary and add transmission information above it.

- G8: 0, 80, 100, 120, 130, 140, 150, 155, 160 cm
- G12: 0, 40, 80, 100, 120, 130, 140, 145, 150, 152.5, 155, 157.5, 160 cm
- G16: 0, 20, 40, 60, 80, 100, 110, 120, 130, 135, 140, 145, 150, 152.5, 155, 157.5, 160 cm

No state count above 16 may be added after P4 response.

## Fresh blind workload

P4 does not use the P3 candidate-response histories for its primary decision.

SURF_P uses S17-S20 with effective-saturation anchors 0.73, 0.81, 0.87 and 0.93 and the inherited alternating WET/DRY forcing semantics.

GW_LB uses G17-G20 with effective-saturation anchors 0.72, 0.80, 0.85 and 0.90 and the inherited lower-head rise/fall semantics.

Reference target, comparator, metrics and numerical qualification mathematics are inherited unchanged.

## Matched attribution design

Every frozen P4 partition is evaluated twice:

1. Layer-ROM with CURRENT_LAYER_FACE;
2. conventional Richards on exactly the same vertical partition.

The attribution is rung-specific.

| Layer-ROM | same-partition Richards | Interpretation |
| --- | --- | --- |
| misses | misses | representation or spatial resolution remains limiting |
| misses | reaches | propagation/closure deficit is supported at this rung |
| reaches | reaches | representation is sufficient within the frozen comparator envelope |
| reaches | misses | anomalous ordering; report directly, do not infer a closure advantage |
| any | numerically unavailable | no closure attribution |

A closure deficit can therefore only be claimed after the same-partition Richards route is independently numerically qualified.

## Boundaries

P4 does not:

- change Reference Richards or RossFast;
- change production physics;
- introduce or tune a new closure family;
- adjudicate application acceptance;
- admit a production ROM;
- make a speedup claim;
- claim a mathematical or universal minimum state count.

Application acceptance remains under ROM-ACCEPT.

## Stop rule

P4 stops at the 16-state/cell rung. If neither method reaches the comparator by then, the result is a bounded representation/resolution frontier failure, not permission to extend the ladder post hoc.
