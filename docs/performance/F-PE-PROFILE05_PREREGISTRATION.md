# F-PE-PROFILE05 — combined practical-stack performance rebaseline

Date: 2026-09-26

Status: `PREREGISTERED_NOT_STARTED`

Parent:
`F-PE-APPROX03`

Practical modes retained from prior work:

- A1 — bounded same-origin tangent cache;
- A2C — strict-practical Richards convergence envelope.

APPROX03 result:

- no temporal-budget production opt-in retained.

## Purpose

Re-measure the production-shaped runtime distribution after applying the currently retained practical modes together.

PROFILE05 is observation-only.

It does not introduce a new approximation and does not modify `src/**`.

The purpose is to decide where a new performance workunit should look next, rather than continuing to relax numerical controls by intuition.

## Questions

1. What fraction of current repeated application runtime remains in Reference/transaction execution?
2. How much of the former bottom-head directional overhead remains after A1?
3. How much Richards nonlinear work remains after A2C?
4. Does temporal acceptance still contribute material runtime in production-shaped workloads despite APPROX03 rejection?
5. What fraction is now outside SWAP solve execution, including coupling, application/context handling and MODFLOW work?
6. Are there any remaining repeated allocations, copies, constitutive reevaluations or transaction preparation costs large enough to justify a separate exact workunit?

## Required modes

Measure at minimum:

- exact default;
- A1 only;
- A2C only;
- A1 + A2C.

Do not infer combined speedup by adding results from earlier workunits.

All combined claims must come from same-postimage measurements.

## Production-shaped workloads

At minimum include:

- the production application sequence used in APPROX01/APPROX02;
- live SWAP + MODFLOW6 coupling;
- a repeated participant/corrector workload;
- representative B01/B12/O05/O14 wet/mid/dry direct workloads where useful for attribution.

Prefer workloads that expose the current production route rather than isolated solver arithmetic.

## Measurements

### End-to-end
- total wall-clock runtime;
- SWAP participant runtime;
- MODFLOW/runtime outside SWAP where measurable;
- coupling iteration count;
- accepted transaction count.

### Richards work
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- accepted substeps;
- retries;
- HeadCalc calls.

### Directional work
- fresh tangents;
- reused tangents;
- tangent refresh rate;
- directional constitutive passes where observable.

### Runtime structure
- setup versus repeated execution;
- transaction/reference execution;
- application/context wrapper work;
- other measurable dominant regions.

## Timing policy

Use replicated same-postimage timings.

Do not add percentages across unrelated microbenchmarks.

For short coupled loops, report all replicas and treat the spread explicitly as timing variance.

## Interpretation rule

PROFILE05 may identify a new candidate hotspot, but must not modify production implementation.

Any new optimization or approximation lever requires a separately preregistered workunit.

A candidate hotspot should advance only when:

- it is materially present in production-shaped timing;
- its ownership is clear;
- the proposed next experiment can isolate one mechanism;
- and there is a plausible route to measurable end-to-end benefit.

## Closure

PROFILE05 closes with:

1. a current post-A1+A2C runtime decomposition;
2. an end-to-end practical-stack speedup measurement against exact default;
3. a ranked factual hotspot list by measured cost, without speculative percentage addition;
4. one separately preregistered next workunit if a material target remains;

or with a finding that no remaining SWAP-side hotspot justifies another performance workunit.
