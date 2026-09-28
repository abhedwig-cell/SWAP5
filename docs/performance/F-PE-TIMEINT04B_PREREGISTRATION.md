# F-PE-TIMEINT04B preregistration — BDF2 total-balance representation floor

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@bd9a3fcc54000b9cdafee77f4a20e739a5abfaf2`

Parent evidence:

- TIMEINT04 P0 shows the failing BDF2 Newton path reaches roundoff-scale local residuals and head updates but remains blocked by the scalar total-balance criterion.
- TIMEINT04A shows iterations 4 through 8 are all below a preregistered BDF2 storage-input distinguishability floor.

## Candidate rule

Only when `timeint02_mode == 2` in the test-only BDF2 HeadCalc:

For every nonlinear convergence check compute:

`bdf2_total_floor = sum_i 0.5 * dz_i/dt * (1.5 spacing(theta_np1_i) + 2 spacing(theta_n_i) + 0.5 spacing(theta_nm1_i))`.

Use:

`effective_total_balance_tolerance = max(configured_total_balance_tolerance, bdf2_total_floor)`.

The ordinary BE path remains exactly unchanged.

## Explicit non-changes

Do not change:

- compartment/local balance tolerance;
- head convergence criteria;
- ponding criterion;
- BALTOL02 production rule;
- MAXIT;
- backtracking;
- Jacobian;
- conductivity treatment;
- BDF2 storage formula;
- forcing or boundary conditions;
- mass acceptance.

This is a test-only convergence floor for the BDF2 mechanism study.

## Qualification bank

Reuse the full TIMEINT03 smooth fixed-flux matrix:

- B01, infiltration 2 cm/day;
- B01, infiltration 4 cm/day;
- O05, infiltration 2 cm/day;
- O05, infiltration 4 cm/day.

Fixed dt ladder:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

Compare:

- BDF2_KIMPL baseline from TIMEINT03;
- BDF2_KIMPL_FLOOR candidate.

## Frozen advancement gates

Candidate advances only if:

1. 4/4 complete ladders;
2. median refined top-head order >=1.6;
3. at least 3/4 individual refined top-head orders >=1.5;
4. no finite-state or mass/storage failure;
5. median deterministic work per step <=1.5 times BE_KIMPL;
6. on every baseline-complete point, candidate endpoint differences satisfy:
   - top/mid/bottom head <=1e-8 cm;
   - terminal storage <=1e-10 cm;
7. the restored B01 / 4 cm/day / dt=0.00125 d point has a finite endpoint and completes without retry;
8. no BE_KIMPL behavior is changed by the materialized candidate source.

If these gates pass, classify:

`BDF2_MECHANISM_QUALIFIED_WITH_REPRESENTATION_AWARE_TOTAL_FLOOR`.

This remains research-only. It does not production-admit BDF2, SWKIMPL=1, or a new balance policy.

## Stop rule

If the candidate does not restore the full ladder while preserving order and common-point equivalence, close TIMEINT04 without another balance-floor variant.
