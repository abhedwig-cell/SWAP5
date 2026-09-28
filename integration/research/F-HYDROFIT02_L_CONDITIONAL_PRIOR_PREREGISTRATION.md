# F-HYDROFIT02 P-LPRIOR01 — conditional lambda-prior preregistration

Authority observed before write: `integration/f-ci-canonical@b7cec379c9ab492208a9c39faf4c65cde6dcac6a`.
Research authority: `research/f-hydrofit02-bro-acquisition@fd2a1b805877930e32df8efe6d28bf8df7c3fd40`.

## Motivation

P-LFALL01 falsified a universal scalar fallback as a production policy. The frozen corpus median improved substantially over lambda=0.5, and regularized the two non-qualified free-lambda cases, but leave-one-object-out performance retained an unacceptable tail. The next question is therefore whether lambda can be regularized conditionally without target-fit leakage.

## Scientific question

Can descriptors available for a genuinely new sample define a leakage-resistant conditional prior for lambda that improves over the global-median fallback while retaining scale-aware qualification?

This workunit concerns prior construction and falsification, not production admission.

## Frozen evidence and leakage rule

Retain the existing 31-interval spatial corpus as development evidence. Any target interval's stored lambda, fitted parameters, residuals, profile optimum, or other quantities derived from its hydraulic fit are forbidden as predictor inputs for that target.

Evaluation must be grouped by BRO object. A target object's intervals must not contribute to the empirical prior or predictor used for that object.

The two known non-qualified intervals remain evaluation cases, not tuning anchors.

## Candidate descriptor classes

Before inspecting predictive performance, investigate only descriptors that are available independently of the target hydraulic fit:

1. measurement-derived descriptors computable directly from the raw observed theta(h) and K(h) tuples, such as number and h-range of observations and simple observed-range summaries;
2. interval geometry, including top depth, bottom depth and thickness;
3. BRO source metadata or sample/soil descriptors actually present and sufficiently populated in the fetched official objects.

Do not silently substitute source-fit Mualem-Van Genuchten parameters, including source lambda, alpha, n, theta_r, theta_s or Ks, as predictors.

## Phase A: availability audit

First inventory candidate descriptors and missingness across all 31 intervals. No predictive model is to be selected before this audit is recorded.

A descriptor may enter Phase B only if:
- its meaning is traceable to official BRO data or directly to raw measurements;
- it is available without using the target source fit;
- coverage is sufficient to support grouped evaluation.

## Phase B: deliberately low-capacity conditional priors

Only after Phase A, preregister the exact model(s) from the available descriptor set. Prefer low-capacity robust estimators or coarse stratification over flexible regression because n=31 is small.

Every reported predictive result must use leave-one-BRO-object-out evaluation.

## Comparators and metrics

Comparators:
- FIXED_0P5;
- frozen global CORPUS_MEDIAN;
- leave-one-object-out median;
- SOURCE_L diagnostic only, never as an available new-sample policy.

Primary metrics after refitting the remaining hydraulic parameters:
- median, mean and maximum J/Jbest;
- scale-aware boundary status;
- condition number;
- behavior of the two previously non-qualified cases.

Also report lambda prediction error against source lambda as a descriptive diagnostic, but do not equate source-lambda prediction with hydraulic-fit quality.

## Decision logic

A conditional prior is promising only if grouped out-of-object evaluation improves the objective-loss tail relative to the leakage-resistant scalar median without reintroducing alpha/n/Ks boundary pathology.

If descriptor coverage is weak or no low-capacity conditional prior improves robustly, preserve that negative result and move to shrinkage/regularization around a broad empirical prior rather than increasing model flexibility on 31 intervals.
