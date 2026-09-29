# F-HYDROFIT02 P-LSAFE01 — gated soft-lambda estimator preregistration

## Trigger

Identity-corrected P-LSHRINK02 confirms that LOO-median soft shrinkage remains non-replicated under the zero-SEVERE rule because one genuine hydrophysical record, BHR000000378532 0.65-0.75 m, has a low-objective lambda region that is locally SEVERE.

No new sigma, KNN rule, lambda grid or condition threshold will be tuned from that failure.

## Purpose

Test whether the already-qualified components can be composed into a safer estimator:

1. primary fit: the existing LOO-median soft shrinkage estimator with `sigma_lambda = 1.5`;
2. qualification gate: the existing scale-aware parameter-bound gate plus the preregistered hydraulic identifiability gate;
3. fallback: only when the primary fit fails the gate, refit with lambda hard-fixed to the same leave-one-BRO-object-out median target.

This is an estimator-composition test, not a new lambda-center search.

## Frozen data and identity

Use only:

`integration/research/data/F-HYDROFIT02_FROZEN_SPATIAL_LAMBDA_CORPUS_IDENTITY.json`

All hydraulic records must be bound by:
- BRO id;
- begin depth;
- end depth;
- hydraulic SHA-256.

Source lambda is an audit field only.

The existing deterministic 12 / independent 19 membership split is preserved.

## Primary estimator

For each target record:
- compute the leave-one-BRO-object-out median source lambda from all records belonging to other BRO objects;
- fit theta_r, theta_s, alpha, n, Ks and lambda with the existing hydraulic objective;
- add the existing prior residual:
  `(lambda - lambda_target) / 1.5`;
- retain all existing parameter bounds, weighting, optimizer settings and transformations.

## Gate

The primary fit is accepted only when:
- hydraulic Jacobian condition number is finite and < 1e8;
- no existing scale-aware formal alpha, n or Ks boundary block is present.

The 1e8 threshold is the existing P-LID01 SEVERE threshold and is not re-estimated here.

## Fallback

If the primary fit fails either gate:
- keep the same LOO-median lambda target;
- fix lambda exactly to that target;
- refit only theta_r, theta_s, alpha, n and Ks using the existing fixed-lambda solver;
- apply the same identifiability and scale-aware boundary gates to the fallback fit.

No alternative hard lambda, no shifted target and no second soft sigma may be tried.

## Evaluation

Report separately for:
- deterministic 12;
- independent 19;
- all 31 for descriptive completeness.

For the final gated estimator report:
- number accepted at primary stage;
- number requiring fallback;
- number still unqualified after fallback;
- median, mean and maximum hydraulic J/Jbest;
- boundary blocks;
- identifiability-class counts;
- identity and outcome for every fallback-triggered record.

`Jbest` remains the minimum on the already frozen discrete lambda profile grid where that reference is already defined. Do not add grid points.

## Qualification rule

Research qualification requires:
- zero final SEVERE fits;
- zero final alpha/n/Ks boundary blocks;
- no silent record loss;
- no failure to match the frozen hydraulic hash;
- final maximum J/Jbest no worse than the already observed hard LOO fallback tail on the deterministic reference set.

The last criterion is only a guard against a fallback composition that is less useful than the existing hard LOO baseline. It is not a tuning target.

## Interpretation limits

A positive result would show only that a gate-and-fallback composition removes the observed identifiability failure on this frozen 31-record research corpus.

It would not establish production readiness, population-level robustness, or optimality of sigma 1.5.

A negative result must be retained. No stronger fallback or new threshold may be introduced without a new preregistration.
