# F-PE-REPRO02 R1 result — rejection mechanism

Date: 2026-09-26

Status: `SUPERSEDED_BY_R13_ORDERED_TRACE`

## Protocol

For all six difficult PROFILE06 origins, five fresh-process repetitions were run at:

- -0.001 cm;
- 0;
- +0.001 cm.

The bridge exposed serialized Reference backend diagnostics after every trial attempt.

## Result

All zero-displacement controls passed.

Typical zero-displacement signature:

- participant status 0;
- solver status 1 = converged;
- 1 nonlinear/Jacobian/linear iteration;
- 1 backtracking attempt;
- 0 internal retries;
- temporal certificate available;
- normalized temporal indicator 0.

All rejected nonzero cases, except the known B01-mid +0.001 cm pass, failed with the same structural signature:

- participant status 6;
- solver status 2 = retry advised;
- nonlinear iterations = 16;
- Jacobian builds = 16;
- linear solves = 16;
- backtracking attempts approximately 78-114;
- internal retries = 1;
- temporal status = not run;
- temporal indicator unavailable;
- temporal certificate unavailable.

B01-mid +0.001 cm passed with:

- solver status converged;
- 2 nonlinear iterations;
- 2 backtracking attempts;
- temporal certificate available;
- normalized temporal indicator about 0.117, below the 1e-5 cm budget.

## Conclusion

**Superseded by R13.** This result describes the final physical attempt after transaction retry exhaustion, not the first rejection in the ordered retry chain.

R13 demonstrates that every tested nonzero point first completes a physical solve and is rejected by the temporal certificate. The later nonlinear failure is a downstream retry-path consequence.

## Next discriminator

The production FGC44 participant parameters currently cap the local solve at:

- max nonlinear iterations = 16;
- max backtracking = 8.

The successful offline P0 direct-solver characterization uses:

- max nonlinear iterations = 48;
- max backtracking = 16.

R2 therefore tests whether the difficult-origin participant frontier is primarily an effort-cap effect.

No production policy change is implied by R1.
