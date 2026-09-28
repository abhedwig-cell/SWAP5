# F-HYDROFIT02 P-LFALL01 — lambda fallback preregistration

Authority observed: `integration/f-ci-canonical@230f71ee3b2ca991624977fb3b73a2acd5f86f3a`.

## Purpose

Evaluate simple fallback strategies for cases where free lambda is not qualified.

This workunit is diagnostic. It does not define a production prior.

## Frozen evidence

Use:

- the 31-interval P-LCORP02 source-lambda corpus;
- the same 12 deterministic P-LPROF01 intervals and profile grid;
- the scale-aware qualification from P-BOUND01.

The two non-qualified intervals are not used to tune fallback constants.

## Fallbacks

F0: FIXED_0P5, historical/common conventional comparator lambda=0.5.

F1: CORPUS_MEDIAN, lambda fixed to the 31-interval source median, computed from the frozen corpus.

F2: LEAVE_ONE_OBJECT_OUT_MEDIAN, lambda fixed to the median source lambda from corpus intervals excluding all intervals belonging to the target BRO object. This tests a minimally leakage-resistant empirical fallback.

F3: SOURCE_L, retain the stored WENR/BRO lambda for diagnostic comparison only. This is unavailable for genuinely new samples and therefore cannot be the general new-data fallback.

For each fixed lambda, refit theta_r, theta_s, alpha, n and Ks with the same objective and scale-aware boundary diagnostics.

## Metrics

For all 12 intervals report objective ratio to each interval's best profiled objective.

For the two non-qualified cases report parameters, scale-aware boundary status and condition number.

## Decision logic

A useful generic fallback should:

- avoid the severe alpha-boundary pathology on the two non-qualified cases;
- have materially lower objective loss than FIXED_0P5 across the 12-case subset;
- not rely on the target's stored source fit.

Failure is admissible and would imply that a single scalar empirical fallback is insufficient.
