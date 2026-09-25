# F-PE-PROFILE02 — post-zero-waste performance re-baseline

Date: 2026-09-25

Status: `PREREGISTERED_BASELINE_1`

Production-source authority at branch creation: `f5ba657695156a936cb3dc8e14669f92d333753b` from `work/f-pe-zero-waste01`.

## Purpose

PROFILE02 rebuilds the SWAP5/MultiSWAP hotspot map after F-PE-ZERO-WASTE01. Historical rankings are context only. No production optimization is authorized by this workunit.

Governing sequence:

`RECONCILE -> BIND AUTHORITY -> PREREGISTER -> MEASURE -> DECOMPOSE -> RANK -> SELECT -> CLOSE`

## Boundaries

PROFILE02 does not change physics, tolerances, water-balance gates, transaction semantics, solver policy, or accepted-state semantics.

F-AHL remains the owner of adaptive hydraulic representation work. If constitutive evaluation is material, PROFILE02 will report that as a handoff, not implement a competing lookup.

RossFast may be used only as a comparison route to understand solver-cost attribution.

Approximate/practical application modes are excluded from implementation here.

## Reused measurement authority

The first scale baseline reuses the production application bootstrap route already exercised by APPQUAL01, but PROFILE02 records a different evidence packet:

- setup time separated from repeated interval work;
- N=1, 100, 1,000 and 10,000;
- completed and committed column count;
- solver call count;
- accepted substeps;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- HeadCalc calls;
- internal solver retries;
- backtracking attempts;
- maximum column mass residual.

This is a workload benchmark, not a portable machine speed claim.

## Preregistered baseline matrix

| ID | N | regime | route | repetitions | role |
| --- | ---: | --- | --- | ---: | --- |
| P02-S1 | 1 | reference equilibrium-like | cleaned Reference Richards | 3 | single-column denominator |
| P02-S100 | 100 | reference equilibrium-like | cleaned Reference Richards | 3 | small MultiSWAP scale |
| P02-S1000 | 1,000 | reference equilibrium-like | cleaned Reference Richards | 3 | medium scale |
| P02-S10000 | 10,000 | reference equilibrium-like | cleaned Reference Richards | 3 | large-N scale |

The first workload intentionally keeps optional processes disabled so the initial scale curve measures the cleaned core route. This is not the final difficulty matrix.

## Difficulty matrix to add after baseline seam is proven

At minimum the same counters will be collected for bounded fixtures representing:

- wet start;
- dry start;
- strongly dry state;
- coarse-sand/O5-like behavior using an existing repository authority if available;
- heavy-clay behavior using an existing repository authority if available;
- a trajectory with multiple Newton iterations;
- a trajectory with rejected trials or timestep reduction;
- source/sink or oxygen-stress load only if a qualified fixture demonstrates material cost.

No synthetic difficult fixture will be labelled O5 or heavy clay without a repository source for that parameterization.

## Cost classification

Every measured hotspot will be classified as one of:

- A: remaining pure software waste;
- B: necessary work that can remain exact but cheaper;
- C: solver/numerical algorithm work;
- D: constitutive/hydraulic evaluation;
- E: workload/difficulty-dependent work;
- F: coupling/application overhead;
- G: requires approximation or a changed error budget.

## Initial decision rule

The first baseline is sufficient to answer only:

1. whether repeated execution remains approximately linear in N;
2. whether one-time setup has become material relative to one interval;
3. which solver counters scale directly with N on an easy/reference workload;
4. whether any residual orchestration cost is visible from non-linear scale behavior.

No optimization workunit will be opened from this baseline alone unless the result exposes an unambiguous measurement defect or residual pure-waste anomaly.

## Closeout target

PROFILE02 closes only after the easy/reference scale baseline is joined by a difficulty decomposition and a ranked post-zero-waste hotspot map, with no more than two next exact-performance workunits selected.
