# F-HYDROFIT02 P-BOUND01 — conditional-bound attribution preregistration

Authority observed: `integration/f-ci-canonical@b372305b21012318175b973680f1204e7c5e8dd0`.

## Purpose

Explain why all 12 P-LPROF01 lambda profiles failed the qualification gate due to another parameter being near a generic bound.

## Frozen cases and fits

Use exactly the same 12 deterministic intervals, lambda grid, observations, family-mean objective, and conditional refitting procedure as P-LPROF01.

Do not change any parameter bound in this workunit.

## Diagnostics at each interval's profile minimum

Report:

- fitted theta_r, theta_s, alpha, n, Ks and fixed lambda;
- source WENR/BRO theta_r, theta_s, alpha, n, Ks and lambda;
- normalized distance to lower and upper bounds for alpha, n and Ks;
- exact blocking parameter(s) under the existing 0.1% gate;
- ratios fitted/source for alpha and Ks, and delta n;
- whether the blocking parameter is already near the same generic bound in the source fit;
- local conditional Jacobian singular values/condition number when finite.

## Classification

Per interval classify the blocker as one of:

- ALPHA_BOUND;
- N_BOUND;
- KS_BOUND;
- MULTIPLE_BOUNDS.

No causal interpretation is assigned solely from this classification.

## Gate

Only after blocker attribution may a subsequent workunit test alternative parameter domains or transformations. This workunit must not relax bounds.
