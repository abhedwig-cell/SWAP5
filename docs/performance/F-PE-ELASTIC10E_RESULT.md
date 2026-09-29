# F-PE-ELASTIC10E — BHR-GT mechanical target extraction result

Date: 2026-09-29

Status: MECHANICAL_TARGET_CORPUS_QUALIFIED_NO_PTF

Workflow:
`F-PE-ELASTIC10E BHR-GT mechanical target extraction`

Run:
`36531232195`

Qualified execution head:
`97b782e1734d5724a58af267c3d5eed933a86cbe`

Artifact:
`f-pe-elastic10e-mechanical-targets`

Artifact id:
`11016752492`

Artifact digest:
`sha256:da74c45f96f53d7f71df5793fd7b0a7512bc84c79206af2093616ca430b8b944`

Parent authorities:
- F-PE-ELASTIC10D frozen 16-object BHR-GT sample;
- F-PE-ELASTIC11A source-bound SWE field order and units;
- F-PE-ELASTIC06B USGS consolidation-to-specific-storage identity.

## Deterministic extraction

The extractor was run twice independently against the same frozen raw object
bytes and schema artifacts.

The two output trees were byte-identical.

Marker:
`F_PE_ELASTIC10E_T3_DETERMINISM=PASS`.

No changed BHR-GT object was silently substituted.

## Corpus result

Frozen objects:
`16`.

Valid mechanical targets:
`47`.

By route:
- R2 load-controlled explicit unload targets: `29`;
- R3 effective-stress unload targets: `18`.

Explicit rejected candidates:
`3`.

All three rejections are retained as evidence with reason
`NONPOSITIVE_OR_ZERO_SECANT`; no extraction rule was relaxed to recover them.

All 16 frozen objects emit at least one valid target.

## Mechanical target definition

For every valid target:

`mv = abs(delta epsilon_v / delta sigma'_v)`

or, for R2 where only total vertical test stress is source-bound,

`mv = abs(delta epsilon_v / delta sigma_v)`.

Strain is dimensionless and stress is converted from kPa to Pa.

The skeletal one-dimensional specific-storage target is:

`Ssk = gamma_w * mv`

with frozen
`gamma_w = 9806.65 N/m3`.

Water compressibility is not folded into these targets.

## Observed unfiltered target range

Across all 47 targets:

### Constrained compressibility

`mv`:
- minimum: `5.5188e-10 Pa^-1`;
- median: `8.2222e-8 Pa^-1`;
- maximum: `5.8816e-7 Pa^-1`.

### Skeletal specific storage

`Ssk` in m^-1:
- minimum: `5.4121e-6`;
- 10th percentile: `1.2469e-4`;
- median: `8.0632e-4`;
- 90th percentile: `4.4474e-3`;
- maximum: `5.7679e-3`.

Equivalent in cm^-1:
- minimum: `5.4121e-8`;
- median: `8.0632e-6`;
- maximum: `5.7679e-5`.

No target was removed using an empirical plausibility cutoff.

## Route-specific distributions

### R2

Targets:
`29`.

`Ssk` in cm^-1:
- minimum: `1.2923e-6`;
- median: `9.3569e-6`;
- 90th percentile: `4.8613e-5`;
- maximum: `5.7679e-5`.

### R3

Targets:
`18`.

`Ssk` in cm^-1:
- minimum: `5.4121e-8`;
- median: `4.5382e-6`;
- 90th percentile: `2.6577e-5`;
- maximum: `3.2757e-5`.

The route difference is descriptive only. R2 and R3 are different experimental
protocols and stress-path observations; this workunit does not interpret their
distributional difference as a method bias estimate.

## Relation to Pim Dik's 1e-6 cm^-1 candidate

The proposed reference magnitude

`1e-6 cm^-1 = 1e-4 m^-1`

lies inside the observed BHR-GT mechanical scale but below the corpus median.

Among the 47 unfiltered mechanical targets:
- 3 are below `1e-6 cm^-1`;
- 24 are between `1e-6` and `1e-5 cm^-1`;
- 20 are between `1e-5` and `1e-4 cm^-1`;
- none exceed `1e-4 cm^-1`.

The corpus median is about 8.1 times `1e-6 cm^-1`.

This does **not** imply that SWAP should use the corpus median or that Pim's
candidate is too small. The population and stress conditions differ from the
intended SWAP soil-layer application.

## Depth boundary

The mechanical targets are geotechnical subsurface samples, not a representative
agricultural topsoil sample.

Source-bound interval depths for the 47 targets span approximately:
- shallowest begin depth: `1.36 m`;
- median interval midpoint: `4.835 m`;
- deepest end depth: `12.79 m`.

Therefore this corpus is strong evidence for the physical scale and variability
of Dutch soil/sediment skeleton storage, but it is not direct calibration
authority for root-zone BOFEK/Staringreeks layers.

A depth/material/stress bridge is required before transferring these values to a
production soil-parameter generator.

## Scientific interpretation

The extracted Dutch observations materially strengthen the earlier literature
conclusion:

1. physical elastic storage varies by orders of magnitude;
2. a single universal ELAS is not supported as a general physical law;
3. `1e-6 cm^-1` is physically plausible within the Dutch mechanical evidence;
4. many observed unload/reload tangents imply larger skeletal storage;
5. effective stress, depth, material structure and test route matter;
6. the appropriate SWAP value cannot be identified from MvG parameters alone.

The result also supports the distinction between:
- legacy-compatible scalar per-layer ELAS;
- a future stress/state-dependent mechanical formulation.

## Predictor-model boundary

No descriptor -> ELAS/Ssk model is fitted here.

Before any predictive model:
- freeze object-level calibration and holdout groups;
- bind mechanical/pedological descriptors independently of target magnitude;
- keep object identity grouped so multiple determinations from one object cannot
  leak across calibration and holdout;
- model depth/stress applicability explicitly;
- retain R2/R3 route identity;
- do not optimize against SWAP runtime performance.

## Decision

F-PE-ELASTIC10E succeeds.

Classification:

`DUTCH_MECHANICAL_SSK_TARGET_CORPUS_QUALIFIED`.

The result establishes a reproducible Dutch physical target corpus for the next
parameterization phase.

It does not establish:
- a production ELAS default;
- a BOFEK/Staringreeks lookup;
- a pedotransfer relation;
- topsoil transferability;
- a stress-independent universal coefficient.
