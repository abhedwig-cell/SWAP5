# SWAP5 publication portfolio

Status: **working publication-governance contract**

This document separates the main SWAP5 publication lines so that shared software, test infrastructure and model cases can be reused without reusing the same primary scientific inference in multiple papers.

The governing rule is:

> Shared infrastructure may support multiple papers. A primary scientific result, figure, table or conclusion has one publication owner.

There is deliberately no `RESULT_FOR_BOTH` category.

## Publication lines

| Code | Working topic | Primary research question | Protected primary contribution |
| --- | --- | --- | --- |
| `PUB-ME` | Controlled model evolution | How can an established scientific model be modernized while preserving scientific meaning and qualification evidence? | state ownership, transactional execution, migration slices/gates, behavior-preserving evolution and SWAP4.3.1 to SWAP5 equivalence |
| `PUB-SQ` | Solver qualification | When may an alternative numerical solver replace the reference Richards solver? | solver admissibility domains, accuracy, conservation, robustness and cost trade-offs, including RossFast/reference comparisons |
| `PUB-GC` | Groundwater coupling | How can independently time-integrating vadose-zone and groundwater models be coupled conservatively and reproducibly over finite coupling windows? | same-origin replay, whole-window exchange, interface conservation and coupled accepted-state semantics |
| `PUB-RC` | Response-assisted coupling | Can the whole-window response of the vadose zone to groundwater head be used to solve the nonlinear interface problem more efficiently? | response/tangent information, accelerated outer coupling and error-versus-cost behaviour |
| `PUB-SG` | Subgrid heterogeneity and upscaling | When must heterogeneous vadose-zone columns within a groundwater cell be represented explicitly? | hydrologic consequences of explicit N:1 subgrid heterogeneity versus effective/homogenized representations |

`PUB-SG` is conditional. It becomes a paper only if the experiments demonstrate a material, explainable hydrologic effect that is not already needed to establish `PUB-GC` or `PUB-RC`.

## Hard claim boundaries

### `PUB-ME`

Owns general software/model-evolution claims about transactional architecture, state ownership, scientific migration, qualification gates and behavior preservation.

Does **not** own:

- RossFast/reference regime maps or solver speed/accuracy conclusions;
- groundwater-coupling accuracy or convergence conclusions;
- response/tangent acceleration conclusions;
- N:1 hydrologic upscaling conclusions.

### `PUB-SQ`

Owns scientific qualification of solver substitution.

Does **not** own:

- transactional architecture as a general novelty;
- SWAP4.3.1 to SWAP5 migration methodology;
- groundwater-coupling novelty;
- regional/subgrid hydrologic conclusions.

A coupled groundwater workload may be reused as infrastructure, but solver-comparison figures and admissibility conclusions remain `PUB-SQ` results.

### `PUB-GC`

Owns the correctness and numerical consistency of the vadose-zone/groundwater coupling formulation.

Does **not** own:

- the general SWAP5 transaction architecture;
- solver substitution or RossFast performance;
- response/tangent acceleration as a primary result;
- regional N:1 upscaling effects.

`PUB-GC` may rely on checkpoint/replay as a required coupling property, but it must not present the generic transaction architecture as its own software-engineering contribution.

### `PUB-RC`

Owns acceleration of the nonlinear coupling problem through response, tangent, quasi-Newton or related interface information.

Does **not** own the base coupling formulation itself. Base conservation, replay and accepted-state semantics are inherited from `PUB-GC`.

### `PUB-SG`

Owns hydrologic upscaling and heterogeneity consequences. It may reuse the coupling implementation and performance infrastructure, but not the primary numerical-coupling conclusions of `PUB-GC` or acceleration conclusions of `PUB-RC`.

## Evidence ownership

Every publication-relevant workunit should record at least:

```yaml
publication_relevance:
  primary: PUB-GC | PUB-ME | PUB-SQ | PUB-RC | PUB-SG | SHARED-INFRASTRUCTURE
  reusable_infrastructure:
    - PUB-...
  primary_claim: <one sentence or null>
  evidence:
    - <test/run/artifact/commit reference>
  candidate_figures_tables:
    - <identifier or null>
  excluded_primary_claims:
    - PUB-...
```

The `primary` field identifies ownership of the scientific inference, not necessarily ownership of the code or test harness.

## Reuse rules

A model case, benchmark harness, MODFLOW input, SWAP forcing series, timing collector or common reference dataset can be `SHARED-INFRASTRUCTURE` and reused across papers.

A derived result such as:

- a migration-equivalence curve;
- a RossFast admissibility map;
- a coupling-window convergence plot;
- a response-assisted iteration reduction plot; or
- a subgrid-versus-homogenized groundwater-impact plot

must have one primary publication owner.

The same raw simulation may therefore feed multiple publications only when each paper derives a genuinely different, pre-declared inference from it.

## Figure and table firewall

Before a figure or table becomes manuscript evidence, record:

1. its publication owner;
2. the claim it supports;
3. the exact run/evidence identifiers from which it is derived;
4. whether another publication may reuse only the underlying data or infrastructure;
5. explicit exclusions.

A figure that is necessary for the primary conclusion of one paper must not be reused as primary evidence for another paper.

## Development rule

Publication tracking must be prospective rather than reconstructed after implementation. When a workunit begins to create data that may become publication evidence, assign publication relevance before or at qualification time.

This publication layer does not replace SWAP5 capability authority, scientific qualification or canonical admission. It is an additional traceability layer from implementation/evidence to manuscript claim.

## Current portfolio dependency order

The scientific dependency is intentionally one-way:

```text
PUB-ME   PUB-SQ
   \       /
    shared qualified SWAP5 implementation
              |
            PUB-GC
              |
            PUB-RC
              |
       PUB-SG (conditional)
```

This diagram does not imply manuscript submission order. It means only that later coupling papers may rely on already qualified software and solver capabilities without re-claiming their scientific contributions.
