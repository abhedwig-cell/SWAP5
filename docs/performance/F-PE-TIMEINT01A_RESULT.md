# F-PE-TIMEINT01A result — smooth-regime temporal-order characterization

Date: 2026-09-28

Status: `CURRENT_REFERENCE_FIRST_ORDER_SUPPORTED`

Authority:

- canonical base: `integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`;
- Actions run: `36439604361`;
- job: `108986356263`;
- conclusion: SUCCESS.

## Fixed-step ladder

Tested dt:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

Cases:

- B01/DRY;
- B01/TRANSITION;
- O05/DRY;
- O05/TRANSITION.

All four cases completed.

## Observed top-head orders

B01/DRY:

- coarse triplet: 0.985;
- refined triplet: 0.993.

B01/TRANSITION:

- coarse: 0.914;
- refined: 0.957.

O05/DRY:

- coarse: 0.676;
- refined: 0.853.

O05/TRANSITION:

- coarse: -1.208;
- refined: 0.492.

Median over all usable top-head estimates:

`p = 0.883`.

The preregistered first-order support interval was [0.7, 1.3].

Result:

`PASS`.

## Interpretation

B01 is already clearly in a first-order asymptotic regime over the chosen ladder.

O05 approaches that behavior more slowly. O05/TRANSITION is not asymptotic on the coarsest triplet, but the refined estimate moves toward first-order rather than toward second-order behavior.

Bottom-head estimates for the same ladder are near order one for all four cases.

The empirical result therefore supports the source-derived conclusion that the current Reference SWKIMPL=0 temporal scheme is effectively first-order in smooth operation.

This study does not claim a useful order at dynamic-top regime switches.
