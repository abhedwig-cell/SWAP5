# F-PE-NLGLOB14Z18 closeout — post-event UPPER ownership boundary

Date: 2026-09-30

Final status:

`QUALIFIED_Z18_POST_EVENT_UPPER_OWNERSHIP_BOUNDARY_ATTRIBUTION`

Qualification authority:

- run `36697938929`;
- HEAD fine probe job `109835480588`;
- RUNOFF fine probe job `109835480609`.

## Closure

Z18 closes positively as a diagnostic attribution.

For both fine split fixtures, the first candidate after accepted `12:16 -> 13:16`:

- converges in 2 nonlinear iterations;
- is finite;
- is mass-clean;
- has exact rollback authority;
- preserves provider-faithful `surface-flux`;
- has contiguous paired saturation geometry;
- saturates exactly node 12 in the current upper domain.

The only failed frozen gate is strict upper-domain unsaturation.

The resulting candidate tail is:

`12:16`

from accepted origin tail:

`13:16`.

## Mechanistic conclusion

The Z15 post-event `UPPER` boundary is an ownership/domain-definition boundary, not a failed physical solve.

The current retreat-only ownership semantics cannot represent this clean immediate reverse candidate.

## Direct successor

Preregister a bidirectional accepted-state ownership workunit for the immediate post-event transition:

`13:16 -> 12:16`

with ownership:

`face 12/13 -> face 11/12`.

Do not introduce fitted thresholds or hysteresis in the first successor.

The immediate question is whether exact accepted-state reclassification is transactionally valid and whether it produces chatter or a stable reverse move.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z18

BRANCH: `research/f-pe-nlglob14z18-post-event-upper-attribution`

QUALIFICATION RUN: `36697938929`

QUALIFICATION STATUS: `QUALIFIED_Z18_POST_EVENT_UPPER_OWNERSHIP_BOUNDARY_ATTRIBUTION`

NEXT SAFE STEP: bidirectional accepted-state ownership reclassification of the exact `13:16 -> 12:16` candidate.

## Production boundary

No production source/default change.
