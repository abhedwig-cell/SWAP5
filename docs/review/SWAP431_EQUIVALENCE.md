# SWAP 4.3.1 and SWAP5 — what equivalence is established?

## Review question

A central question for the SWAP5 rebuild is:

> How do we know that the modernised implementation still represents the admitted SWAP scientific behaviour?

The answer is deliberately evidence-based and bounded. SWAP5 has strong reference-preservation and capability-specific scientific/numerical qualification evidence, but the repository must not compress all of that into an unsupported statement that *every possible SWAP 4.3.1 application is already proven byte-identical to SWAP5*.

## Frozen SWAP5 scientific target

The first colleague review uses:

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

Within that denominator, the release-readiness authority closes the admitted scientific/numerical capability set and preserves the reference baseline through the relevant scientific, numerical, mass, restart, MultiSWAP and permanent-regression evidence.

See [Status-A traceability](../status-a/TRACEABILITY.md) for capability-by-capability evidence.

## Direct legacy Hupsel evidence

The F-VQ99 equivalence campaign recovered the official SWAP 4.3.1 distribution and reconstructed the qualified B1.10 legacy source through the immutable patch chain.

For the official Hupsel case over **2002-01-01 through 2004-12-31**:

- the recovered B0 legacy model completed successfully;
- reconstructed B1.10 completed successfully;
- annual reported water-balance deviations were zero to displayed precision;
- after one declared representation-only normalization — removing the generated timestamp line and normalising line endings — `result.bal` and `result.blc` were byte-identical between B0 and B1.10;
- no unexplained scientific or numerical difference was found in that qualified legacy long trajectory.

This is valuable evidence that the qualified legacy transformation preserved the Hupsel balance content.

## What this direct Hupsel result does **not** yet prove

F-VQ99 did **not** find an already-admitted whole-application SWAP5 driver that consumes the complete legacy Hupsel meteorology/crop/ET/input set with a formally fixed semantic mapping into the typed SWAP5 application composition.

Therefore the current global F-VQ99 verdict remains:

`SWAP431_SWAP5_STATUS_A_EQUIVALENCE_NOT_YET_ESTABLISHED`

This verdict does **not** mean that an unexplained SWAP5 scientific difference was found. It means the direct whole-application comparison is not yet a valid experiment because the complete canonical input/application mapping has not been fixed for that trajectory.

## How SWAP5 is nevertheless already verified

The rebuild does not rely on one monolithic application test. Its current evidence structure is capability-based:

```text
legacy / scientific contract
        |
        v
reimplemented production capability
        |
        v
owner + independent scientific/numerical qualification
        |
        v
canonical admission
        |
        v
current-head / permanent preservation
```

This allows specific claims to be established without pretending that untested combinations are covered automatically.

Examples in the frozen denominator include the reference Richards core, transaction architecture, Restart v1, serialized MultiSWAP v1, drainage, surface evaporation, bounded WOFOST runtime, restricted Snow and Groundwater Coupling v1.

## Why this distinction matters for peer review

There are two useful but different questions:

1. **Did SWAP5 preserve the admitted scientific/numerical contracts while the software architecture was rebuilt?**  
   The Status-A qualification/evidence chain supports this bounded claim for the admitted denominator.

2. **Can the complete historical Hupsel application already be run side-by-side through SWAP 4.3.1 and SWAP5 under one formally identical application mapping?**  
   Not yet. The legacy side is now well qualified; the complete SWAP5 application mapping remains the missing experimental prerequisite.

Keeping those statements separate makes the review stronger rather than weaker: reviewers can see exactly what is proven, how it is proven and what remains to be demonstrated.

## Additional recovered legacy evidence

The later F-AR01 reconciliation recovered and classified additional legacy audit packages, including reference testbank and performance/correctness work. That material is evidence/provenance support; it does not silently broaden the frozen Status-A scientific denominator.

## Review recommendation

For the first colleague review, assess the rebuild at two levels:

- **capability equivalence/preservation**, using the current Status-A traceability and qualification evidence;
- **whole-application continuity**, using F-VQ99 as the transparent current state of the direct SWAP 4.3.1/Hupsel campaign.

When the complete application-level mapping is admitted and the long Hupsel run is executed through SWAP5, its result can be added here as a stronger external equivalence authority without rewriting the existing Status-A evidence chain.
