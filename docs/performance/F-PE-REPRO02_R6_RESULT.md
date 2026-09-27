# F-PE-REPRO02 R6 result — optional-direction physical-solve invariance

Date: 2026-09-26

Status: `OPTIONAL_DIRECTION_NOT_CAUSAL`

## Protocol

The same difficult mode-5 request was executed as:

- PLAIN: direct `solver%solve`;
- DIRECTION: `solve_with_accepted_step_direction`.

Six difficult origins, offsets -0.001, 0 and +0.001 cm, three repetitions per point.

## Result

- PLAIN: 18/18 converged;
- DIRECTION: 18/18 converged.

Per point, the two arms had identical nonlinear and backtracking counts.

Examples:

- B01 wet +0.001 cm: both 3 nonlinear / 4 backtracking;
- O14 mid -0.001 cm: both 4 nonlinear / 5 backtracking;
- zero displacement: both 1 nonlinear / 1 backtracking.

## Conclusion

Preparing optional accepted-direction factorization scratch does not cause the participant/direct divergence.

The direct Reference solver converges on all tested difficult requests both with and without directional processing.

The failure is therefore localized above the direct physical-solver entry, within serialized backend / transaction request-state materialization or execution.

R7 will capture the serialized backend's actual solver request immediately before the physical solve and compare it to the successful direct request.
