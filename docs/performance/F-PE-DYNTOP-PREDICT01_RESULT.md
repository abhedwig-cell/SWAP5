# F-PE-DYNTOP-PREDICT01 result — origin-frozen surface classifier

Date: 2026-09-28

Status: `CLOSED_SURFACE_ONLY_FALSE_SAFE`

Authority:

- canonical base: `integration/f-ci-canonical@94e265d18200b40d942184809e1e45694aea850f`;
- Actions run: `36418280174`;
- classifier job: `108914564813`;
- conclusion: SUCCESS.

## Calibration evidence

27 large-step intervals were labelled using full versus two-half local comparison:

- SAFE: 19;
- UNSAFE: 8;
- one calibration case later became incomplete through solver nonconvergence, but all labels observed before that point remain valid research evidence.

## Frozen rules

P0 through P3 all behaved identically:

- true safe: 19;
- false safe: 4;
- true unsafe: 4;
- false unsafe: 0;
- safe coverage: 100%.

All four therefore fail the preregistered zero-false-safe gate.

## Interpretation

The analytical origin-frozen surface calculation is excellent at identifying clearly ponded/runoff-sensitive intervals, but four unsafe intervals still originate from the ordinary non-ponded flux route.

Therefore current surface-regime prediction alone cannot safely decide whether a large Richards interval may be executed without temporal refinement.

## Decision

No surface-only classifier advances.

A successor may combine surface information with richer accepted-state history, but may not add material/regime identifiers.
