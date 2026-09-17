# SWAP5 two-paper publication programme

## Purpose

This document separates two publication lines that share the SWAP5 codebase and some qualification infrastructure but must not share the same primary scientific result.

The separation is intentional from the start to prevent duplicate publication, retrospective claim splitting and accidental reuse of one novelty claim in two manuscripts.

## Publication lines

### P1 - Model evolution

Research question:

> How can a mature time-stepped scientific model be structurally transformed while preserving its established scientific behaviour and maintaining auditable evidence of equivalence throughout the migration?

Primary result class:

- evidence-preserving scientific software evolution;
- explicit authoritative-state ownership;
- transactional interval semantics;
- qualification-gated migration;
- preservation of established scientific behaviour through substantial architectural change.

Research design:

`PAPER1_MODEL_EVOLUTION_RESEARCH_DESIGN.md`

### P2 - Solver admissibility

Research question:

> Under which physical and numerical conditions can an alternative soil-water solver replace the reference Richards solver in a complete process-based model without materially changing the simulated hydrological system?

Primary result class:

- solver discrepancy as a function of hydrological and numerical regime;
- admissibility and exclusion domains;
- accuracy, conservation and cost trade-offs;
- interpretable boundaries for qualified solver substitution.

Research design:

`PAPER2_SOLVER_ADMISSIBILITY_RESEARCH_DESIGN.md`

## Publication firewall

The same code, test harness or reference dataset may support both studies. The same primary scientific inference may not.

A result is not made distinct merely by changing the figure style, subset of cases or wording.

### Ownership matrix

| Evidence or claim | P1 | P2 | Classification |
| --- | --- | --- | --- |
| SWAP 4.3.1 scientific reference shield | primary evidence | background only | P1_RESULT |
| SWAP4.3.1 to SWAP5 state/flux equivalence | primary evidence | assumed platform qualification | P1_RESULT |
| explicit data ownership | primary architectural claim | infrastructure | P1_RESULT |
| committed versus trial state | primary architectural claim | infrastructure | P1_RESULT |
| retry/rollback/commit fault-injection tests | primary evidence | infrastructure | P1_RESULT |
| generic `[t0,t1]` interval semantics | primary architectural claim/evidence | infrastructure | P1_RESULT |
| solver seam exists and accepts second solver | architectural consequence | experimental enabler | SHARED_INFRASTRUCTURE |
| RossFast is wired without a second application lifecycle | architectural probe | platform fact | SHARED_INFRASTRUCTURE |
| RossFast versus Reference state discrepancy | not a result | primary result | P2_RESULT |
| RossFast versus Reference flux discrepancy | not a result | primary result | P2_RESULT |
| RossFast versus Reference water-balance comparison | not a result | primary result | P2_RESULT |
| RossFast speedup | not a result | primary result after admissibility | P2_RESULT |
| physical/numerical regime map | excluded | primary result | P2_RESULT |
| solver-admissibility domain | excluded | primary novelty | P2_RESULT |
| solver exclusion/fail-closed scientific criteria | excluded | primary novelty | P2_RESULT |
| MultiSWAP scaling architecture | possible architectural consequence only | possible experimental context | SHARED_INFRASTRUCTURE unless separately studied |
| MODFLOW coupling architecture | possible architectural consequence only | outside current P2 scope | NOT_CURRENT_RESULT |

## Evidence tags

Publication evidence records should use one of the following classifications.

### `PUB_P1_RESULT`

Evidence may support a primary result or conclusion in Paper 1. It must not become a primary result of Paper 2.

Examples:

- legacy/reference equivalence after a migration slice;
- state non-mutation after rejected trial;
- single-commit proof;
- flux-accounting proof over retry;
- evidence that a successor capability reuses the established transaction lifecycle.

### `PUB_P2_RESULT`

Evidence may support a primary result or conclusion in Paper 2. It must not become a primary result of Paper 1.

Examples:

- solver-specific state or flux discrepancy;
- solver performance inside a prequalified regime;
- transition from admissible to excluded behaviour;
- mechanism-specific solver divergence;
- regime-specific solver-selection or exclusion rule.

### `PUB_SHARED_INFRASTRUCTURE`

The artifact enables both studies but is not itself a primary scientific result in either manuscript.

Examples:

- common solver ABI;
- execution harness;
- reference case materialization;
- output extraction tools;
- benchmark runner;
- data format used to collect publication metrics.

### `PUB_CONTEXT_ONLY`

Useful for manuscript background, provenance or reproducibility but not part of the scientific inference.

### `PUB_NOT_CURRENT`

Scientifically interesting but outside both present publication claims. This prevents adjacent capabilities from being silently pulled into either scope.

## Rule for shared evidence

An artifact may be used by both papers only when its role differs clearly:

- in one paper it may be a qualified platform assumption;
- in the other it may generate the primary comparison.

Example:

The common soil-water solver seam can be shown in P1 as evidence that the architecture admits a new solver without a second lifecycle. In P2 the seam is simply the controlled experimental platform. The seam itself is not re-claimed as novelty in P2.

## Duplicate-publication guard

Before a figure, table or quantitative result is assigned to a manuscript, record:

1. the research question it answers;
2. whether it changes a primary conclusion;
3. the owning paper;
4. whether the other paper needs it only as background or infrastructure;
5. whether a cross-reference is required.

A figure or table carrying a primary conclusion in P1 must not carry a primary conclusion in P2, and vice versa.

Reusing a small factual platform description is acceptable. Reusing a result and drawing a second nominally different conclusion from the same analysis requires explicit review.

## Evidence record schema

Publication-grade evidence should be recorded with at least:

```text
publication_class: PUB_P1_RESULT | PUB_P2_RESULT | PUB_SHARED_INFRASTRUCTURE | PUB_CONTEXT_ONLY | PUB_NOT_CURRENT
capability_or_experiment:
source_branch:
source_head:
reference_baseline:
scientific_question:
independent_variables:
response_variables:
predeclared_tolerances:
cases:
result:
limitations:
primary_paper: P1 | P2 | NONE
allowed_secondary_use:
artifact_locations:
```

Where evidence already exists in immutable qualification artifacts, the publication record should point to it rather than duplicate or rewrite it.

## P1 evidence backlog

Highest-priority missing or not-yet-publication-organized evidence:

1. Freeze a publication qualification set representing contrasting hydrological and numerical conditions.
2. Assemble state, integrated-flux and water-balance equivalence across major migration boundaries.
3. Collect directed transaction fault-injection evidence into one reproducible publication dataset.
4. Record examples where qualification gates detected or prevented a scientifically relevant regression.
5. Demonstrate at least one substantial successor capability using the same state/transaction lifecycle without duplicating process physics.
6. Translate the SWAP-specific M0-M8 history into a general migration method without overstating universality.

## P2 evidence backlog

Highest-priority new research:

1. Convert the current restricted RossFast envelope into explicit experimental baseline `E0`.
2. Define state, integrated-flux and mass-balance discrepancy metrics and tolerances before broad benchmarking.
3. Design Stage A space-filling experiments over soil, initial state, forcing, grid and timestep dimensions.
4. Add targeted difficult-regime tests based on the Richards-equation literature.
5. Expand physical process context only through independently qualified stages.
6. Identify and refine transition regions where solver discrepancies cross the declared scientific tolerances.
7. Test whether admissibility boundaries can be predicted from known physical/numerical descriptors.
8. Add computational-cost analysis only after scientific admissibility is evaluated.
9. Validate controlled-domain conclusions against representative long-running SWAP trajectories.

## Decision points

### P1 go/no-go

Proceed to manuscript construction when:

- a representative preservation dataset exists;
- transactional semantics are tested under directed failure and retry;
- at least one substantive successor capability demonstrates architectural separability;
- the resulting method can be described without claiming generic software practices as new.

### P2 go/no-go

Proceed to manuscript construction only when at least one of the following exists:

- an interpretable admissibility domain with scientifically meaningful boundaries;
- a generalizable pre-execution solver-selection or exclusion principle.

If the result is only average error plus average speedup, do not pursue the intended P2 claim.

## Relationship between manuscript timing

The two research lines may develop in parallel, but the preferred publication dependency is:

1. stabilize P1 architecture/migration method and evidence;
2. make P1 citable as manuscript or preprint when appropriate;
3. let P2 cite that execution architecture as established experimental infrastructure;
4. keep P2 focused on solver science rather than redescribing the migration method.

This ordering is a publication clarity preference, not a requirement to stop P2 experimentation while P1 is being prepared.

## Literature watch

Because both topics are active, maintain a periodic literature watch for:

- scientific-model legacy modernization;
- transactional or rollback-safe scientific simulation;
- hydrological component architectures;
- alternative Richards-equation solvers;
- dual-solver or adaptive-solver vadose-zone models;
- regime-dependent numerical model selection.

Any new paper that overlaps a primary novelty claim should trigger a review of the relevant research design before manuscript drafting.

## Status

Established: 2026-09-17.

This programme is documentation and research governance only. It does not change production code, physics, numerical semantics, qualification tolerances or existing canonical evidence.
