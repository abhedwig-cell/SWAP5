# F-PE-TIMEINT04 P0 result — BDF2 nonlinear-path reconstruction

Date: 2026-09-28

Status: `TOTAL_BALANCE_ROUNDOFF_STALL_IDENTIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@bd9a3fcc54000b9cdafee77f4a20e739a5abfaf2`;
- Actions run: `36444803211`;
- trace job: `109004193490`;
- conclusion: SUCCESS.

## Frozen case

B01, fixed infiltration 4 cm/day, zero bottom flux, dt=0.00125 d, SWKIMPL=1, MAXIT=8.

Compared:

- BE_KIMPL;
- BDF2_KIMPL.

Steps 24 and 25 were traced per nonlinear iteration without changing solver decisions.

## Step 24

Both methods converge normally.

BE_KIMPL:
- 4 nonlinear iterations;
- every full Newton step passes the progress test;
- no backtracking below factor 1;
- final max local residual about 2.75e-13 cm/day;
- final total residual about -8.85e-13 cm/day.

BDF2_KIMPL:
- 4 nonlinear iterations;
- every full Newton step passes;
- no reduced line-search factor;
- final max local residual about 3.84e-13 cm/day;
- final total residual about -9.95e-13 cm/day.

## Step 25

BE_KIMPL converges after 6 iterations.

Its Newton path is healthy:

- every full step passes the line-search progress test;
- residual quadratic norm falls from about 7.03 to O(1e-25);
- max local residual falls from about 3.75 cm/day to O(1e-13);
- max Newton update falls from about 0.355 cm to O(1e-14 cm).

The only criterion that delays acceptance after iteration 4 is the total residual sum:

- iteration 4: about +1.34e-12 cm/day, still above 1e-12;
- iteration 5: about -1.11e-12 cm/day, still just above;
- iteration 6: about -2.19e-13 cm/day, accepted.

BDF2_KIMPL follows the same healthy nonlinear collapse through iteration 4:

- every full Newton step passes;
- no backtracking below factor 1;
- quadratic residual falls from about 12.54 to O(1e-25);
- max local residual falls from about 4.97 cm/day to O(1e-13);
- max Newton update falls from about 0.313 cm to O(1e-14 cm).

From iteration 4 onward the physical/Newton state is effectively stationary, but the total residual sum oscillates around the configured total-balance threshold:

- iteration 4: about -2.88e-12 cm/day;
- iteration 5: about +2.00e-12 cm/day;
- iteration 6: about -1.55e-12 cm/day;
- iteration 7: about +2.00e-12 cm/day;
- iteration 8: about -2.44e-12 cm/day.

Meanwhile:
- max local residual stays around 4e-13 to 7e-13 cm/day;
- head updates stay around 3e-14 to 4e-14 cm;
- every trial is accepted at line-search factor 1.

## Attribution

The failure is not:

- line-search rejection;
- a bad Newton direction;
- residual blow-up;
- large head updates;
- insufficient MAXIT in the ordinary sense.

The solver has reached a floating-point residual floor, but the scalar total-balance convergence test does not recognize that floor for this BDF2 storage operator.

Classification:

`TOTAL_BALANCE_ROUNDOFF_STALL`

This is consistent with existing BALTOL01/BALTOL02 and PUB-P2E07 authority that strict balance-rate residuals can become numerically indistinguishable from storage representation/cancellation error.

## Important new issue

BALTOL02 qualified the current Reference storage residual and applies:

`max(configured, 2.8e-16 cm / dt)`.

BDF2 changes the storage algebra to:

`1.5 theta^{n+1} - 2 theta^n + 0.5 theta^{n-1}`.

The numerical representation floor of this three-level combination has not been qualified by BALTOL02.

Therefore TIMEINT04 does not change any tolerance.

A separate BDF2-specific numerical distinguishability diagnostic is required before any convergence-floor proposal.
