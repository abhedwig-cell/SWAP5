# F-PE-REPRO02 R3 result — minimum-step sensitivity

Date: 2026-09-26

Status: `MINIMUM_STEP_NOT_CAUSAL`

## Protocol

With max nonlinear/backtracking fixed at 48/16, the difficult-origin +/-0.001 cm participant trials were repeated for:

- 1e-8 day;
- 1e-9 day;
- 1e-10 day;
- 1e-11 day;
- 1e-12 day.

## Result

Every minimum-step setting produced the same outcome:

- 1 of 12 signed points passed;
- 11 of 12 failed with solver status retry-advised;
- B01-mid +0.001 cm remained the only pass.

The nonlinear/backtracking signatures were unchanged across the minimum-step sweep.

## Conclusion

The participant/direct-P0 difference is not caused by max iterations, max backtracking or minimum-step duration.

The next experiment compares the direct P0 solve with and without the serialized legacy-context binding that the participant applies immediately before solving.
