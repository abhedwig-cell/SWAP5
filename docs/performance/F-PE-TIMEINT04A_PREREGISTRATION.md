# F-PE-TIMEINT04A preregistration — BDF2 total-balance numerical-resolution diagnostic

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@bd9a3fcc54000b9cdafee77f4a20e739a5abfaf2`

Parent evidence:

- TIMEINT04 P0 attributes the BDF2 step-25 failure to a total-balance residual oscillation at O(1e-12 cm/day) after local residual and head-update convergence have reached roundoff scale.
- BALTOL02 and PUB-P2E07 already establish that Reference balance residuals can be limited by finite representation of storage terms.
- BALTOL02's admitted depth floor was derived for the current Reference storage residual, not for BDF2's three-level storage combination.

## Question

At the exact BDF2 step-25 terminal Newton iterates, is the observed total residual sum numerically distinguishable from the finite-representation and summation floor of the BDF2 storage residual?

## Frozen case

Use the exact TIMEINT04 B01 / 4 cm/day / dt=0.00125 d / SWKIMPL=1 / BDF2_KIMPL trajectory.

Trace iterations 4 through 8 of step 25.

No solver decision, tolerance or state is changed.

## BDF2 storage representation floor

For each node, storage rate is:

`S = dz * (1.5 theta_np1 - 2 theta_n + 0.5 theta_nm1) / dt`.

Estimate a conservative input-quantization floor from the stored real64 theta values:

`floor_node = 0.5 * dz/dt * (1.5 spacing(theta_np1) + 2 spacing(theta_n) + 0.5 spacing(theta_nm1))`.

This is a diagnostic resolution scale, not a solver tolerance.

For the total residual, report:

- sum of node floors;
- root-sum-square of node floors;
- maximum node floor;
- current configured total tolerance;
- BALTOL02 existing `2.8e-16/dt` floor;
- observed absolute total residual.

## Summation/cancellation diagnostic

At the traced terminal iterate, expose the exact per-node residual vector and report:

- native-order real64 sum;
- ascending-absolute-value real64 sum;
- descending-absolute-value real64 sum;
- `math.fsum`/higher-precision host recomposition of the same stored residual values;
- spread among real64 summation orders;
- component L1 / abs(total residual) cancellation ratio.

No claim is made that host recomposition recovers exact physics.

## Frozen interpretation

A traced total residual is classified `NOT_NUMERICALLY_DISTINGUISHABLE` if:

`abs(total_residual) <= max(sum_node_storage_floor, real64_summation_spread)`.

It is `DISTINGUISHABLE` otherwise.

This criterion is frozen before diagnostic exposure.

## Advancement

TIMEINT04A may open a convergence-floor candidate only if:

1. all traced terminal residuals and floor components are finite;
2. exact residual-vector reconstruction/printing is internally consistent;
3. at least iterations 4 through 8 are retained;
4. every iteration-4-through-8 total residual is NOT_NUMERICALLY_DISTINGUISHABLE under the frozen criterion;
5. no mass equation or physical state is altered.

If any of these fail, do not propose a BDF2-specific balance floor from this line.

## Production boundary

Diagnostic only.

No production or test-solver tolerance change in TIMEINT04A.
