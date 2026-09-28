# F-HYDROFIT01 P4 weighting result

Canonical authority remained `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`.

## P4-A

Run `36403568303` at `ec50a2862b0b7afbb6481191fc205a6a15ffa545`: SUCCESS.

The preregistered falsification demonstrated that ordinary concatenated sum-of-squares fitting changes the optimum when identical theta rows are replicated while K rows are unchanged. The current objective was therefore confirmed to be sample-count sensitive.

## P4-B

Implementation adds explicit `weighting_mode`:

- `sum`: sum of standardized squared residuals;
- `family_mean`: each residual is additionally divided by `sqrt(N_family)`, so each family's objective contribution is its mean standardized squared residual.

Run `36403652109` at `640a980bca577e0ac3560c125f165fe560e5de62`: SUCCESS.

The run confirms:

- exact theta replication leaves the `family_mean` optimum invariant within the preregistered tolerance;
- exact synthetic SWAP-native recovery remains intact;
- all earlier research tests remain green.

## Interpretation

There is no single universally correct default independent of the observation model.

Use `sum` when rows represent independent measurements under an explicit probabilistic error model and repeated measurements genuinely add information.

Use `family_mean` when theta and K are intended as balanced information families and their row counts mainly reflect sampling design.

Real-data analyses must record this choice. Silent automatic switching is prohibited.

## Next gate

P5 should move from a single optimum to a near-equivalent parameter ensemble. The first experiment should use a deliberately information-limited synthetic dataset and map parameter sets inside a declared objective envelope, then quantify spread in theta(h) and K(h). Solver behaviour remains deferred until the ensemble semantics are qualified.
