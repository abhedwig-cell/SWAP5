# F-HYDROFIT02 P-LSHRINK01 — soft lambda shrinkage preregistration

## Purpose

Test whether soft regularization around a leakage-resistant lambda target can retain the objective benefit of a conditional prior while avoiding severe local ill-conditioning.

This is research-only. It does not alter production SWAP code.

## Frozen target policies

Use two already frozen targets:
- S0: leave-one-BRO-object-out global median lambda;
- S1: P-LPRIOR03 KNN5K target, unchanged.

Do not retune neighbours, predictors or k.

## Penalized objective

Fit lambda jointly with theta_r, theta_s, alpha, n and Ks using the existing hydraulic residual vector plus one prior residual:

`r_prior = (lambda - lambda_target) / sigma_lambda`.

Test exactly three preregistered prior widths:
- sigma_lambda = 0.5;
- sigma_lambda = 1.5;
- sigma_lambda = 4.0.

These span strong, moderate and weak shrinkage. Do not add intermediate widths after seeing results.

Retain the existing lambda search bounds used by the free-lambda research fit.

## Frozen evaluation

Use the same deterministic 12 profile cases.

For every target-policy × sigma combination report:
- fitted lambda and displacement from target;
- hydraulic objective J excluding the prior penalty;
- J/Jbest using the existing frozen profile reference;
- scale-aware alpha/n/Ks boundary status;
- Jacobian condition number for the hydraulic parameter fit and the combined penalized fit where available;
- P-LID01 condition class.

Primary decision uses hydraulic J/Jbest and identifiability, not the penalized total objective.

## Decision rule

A shrinkage policy is promising only if:
- no frozen case is SEVERE under the identifiability gate;
- no alpha/n/Ks boundary pathology reappears;
- objective-loss tail improves materially over the hard LOO_MEDIAN fallback.

If only very strong shrinkage is stable, the result effectively supports a hard robust fallback rather than free lambda. If weak shrinkage recreates severe conditioning, preserve that negative result.

Do not tune sigma per soil, horizon or case in this workunit.
