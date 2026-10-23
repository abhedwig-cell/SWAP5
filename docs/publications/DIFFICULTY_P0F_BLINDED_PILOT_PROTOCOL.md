# DIF-P0F — blinded infrastructure pilot protocol

Status: PREREGISTERED; EXECUTION GATED ON P0C PASS

## Purpose

P0F is a plumbing and evidence pilot. It is not an exploratory scientific analysis and cannot change the Phase-0 hypotheses or regime thresholds.

## Pilot population

Use a deliberately small set of pre-trial checkpoints spanning the available prototype R1-R6 labels and at least two soil parameterizations where current canonical application envelopes permit execution.

Checkpoint selection uses only pre-trial state/forcing/descriptors. No solver outcome may be queried during selection.

## Counterfactuals

For each checkpoint:
- replay Reference Newton at the frozen pilot dt ladder;
- replay RossFast only where its exact admitted common envelope is satisfied;
- retain RossFast as formulation-sensitive secondary evidence only.

The pilot MUST NOT be described as an H3 cross-iterative-method test.

## What may be inspected

Infrastructure inspection may verify:
- complete TrialDifficultyRecord serialization;
- stable checkpoint/counterfactual identifiers;
- descriptor reproducibility;
- regime label reproducibility;
- method/order replay qualification;
- outcome-field population and missingness semantics;
- dt-ladder bookkeeping;
- failure classification plumbing;
- ability to separate predictor and outcome tables.

## What may not be learned/tuned from P0F

P0F outcomes may not be used to:
- alter R1-R6 thresholds;
- add/remove physical predictors because they correlate with difficulty;
- choose model form;
- choose statistical cutoffs;
- choose the final dt ladder for predictive advantage;
- widen solver application envelopes;
- claim physical difficulty regimes.

A technical change required because a field is missing, malformed or semantically ambiguous is permitted, but must be recorded as an infrastructure correction rather than scientific tuning.

## Blinding/export contract

Produce two keyed artifacts:
1. `pretrial.csv`: identity + phys + forcing + num_pre, with no difficulty outcome.
2. `outcome.csv`: trial key + method + outcomes.

Threshold calibration and state-space support analysis may consume only `pretrial.csv`. The join is reserved for the explicitly admitted pilot diagnostic and later frozen analysis.

## dt-ladder pilot

The preregistered nominal ladder is {0.25, 0.5, 1, 2, 4} dt_ref.

P0F may establish only whether this ladder is technically executable and whether deterministic bracketing/bisection machinery works. If numerical limits make a rung invalid before solver execution, that is a domain/contract issue, not a difficulty outcome.

Non-monotone solvability must be preserved as a response curve and flagged; it must not be coerced into dt-star.

## Closure criteria

P0F closes only if:
- P0C is green;
- predictor/outcome separation is machine-checkable;
- repeated exports are deterministic;
- missing optional diagnostics remain explicit rather than zero-filled;
- no pilot observation has changed the scientific regime definition;
- all common-envelope exclusions are recorded.

P0F closure authorizes construction of the frozen Phase-0 dataset machinery, but NOT P0G H3/S3 adjudication while the independent-iterative-method prerequisite remains unresolved.
