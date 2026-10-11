# F-PE-NLGLOB08 closeout — post-stationarity physical tail drift

Date: 2026-09-29

Final status:

`NLGLOB08_POST_STATIONARITY_TAIL_PHYSICALLY_INERT`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@a82721f5ebece9376f83ab9b0fe5df26e42a36f2`

Qualification authority:

- run `36548799864`;
- job `109341595842`;
- conclusion: SUCCESS.

## Closure

NLGLOB08 closes the tail-drift attribution positively.

Every one of the 302 NLGLOB07 S0-certified points is physically inert with respect to all later accepted Newton origins under the unchanged `5e-8 cm` physical water-depth authority.

For the 110 early S0 points:

- inert fraction: 1.0;
- median tail maximum: 0.0 cm;
- 95th percentile tail maximum: about `4.44e-15 cm`;
- maximum tail maximum: about `7.77e-15 cm`.

The result spans both TG and KLAG, all three dynamic-top routes and all four frozen materials.

No route or nonfinite tail pathology was observed.

## Scientific conclusion

The TIMEINT17 endpoint blocker is now narrowed further.

After the S0 state-stationarity condition is reached, continued Newton iteration changes the conserved moisture state only at roundoff-scale water depths on the frozen bank.

The early S0 occurrences that caused NLGLOB07 to fail its temporal-position control are therefore not physically unsafe in this bank. They are early only relative to the current solver's iteration counter, not relative to physically meaningful accepted-state evolution.

This establishes a bounded research basis for test-only early termination at S0.

## What remains unchanged

NLGLOB08 does not alter:

- BALTOL02;
- head or ponding convergence contracts;
- physical accepted-interval mass gates;
- cumulative mass gates;
- MAXIT or backtracking;
- timestep or K staging;
- dynamic-top route physics;
- transaction semantics;
- production source.

## Direct successor

Open:

`F-PE-NLGLOB09 — S0 test-only endpoint replay and physical admissibility`.

The replay must be preregistered before result exposure.

The frozen replay rule should terminate the endpoint solve only when S0 is satisfied and diagnose the reason explicitly.

Replay qualification must require at least:

1. recovery of a substantial fraction of the previously failing 96 trajectories;
2. both TG and KLAG represented;
3. all three routes represented;
4. unchanged physical accepted-interval ledger <= `5e-8 cm`;
5. unchanged cumulative ledger <= `5e-8 cm`;
6. finite route-consistent accepted state;
7. existing head and ponding guards satisfied at termination;
8. accepted state within the NLGLOB08-qualified tail envelope of the later canonical endpoint trajectory;
9. no extra Newton evaluations introduced.

Only a positive replay may return the line to TIMEINT17 same-route dynamic-top mechanism qualification.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB08

BASELINE: `a82721f5ebece9376f83ab9b0fe5df26e42a36f2`

BRANCH: `research/f-pe-nlglob08-tail-drift`

STATUS: closed positive

FILES / COMPONENTS TOUCHED: docs/tests/workflow only

INTERFACES CHANGED: none

INVARIANTS AFFECTED: 7, 13, 23, 24, 25, 26, 30

IMPLEMENTATION STATUS: observational tail-drift attribution persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB08_POST_STATIONARITY_TAIL_PHYSICALLY_INERT`

DEPENDENCIES / BLOCKERS: test-only replay not yet executed

NEXT SAFE STEP: preregister and execute NLGLOB09 S0 endpoint replay

RECOVERY POINT: this closeout plus NLGLOB08 result/run authority

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
