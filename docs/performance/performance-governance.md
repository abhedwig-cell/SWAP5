# SWAP5 performance governance

**Scope:** SWAP5 and MultiSWAP performance development  
**Status:** Governing principle  
**Applies to:** performance workstreams, solver work, hydraulic acceleration, runtime/orchestration work, and future coupled practical modes

## Purpose

SWAP5 performance development follows a fixed order of reasoning. Speed is not treated as one optimization problem. A performance change must first be classified by what is being avoided, changed, or approximated.

The governing rule is:

> Compute nothing that is not needed. Compute necessary quantities as cheaply as possible. Do not compute them more accurately than the application justifies.

For every admitted performance change, the evidence must state where the speedup comes from and what, if any, numerical error, approximation, uncertainty, or applicability restriction is introduced in return.

## Three performance classes

### 1. Remove unnecessary work

The first priority is work that contributes nothing to the requested result.

Examples include:

- redundant loops;
- repeated initialization or workspace clearing;
- unnecessary allocation and deallocation;
- avoidable state or buffer copies;
- repeated conversions;
- repeated searches or registry scans for information already known;
- recomputation of values that can be reused safely;
- orchestration or bookkeeping whose result can be established once and validated.

This class is reference-preserving by construction. No physical or numerical concession is accepted in exchange for speed.

A change in this class must demonstrate that the removed work is unnecessary for the authoritative result and that state ownership, transaction semantics, diagnostics required for correctness, and failure behavior remain valid.

### 2. Compute the same model meaning more efficiently

After unnecessary work has been removed, necessary calculations may be replaced by cheaper formulations or execution strategies while retaining the intended SWAP model meaning.

Examples can include:

- automatically generated hydraulic lookup or adaptive representations;
- analytic derivatives instead of repeated numerical differentiation;
- safe caching or reuse of constitutive results;
- more efficient data access;
- better linear or nonlinear solver strategies;
- RossFast or other solver paths where they are qualified against the reference model within an explicit envelope.

This class may change the numerical route, but standard SWAP/Richards remains the scientific reference unless a workstream explicitly declares otherwise.

Qualification must therefore use strict reference criteria and must separate speed gain from any numerical difference.

### 3. Deliberately use less numerical accuracy when the application permits it

Only after classes 1 and 2 have been exploited or characterized may a practical/approximate mode deliberately trade reference fidelity for runtime.

This mode is particularly relevant to large coupled MultiSWAP applications, including SWAP5-MODFLOW6 workflows, where the most useful answer may be the fastest physically adequate representation rather than the closest possible reproduction of the standard SWAP trajectory.

Approximation must be explicit and prequalified. The admissible error envelope must be stated in terms of quantities relevant to the intended application, for example:

- cumulative fluxes;
- root-zone water state;
- groundwater exchange;
- drainage or evapotranspiration totals;
- event timing or peak fluxes where these matter;
- management or coupling decisions derived from the state.

A single generic percentage difference from standard SWAP is not sufficient as an acceptance definition when different variables have different physical significance.

## Water and mass accounting

Approximation relative to the standard SWAP reference is not the same as allowing unexplained internal water loss or creation.

For every execution mode:

- the water accounting of the chosen calculation must close within its declared numerical tolerance;
- internal conservation defects must be reported as numerical defects, not hidden inside an approximation allowance;
- an approximate mode may produce different states or flux partitions from standard SWAP when those differences lie inside its declared application envelope.

Thus an approximate run may be physically acceptable while differing from the standard-SWAP reference, but it may not justify speed by silently violating its own mass-accounting contract.

## Precision follows information value

Numerical effort should be proportional to the information carried by the quantity for the target calculation.

This principle permits investigation of stopping, truncation, representation, solver, timestep, and coupling criteria that avoid spending CPU on distinctions that cannot materially affect the admitted outputs. Such decisions still require explicit qualification; apparent smallness alone is not evidence of irrelevance.

## Required evidence for performance claims

A performance result is not admitted only because wall-clock time decreases.

The record must identify:

1. the performance class above;
2. the source identity and benchmark workload;
3. the work that was removed, replaced, or approximated;
4. the measured runtime effect;
5. the relevant physical and numerical comparison;
6. mass-accounting behavior;
7. the applicability envelope and fallback behavior;
8. any added state, memory, preprocessing, validation, or maintenance cost.

Where a speedup is composed of several mechanisms, their contributions should be separated where practicable.

## Consequence for workstream ordering

The preferred order for SWAP5/MultiSWAP performance work is therefore:

1. remove waste and orchestration overhead;
2. re-profile the remaining necessary computation;
3. make the necessary computation cheaper while preserving model meaning;
4. characterize alternative qualified solver paths;
5. only then introduce and qualify application-specific approximation.

The ordering is methodological, not a ban on parallel research. Approximate-mode research may proceed in parallel, but its evidence and admission criteria must remain separate from reference-preserving optimization.

## Relationship to existing performance documentation

This document governs the interpretation of the measurement architecture and subsequent performance workstreams. The measurement architecture remains responsible for how runtime, counters, memory, solver effort, retries, and batching cost are observed. This document defines how performance changes are classified and what scientific concession, if any, they are allowed to make.
