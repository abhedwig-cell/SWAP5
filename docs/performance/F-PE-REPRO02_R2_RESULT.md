# F-PE-REPRO02 R2 result — solver effort caps

Date: 2026-09-26

Status: `ITERATION_AND_BACKTRACK_CAPS_NOT_CAUSAL`

## Protocol

The six difficult origins were tested at +/-0.001 cm under:

- 16 nonlinear / 8 backtracking;
- 32 / 8;
- 16 / 16;
- 32 / 16;
- 48 / 16.

All other controls were unchanged.

## Result

For every limit combination:

- exactly 1 of 12 signed nonzero points passed;
- the passing point was B01-mid +0.001 cm;
- the other 11 points remained participant status 6 / solver status retry-advised.

Increasing nonlinear effort simply extended the failing path.

Examples:

- 16/8 failure: 16 nonlinear iterations and roughly 80-114 backtracking attempts;
- 48/16 failure: 48 nonlinear iterations and roughly 649-738 backtracking attempts.

Temporal certification remained unavailable on the failed paths.

## Conclusion

The collapsed participant displacement frontier is not caused by too-small max-iteration or max-backtracking caps.

## Remaining controlled difference

The successful P0 direct-solver route uses:

`min_step_duration = 1e-10 day`

The participant route uses:

`min_step_duration = 1e-8 day`

Failed participant solves report one internal retry.

R3 therefore tests minimum-step sensitivity while holding the larger 48/16 effort envelope fixed.

No production numerical-policy change is admitted by R2.
