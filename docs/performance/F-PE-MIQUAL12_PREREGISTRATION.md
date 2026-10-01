# F-PE-MIQUAL12 preregistration — serialized manager component-cost attribution

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_PROFILING_RESULTS`

Canonical authority:

`integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5`

Parent authority:

- MIQUAL11: `MIQUAL11_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`.

## Purpose

Measure which runtime-adapter components dominate the remaining serialized manager overhead before any further optimization.

MIQUAL12 is diagnostic-only. It must not change moving-interface physics, eligibility, reconstruction, tolerances, fallback semantics or benchmark workload.

## Frozen profiling workload

Reuse the MIQUAL09 equilibrium production-shaped workload:

- N=16;
- saturated tail start node 13;
- top flux = 0;
- qbot = 0;
- zero sources/sinks;
- 40,000 committed external intervals;
- external full-half temporal transaction;
- explicit manager profile;
- full accepted-state authority.

## Frozen phase accounting

Instrument cumulative process CPU time inside the moving-interface runtime adapter for:

1. `eligibility_tail`
   - runtime-envelope validation after entry;
   - saturated-tail discovery;
   - active-view derivation.

2. `reduced_request`
   - persistent reduced request preparation;
   - base-state slicing/copy.

3. `provider_prepare`
   - reduced constitutive/source provider preparation and binding.

4. `reduced_solve`
   - reduced Reference/HeadCalc solve only.

5. `reconstruct_materialize`
   - saturated-tail reconstruction;
   - full-shape candidate rematerialization.

6. `finalize_publish`
   - manager finalization;
   - selected-result publication/copy inside the adapter.

Also report:

- manager solve-call count;
- reduced/fallback/bypass count where available;
- total attributed adapter CPU;
- non-solver adapter CPU = total minus reduced_solve.

Instrumentation overhead itself is not a production speed measurement. Phase ratios are diagnostic.

## Interpretation

Classify the largest non-solver contributor only if it is clearly larger than the others.

Frozen classes:

- `QUALIFIED_MIQUAL12_DOMINANT_REQUEST_COPY_OVERHEAD`
- `QUALIFIED_MIQUAL12_DOMINANT_PROVIDER_OVERHEAD`
- `QUALIFIED_MIQUAL12_DOMINANT_RECONSTRUCTION_PUBLICATION_OVERHEAD`
- `QUALIFIED_MIQUAL12_DISTRIBUTED_ADAPTER_OVERHEAD`
- `MIQUAL12_PROFILE_INCONCLUSIVE`
- `MIQUAL12_EXECUTION_INVALID`

A successor optimization may target only the measured dominant class.

## Production boundary

No production source from MIQUAL12 is admission-ready because profiling calls perturb the hot path.

`LEGACY_NUMERICS` remains production default.
