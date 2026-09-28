# F-HYDROFIT01 P2/P3 result

Authority remained `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5` throughout this execution block.

## Executed evidence

GitHub Actions run `36403227171` at `53526bbaf1520fe09ab87ca2a106610cea1f68ef`: SUCCESS.

This established the initial forward physical-limit tests, explicit textbook-versus-SWAP near-saturation non-equivalence, exact synthetic SWAP-native inverse recovery, and degradation of identifiability after removal of informative observations.

GitHub Actions run `36403394097` at `42aafab4ef9a6490d18cf0546a7d502705b9a44d`: SUCCESS.

This additionally established:

- exact synthetic recovery from three substantially displaced initial parameter sets;
- explicit multi-start execution and optimum selection;
- structural non-identifiability of `Ks` from theta-only observations through singular-value/condition diagnostics.

## Interpretation

P2 is qualified for the current synthetic interior case: the bounded estimator can recover its generating SWAP-native parameter set.

P3 is partially qualified: the implemented local Jacobian diagnostics detect at least one deliberately constructed structural information gap, and multi-start does not reveal a competing optimum in the exact synthetic joint theta/K case.

This does not establish global uniqueness for real data.

## Next question

Joint theta/K fitting now needs an explicit family-weighting experiment. The next preregistration must test whether parameter estimates are invariant to mere duplication of observations within one family when no new information is added. If they are not, family scaling is sample-count dependent and must be corrected before real-data use.
