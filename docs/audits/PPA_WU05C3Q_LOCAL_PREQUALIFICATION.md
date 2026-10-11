# PPA-WU05-C3Q local source-bound prequalification

Date: 2026-10-01

Status: `PREQUALIFIED_SOURCE_ALGEBRA / CURRENT_B1_11_REPLAY_STILL_REQUIRED`

## Execution

The exact B0 distribution already retained in the project Library was materialized locally and verified:

```text
distribution SHA-256
2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

Its exact B0 `oxygenstress.f90` was transformed only with the admitted SWAP-007 byte replacement.
The resulting oxygen source matched the pinned corrected identity exactly:

```text
8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87
```

A diagnostic-only sampled trace was added and the official five-year `2.grassgrowth` case was
compiled with GNU Fortran 14.2.0 and run locally.

Observed:

```text
process return code 100
Swap normal completion
sampled trace rows 1000
sampled trace bytes ~0.8 MB
sampled oxygen-limited rows 500
minimum sampled rwu_factor 0
```

The trace intentionally retained the first 500 physical calls plus the first 500 oxygen-limited
calls to avoid the severe I/O cost of tracing every OxygenStress invocation.

## Independent MICRO replay

The source-equivalent pure MICRO algebra was replayed from captured call inputs at the final
legacy respiration factor.

Across all 1000 rows:

```text
maximum absolute c_min_micro difference  4.43e-17
99th percentile absolute difference      2.78e-17
rows within 1e-10                        1000 / 1000
```

This is effectively floating-point roundoff agreement and strongly qualifies the reconstructed
MICRO algebra.

## Independent MACRO replay with bounded inner solve

The pure MACRO algebra was replayed with the historical restart/Newton depth solve replaced by the
R6 monotone bracket/bisection solve.

Across all 1000 rows:

```text
maximum absolute c_macro difference      5.86e-09 kg/m3
99th percentile absolute difference      1.65e-09 kg/m3
rows within 1e-10                        930 / 1000
```

The largest relative differences occur only at very small oxygen concentrations. This is consistent
with different root-solver termination policy, not a different MACRO equation.

## Full respiration/RWU replay

Using the pure MICRO + bounded MACRO response and a bounded outer respiration solve:

```text
max |resp_factor_new - resp_factor_legacy|   2.48e-05
99th percentile                              1.70e-05
all 1000 rows within                         1e-04

max |rwu_factor_new - rwu_factor_legacy|     1.22e-05
99th percentile                              5.46e-07
992 / 1000 rows within                       1e-06
all 1000 rows within                         1e-04
```

The historical outer SOLVE uses `accuracy = 1e-4`. The observed bounded-solver differences remain
inside that declared legacy solve accuracy on every sampled row.

## Important diagnostic finding

Legacy `c_macro` and `c_min_micro` globals immediately after `SOLVE` are not guaranteed to
represent a fresh evaluation at the returned `resp_factor`; they can reflect the last internal
residual evaluation. C3Q therefore must compare fresh MICRO/MACRO evaluations at the returned
respiration factor, not blindly compare those stale scratch globals.

This explains the initially apparent MICRO mismatch in oxygen-limited rows and is itself useful
architecture evidence: these variables are numerical scratch, not physical continuation state.

## Interpretation

This local gate materially strengthens H1/H2 and the proposed pure-kernel architecture:

- MICRO formula parity: qualified at roundoff scale for this 1000-row sample;
- MACRO physical equation parity: qualified to small bounded-solver differences;
- outer bounded solve: all sampled responses remain within legacy `1e-4` solve accuracy;
- no cross-timestep oxygen state was required for replay.

This is not yet the final C3Q admission result because the local execution used canonical B0 plus
the exact SWAP-007 oxygen correction, not the complete current B1.11 source tree. Current B1.11
replay remains the final oracle gate, although later admitted B1 corrections do not modify
`oxygenstress.f90`.
