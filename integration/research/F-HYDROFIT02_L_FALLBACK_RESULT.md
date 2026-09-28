# F-HYDROFIT02 P-LFALL01 fallback result

Run: `36427748243`.

## Frozen corpus constant

The 31-interval source-lambda median is `-1.51057`.

## Aggregate objective loss relative to each interval's best profiled lambda

Across the deterministic 12-case subset:

| policy | median J/Jbest | mean J/Jbest | worst J/Jbest |
|---|---:|---:|---:|
| FIXED_0P5 | 1.436 | 1.734 | 3.927 |
| CORPUS_MEDIAN | 1.103 | 1.284 | 2.241 |
| leave-one-object-out median | 1.181 | 1.512 | 4.132 |
| SOURCE_L diagnostic | 1.003 | 1.011 | 1.078 |

Thus the frozen global corpus median is materially better than lambda=0.5 on this subset, but a single empirical median can still more than double objective in the worst case.

The leave-one-object-out median is not consistently better and has a worse tail. A simple leakage-resistant scalar median is therefore not sufficient evidence for a production fallback.

## Two non-qualified free-lambda cases

BHR000000378543 0.37-0.47 m:

- best profile J=11.5765 at strongly negative lambda, but alpha hits its bound;
- lambda=0.5: J/Jbest=1.306, no alpha/n/Ks bound;
- corpus median -1.51057: J/Jbest=1.262, no alpha/n/Ks bound;
- stored source lambda -9.81823: J/Jbest=1.0003 but reproduces the alpha-bound pathology.

BHR000000378543 0.60-0.70 m:

- best profile J=50.0705 with alpha-bound pathology;
- lambda=0.5: J/Jbest=1.073, no alpha/n/Ks bound;
- corpus median: J/Jbest=1.063, no alpha/n/Ks bound;
- stored source lambda ~0: J/Jbest=1.070, no alpha/n/Ks bound.

For these two cases, fallback regularization sacrifices only about 6-31% objective while removing the severe alpha/Ks tradeoff.

## Interpretation

A fallback is not merely a substitute point estimate for lambda. Its role is regularization when free-lambda estimation is non-qualified.

The global corpus median is a better generic comparator than 0.5 in this evidence set, but its worst-case loss is too large to qualify as a universal production fallback.

Stored source lambda is an excellent objective predictor on average, but it is unavailable for new samples and can preserve pathological parameter tradeoffs.

## Design consequence

The emerging estimator should be hierarchical:

1. attempt scale-aware free-lambda identification;
2. if qualified, use/report the free estimate;
3. if non-qualified, regularize lambda rather than chase the unconstrained objective;
4. choose the regularization target from covariates or a conditional empirical prior, not one universal scalar;
5. report the objective cost of fallback and the reason for fallback.

The next research question is which readily available sample descriptors can condition the lambda prior. Candidate descriptors should come from BRO measurements/source metadata and be selected before fitting a predictive fallback model.
