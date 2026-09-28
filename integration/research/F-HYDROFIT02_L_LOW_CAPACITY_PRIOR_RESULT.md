# F-HYDROFIT02 P-LPRIOR03 low-capacity conditional-prior result

Authority run: `36469751909`.

The preceding run `36468709803` failed before producing lambda results because `parse_object()` initialized a list instead of a dictionary. Only that implementation error was corrected; the preregistered policies were unchanged.

## Source-lambda prediction diagnostics, 31 intervals, leave-one-BRO-object-out

| policy | median abs error | median bias | max abs error |
|---|---:|---:|---:|
| LOO_MEDIAN | 1.470 | -0.158 | 18.489 |
| HORIZON | 1.470 | -0.116 | 18.339 |
| KNN5 | 1.369 | ~0 | 18.000 |
| KNN5K | 1.511 | +0.006 | 18.000 |

Source-lambda prediction error alone does not select KNN5K.

## Hydraulic objective on frozen 12 profile cases

| policy | median J/Jbest | mean | max | formal bound blocks |
|---|---:|---:|---:|---:|
| LOO_MEDIAN | 1.181 | 1.512 | 4.132 | 0 |
| HORIZON | 1.312 | 1.847 | 5.820 | 0 |
| KNN5 | 1.067 | 1.945 | 9.755 | 0 |
| KNN5K | 1.039 | 1.227 | 2.286 | 0 |

HORIZON is falsified as an improvement. KNN5 has an unacceptable objective-loss tail. KNN5K materially improves the aggregate objective-loss distribution relative to the scalar LOO median.

## Identifiability caveat

KNN5K is not qualified.

For the known problematic BHR000000378543 0.37-0.47 m interval, KNN5K predicts lambda=-2.9745 and achieves J/Jbest=1.0137 with no formal alpha/n/Ks bound contact, but the condition number is approximately `1.32e10`.

The simpler KNN5 has the same failure mode, approximately `1.02e10`.

Thus avoiding literal parameter-bound contact does not guarantee an identifiable fit. The previous scale-aware boundary gate is necessary but insufficient.

## Conclusion

No P-LPRIOR03 policy is admitted as a production fallback.

KNN5K is the first leakage-resistant conditional policy to improve the preregistered objective-loss tail substantially, so it remains a research comparator. Before any further policy comparison, HYDROFIT qualification must include an explicit identifiability/conditioning criterion in addition to boundary status.

Do not tune a condition threshold from the KNN5K result after the fact. Preregister the identifiability rule independently and requalify existing fits without changing them.
