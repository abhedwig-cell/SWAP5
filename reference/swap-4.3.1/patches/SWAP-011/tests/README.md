# SWAP-011 regression/qualification map

This directory will eventually contain or point to reproducible machine-run tests for the admitted B1 patch. At candidate stage it records the required evidence classes and the audit results already obtained.

| Gate | Scope | Recorded result | Admission role |
| --- | --- | --- | --- |
| Derivative consistency | affected hydraulic models | reference derivative removed model 3 and 5-12 consistency failures; model 4 confirmed already consistent | proves original defect and intended correction |
| E5 strict gate | 36 full runs | 36/36 PASS, exact Newton routes, byte-identical `result.end` for gate set | optimized implementation equivalence |
| E6 broad gate | 150 runs | 150/150 normal completion | robustness |
| E6 route comparison | 60 paired cases | 60/60 exact Newton routes | nonlinear-path equivalence |
| E6 output K0 | 30 paired cases | 30/30 byte-identical `result.end` | output equivalence |
| E6 output K1 | 30 paired cases | 16/30 byte-identical; remaining differences at reported round-off scale | numerical equivalence envelope |
| E6 state metrics | broad paired set | max H-RMSE 1.43e-11 cm; max nodal deviation 9.98e-11 cm | bounded state difference |
| E6 performance | paired timing | median runtime ratio 0.791 | confirms optimized route avoids reference overhead |
| E7 focused sanity | models 3/7/10/12 | strict/O2 pass; exact Newton histograms and byte-identical focused outputs recorded | upstream-package sanity |

## Required machine assets before formal B1 admission

The exact test scripts/input bundles/output baselines should be recovered together with the final E7 patch where available. If historical machine artifacts cannot be recovered, the tests must be reconstructed from the documented gate definition and rerun against:

```text
B0
B0 + exact recovered SWAP-011 patch
```

Reconstructed **tests** are acceptable if their intent and tolerances are documented. Reconstructed **patch code** is not acceptable for B1 admission.

Mass-balance checks remain mandatory wherever the original full-run cases expose water-balance outputs, even though SWAP-011 targets the Jacobian rather than a physical flux law.
