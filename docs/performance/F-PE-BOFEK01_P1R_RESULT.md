# F-PE-BOFEK01 P1/P1R result — independent oracle limitation

Date: 2026-09-28

Status: `INDEPENDENT_FIXED_STEP_ORACLE_LIMITED`

Authority:

- canonical: `integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`;
- P1 Actions run: `36413551568`;
- P1R Actions run: `36413798107`;
- P1R oracle-solvability job: `108899998894`.

## P1 result

The preregistered independent fixed-step oracle used:

- coarse dt = 0.0005 d;
- fine dt = 0.00025 d;
- strict current solver controls;
- BALTOL02 effective balance floor;
- fixed-K dynamic-top `SWKIMPL=0`.

Only 1 of 16 screening cases produced a complete temporally resolved coarse/fine oracle pair.

Therefore P1 could not adjudicate the timestep/head-tolerance candidates broadly enough to qualify any strict policy.

The single resolved case did not rescue any candidate: all tested policies failed the already frozen oracle head-accuracy gate there.

## P1R result

P1R tested whether insufficient nonlinear iteration capacity caused the fixed-step oracle failures.

Frozen temporal levels remained unchanged. Only Reference computation effort changed:

- O8: MAXIT=8;
- O20: MAXIT=20;
- O48: MAXIT=48;
- max_backtracking remained 8;
- all physical equations and tolerances remained unchanged.

Result:

- O8: complete pairs 1/16, resolved pairs 1/16;
- O20: complete pairs 1/16, resolved pairs 1/16;
- O48: complete pairs 1/16, resolved pairs 1/16.

Thus increasing nonlinear iteration capacity from 8 to 48 does not recover the independent fixed-step oracle.

## Interpretation

The P1 failures are not attributable to the already-fixed BALTOL02 balance floor and are not repaired by additional Newton iteration allowance.

Under the current Reference solver authority, forcing most hydraulic/regime cases to remain at the two preregistered tiny fixed timesteps is not a broadly usable independent temporal oracle.

Per preregistration, the study does not chase still smaller dt values post hoc.

## Consequence for policy selection

P0 remains valid negative policy evidence:

- no tested simple parameter independently met the frozen >=8% deterministic-work improvement plus strict adaptive-reference gates.

P1/P1R do not overturn that result. They only show that an independent fixed-step truth model could not be established broadly enough to reconsider P0 trajectory failures.

No candidate advances to:

- interaction optimization;
- holdout validation;
- production timing qualification;
- production numerical-policy change.

## Final technical conclusion

`NO_STRICT_POLICY_CANDIDATE_AND_INDEPENDENT_ORACLE_LIMITED`

This does not prove that no faster strict temporal strategy can exist. It does establish that the tested simple policy changes are not qualified and that the attempted refined fixed-step oracle cannot currently support a stronger claim.

