# F-HYDROFIT02 P-LPRIOR03 — low-capacity conditional lambda prior preregistration

## Purpose

Test whether a deliberately low-capacity, leakage-resistant conditional prior improves on the scalar leave-one-object-out median.

## Frozen data

Use the same 31-interval corpus. Evaluation is leave-one-BRO-object-out. Target source lambda is never an input.

## Eligible predictors

Use only universally available, unambiguous descriptors established before outcome inspection:
- begin depth;
- end depth / thickness;
- n_obs;
- h span;
- theta span;
- log10 K span;
- horizonCode.

Do not use clay, sand, silt, organic matter or bulk density in this workunit because coverage/ambiguity is incomplete.

## Candidate policies

Keep capacity intentionally low.

C0: LOO global median, already established comparator.

C1: LOO horizon-prefix median. Group horizonCode by its first alphabetic horizon symbol only (for example A, B, C), learned from training objects. If a target group has fewer than 3 training intervals, fall back to the LOO global median.

C2: LOO nearest-neighbour median in a fixed four-dimensional continuous descriptor space:
- normalized interval midpoint depth;
- log10(max(n_obs,1));
- log10(max(h_span,1));
- theta_span.

Standardize each dimension using training objects only. Use the 5 nearest training intervals, but exclude all intervals from the target BRO object. Predict the median training source lambda of those neighbours. No tuning of k is permitted in this workunit.

C3: same as C2 but include log10k_span as a fifth fixed descriptor. Again k=5 fixed in advance.

## Evaluation

First evaluate lambda prediction descriptively against source lambda:
- median absolute error;
- median signed error;
- maximum absolute error.

Then, for the existing deterministic 12 profile cases, refit theta_r, theta_s, alpha, n and Ks at each predicted lambda and report:
- median/mean/max J/Jbest;
- scale-aware boundary status;
- condition number;
- the two previously non-qualified cases.

## Decision rule

A conditional policy is only promising if it improves the objective-loss tail relative to the LOO scalar median without worsening boundary pathology. Lower source-lambda prediction error alone is insufficient.

If none improves robustly, stop increasing predictor flexibility on n=31 and move to explicit shrinkage/regularization rather than supervised prediction.
