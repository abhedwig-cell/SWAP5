# HYDRO-MEMORY-CAP01 result

**Decision:** `CLOSED_BLOCKED_NET_ROOT_EXTRACTION_HYDRAULIC_EXECUTION`

CAP01 does not authorize HYDRO-MEMORY Stage 0.

## Decisive result

The preregistered A4 matrix was executed on GitHub Actions run **35427908820**, job **105856982576**, head `6080f6f7bc95d16de78589969df922f6931f9a8a`.

The workflow is red by design because the original CAP01 qualification target remains a nonzero unbalanced root sink and that target fails. The diagnostic controls completed before that failure.

| Case | Total root sink (cm d-1) | Compensating subsurface source | Completed | Retries | Solver rejections | Temporal rejections | Mass residual |
| --- | ---: | --- | --- | ---: | ---: | ---: | ---: |
| Z | 0 | none | yes | 0 | 0 | 0 | 0 |
| B | 0.02 | exactly equal by node | yes | 0 | 0 | 0 | 0 |
| U1 | 0.0002 | none | no | 8 | 9 | 0 | no accepted result |
| U2 | 0.002 | none | no | 8 | 9 | 0 | no accepted result |
| U3 | 0.02 | none | no | 8 | 9 | 0 | no accepted result |

All cases use the same A3 hydraulic-equilibrium anchor, Reference Richards parameters and canonical external full-half transaction policy.

## Interpretation

The result separates three issues that had previously been conflated.

First, **root-active binding is operational**. Case Z has `root_extraction_active=true` and completes without retries.

Second, **root-sink transport through the typed forcing/binding and its mass bookkeeping are operational when hydraulically cancelled**. Case B reproduces the essential FMR09 pattern: extraction is exactly offset by an equal subsurface source and the model completes with zero mass residual.

Third, **net root extraction as a state-changing hydraulic forcing is not demonstrated by the existing production evidence and fails in CAP01**. Failure already occurs at (2\times10^{-4}\) cm d-1, far below the demand scale envisaged for the later drought experiment.

The failure class is especially informative. There are no temporal-policy rejections in A3/A4 and no accepted-run mass rejection. The transaction exhausts its retry budget through solver rejection.

This does not yet prove a defect in the Richards equations or HeadCalc. It proves a narrower statement:

> the current frozen CAP01 typed production trajectory cannot execute even very small nonzero **unbalanced** precomputed root extraction under a fixture where both the zero-root and exactly balanced-root controls succeed.

## Why existing root-active qualification does not close this gap

The repository's strongest real-HeadCalc root oracle, FMR09, deliberately sets

`subsurface_irrigation_source = root_extraction_sink`

and requires the committed hydraulic state to remain identical to the control.

F-CI34 reuses that oracle to qualify exact root-uptake attribution and mass publication. The F-CI37 independent parallel qualification uses the same conceptual construction: root extraction is accompanied by an equal subsurface source so that hydraulic state is preserved.

Those are valid tests of ownership, attribution, determinism and mass accounting. They are not tests that plant water uptake can deplete the root zone and propagate hydraulically toward groundwater.

HYDRO-MEMORY needs exactly the latter.

## Scope ceiling

CAP01 does **not** establish that every possible SWAP5 numerical configuration fails for net root extraction. It also does not yet identify the root cause.

In particular, the existing root-active reference tests leave several numerical settings at their type defaults, whereas the groundwater-derived CAP01 fixture binds explicit solver controls. Those differences now belong in a separate diagnosis. They must not be tuned inside CAP01 after seeing its outcome.

Nor has CAP01 yet executed the exact corrected B1.11 legacy model on an equivalent net-root case. That reference comparison is required before any production repair is justified.

## Next bounded workunit

Open **PPA-ROOT-HYD01 — Net root-extraction hydraulic execution authority and solver diagnosis**.

Required order:

1. reproduce an equivalent unbalanced root-extraction case in corrected B1.11/reference authority;
2. inventory and compare numerical controls between the legacy/reference case, FMR09 and the typed production route;
3. localize the retry request to nonlinear convergence, balance/head criterion, backtracking or another explicit owner;
4. repair only if source/evidence identifies a local implementation or composition defect;
5. qualify nonzero unbalanced root extraction with a changing hydraulic state and hard mass closure;
6. only then return to CAP01 and rerun the frozen centered-FD groundwater-response gates.

No groundwater drought/recovery ensemble is scientifically authorized before that chain closes.
