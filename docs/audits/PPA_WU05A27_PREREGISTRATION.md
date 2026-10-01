# PPA-WU05-A27 preregistration — RFM performance versus hydrologic equivalence

Date: 2026-10-01
Status: PREREGISTERED
Canonical base: 19f09b818b1bb30c1428919074c00098dbd062bd

## Purpose

Quantify whether the production-admitted bounded RFM route provides a material runtime/stability advantage over the existing standard SWAP macropore runtime without obtaining that advantage by materially changing the simulated hydrologic response.

This is a paired benchmark. Speed alone cannot qualify RFM.

The standard macropore runtime is a behavioral comparator, not assumed ground truth. Where the two formulations differ, the result must be attributed to a known conceptual difference or classified as unresolved.

## Paired experiment

For every case run:
A. matrix-only Reference Richards;
B. standard SWAP macropore runtime;
C. production RFM runtime.

Use identical:
- soil profile and matrix hydraulics;
- initial pressure/water state;
- atmospheric forcing;
- bottom boundary;
- numerical tolerances where semantically shared;
- simulated interval and output sampling.

Macropore parameters must be mapped from the same physical case description. Do not tune RFM to reproduce the standard module case-by-case.

## Regime matrix

At minimum cover:
1. dry profile + short intense storm;
2. moderately wet profile + intense storm;
3. wet/near-saturated profile + storm;
4. long moderate rainfall;
5. repeated storms with incomplete inter-event recovery;
6. low/no preferential-flow control case;
7. cases with terminating IC storage;
8. cases dominated by deep MB routing.

Include more than one soil/hydraulic profile and more than one macropore geometry.

## Performance/stability observables

Measure per simulated day and per accepted interval:
- wall-clock runtime after warm-up;
- Richards solve count;
- nonlinear iteration count;
- backtracking count;
- rejected/retried intervals;
- accepted timestep distribution;
- minimum accepted timestep;
- RFM/macropore-specific evaluation count;
- fraction of runtime attributable to matrix solve versus preferential-flow processing where measurable.

For scaling, repeat representative cases as an embarrassingly parallel column ensemble using identical per-column forcing/state. Report throughput per column and aggregate throughput. Do not infer 100k-column scaling from a single-column timing alone.

## Hydrologic equivalence observables

Compare standard macropore versus RFM for:
- cumulative surface input accepted;
- cumulative matrix infiltration;
- cumulative preferential input;
- cumulative macropore/endpoint-to-matrix exchange;
- cumulative deep preferential receipt/outflow;
- runoff;
- ponding;
- bottom flux/drainage;
- profile water storage;
- water balance residual;
- pressure head and water-content trajectories at representative depths;
- event timing and magnitude of preferential/deep response.

Use both cumulative/event-integrated metrics and trajectory metrics. A similar final water balance alone is insufficient.

## Interpretation

No universal equality is preregistered because the formulations are not identical.

Classify differences as:
- E0: numerically indistinguishable / zero-preferential limit;
- E1: same hydrologic response class, small quantitative differences;
- E2: material quantitative difference with identified conceptual cause;
- E3: unexplained qualitative divergence.

A production-performance claim requires no E3 cases in the bounded benchmark envelope.

Performance results must be reported jointly with the equivalence class. A speedup attached to an E3 case is not evidence of useful acceleration.

## Stability claim

RFM may be called more stable only if, across the paired regime set, it shows evidence such as fewer retries, fewer nonlinear iterations/backtracks, or less timestep collapse without a corresponding deterioration to E3 hydrologic behavior.

## Falsification

The route is falsified as a drop-in practical replacement in any regime where:
- qualitative flow partitioning diverges without an identified model-form reason;
- water ownership/ledger fails;
- refinement does not approach a stable response;
- apparent speedup is mainly caused by suppressing a physically relevant pathway;
- standard macropore behavior cannot be represented because the parameter mapping lacks a physically defensible correspondence.

## Deliverables

Persist:
- exact case definitions and parameter mapping;
- raw timing/solver counters;
- hydrologic comparison tables;
- event hydrographs/trajectories where useful;
- per-regime equivalence classification with rationale;
- performance ratios with uncertainty/repetition;
- explicit recommendation of the envelope where RFM is a credible production alternative.
