# F-HYDROFIT02 P-LID01 — identifiability gate preregistration

## Motivation

P-LPRIOR03 demonstrated that a fixed-lambda fit can avoid formal alpha/n/Ks bound contact while retaining extreme local ill-conditioning (condition number about 1e10). Boundary status alone is therefore insufficient.

## Purpose

Add a diagnostic identifiability classification to HYDROFIT without changing any existing fit, objective, parameter bound, lambda policy or optimizer.

## Frozen evidence

Use all already-computed profile/fallback/conditional-prior fits. Do not refit for this workunit.

## Diagnostics

Report the Jacobian singular values and condition number already derived from the least-squares Jacobian.

Use descriptive condition bands, fixed before reclassification:
- WELL_CONDITIONED: cond < 1e4;
- MODERATE: 1e4 <= cond < 1e6;
- POOR: 1e6 <= cond < 1e8;
- SEVERE: cond >= 1e8 or non-finite.

These bands are diagnostic research classes, not claimed universal physical constants.

A fit is QUALIFIED_IDENTIFIABILITY only if:
- no existing scale-aware alpha/n/Ks boundary block is present; and
- condition class is not SEVERE.

POOR remains reportable as qualified-with-warning for this workunit; do not silently collapse it into WELL_CONDITIONED.

## Falsification check

Reclassify the frozen P-LPRIOR03 12-case results. Specifically test whether the known BHR000000378543 cases are captured by the SEVERE class without changing their fitted parameters.

If the gate marks a broad fraction of otherwise ordinary cases SEVERE, treat the threshold as non-discriminating and do not use it for policy selection.

## Next decision

Only after this frozen reclassification may conditional policies be compared on:
- objective loss;
- formal boundary status;
- identifiability class.

Do not tune KNN hyperparameters or add predictors in P-LID01.
