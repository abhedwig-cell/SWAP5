# F-PE-HYDTABLE01 P0 freeze

Date: 2026-09-27

Status: `P0_CANDIDATE_FROZEN_BEFORE_HOLDOUT`

Authority branch:
`work/f-pe-hydtable01-conductivity-representation`

Calibration head:
`a1c4787976762b7007c48ddfb44a4da6a8797352`

## Frozen candidate

Representation:

- uniform grid in `x = ln(-h)`;
- represented domain `-1e6 cm <= h <= -1 cm`;
- stored ordinate `y = ln(K)`;
- piecewise-linear interpolation in `(x,y)`;
- `K = exp(y)`;
- `dK/dh` derived analytically from that same local interpolant:
  `dK/dh = K * (dy/dx) / h`;
- table size: `N = 1024` per hydraulic material;
- analytical fallback outside the represented domain;
- no interpolation across the near-saturated branch above `h=-1 cm`;
- no interpolation beyond the frozen dry boundary below `h=-1e6 cm`.

This freeze is research-only and does not authorize production routing.

## Calibration evidence

The P0 calibration matrix covered B01, B12, O05 and O14 on 12,001 logarithmically distributed points per material.

For the frozen N=1024 candidate:

- worst observed relative K error: `8.883911362e-05`;
- worst observed relative dK/dh error: `1.327587612e-02`;
- monotonicity: PASS for all four material tables;
- negative K: none;
- median-of-four K runtime ratio: approximately `0.172442`;
- median-of-four K+dK/dh runtime ratio: approximately `0.080841`;
- table construction cost: approximately 0.16-0.20 ms per material on the calibration runner.

The timing values are microkernel localization evidence. They are not yet solver or application speedup claims.

## Frozen holdout gates

The independent holdout must pass all of the following without changing this candidate:

1. K is finite and nonnegative at every represented holdout point.
2. K is monotone nondecreasing with increasing head on each smooth represented branch.
3. The table is unavailable outside the frozen represented domain and therefore requires analytical fallback.
4. Maximum relative K error <= `1.0e-4`, using denominator `max(abs(K_analytic), 1e-12*Ksat)`.
5. Maximum relative dK/dh error <= `1.5e-2`, using denominator `max(abs(dKdh_analytic), 1e-12*Ksat)`.
6. No hidden branch interpolation is allowed at the wet boundary. Points above `-1 cm` must be fallback.
7. No hidden extrapolation is allowed below `-1e6 cm`.
8. Repeated K evaluation must remain speed-positive relative to analytical evaluation.
9. Repeated K+dK/dh evaluation must remain speed-positive relative to the analytical directional route.

## Holdout separation

The holdout must not reuse the calibration point lattice.

Use a deterministic phase-shifted or otherwise disjoint set of logarithmic interior points, plus explicit boundary-neighborhood probes on both sides of `h=-1 cm` and `h=-1e6 cm`.

No threshold or table-size change is allowed after holdout results are observed. Failure redirects or closes the candidate.

## Next gate

If holdout passes, proceed to solver-level qualification on the frozen 4 material x 3 regime matrix.

