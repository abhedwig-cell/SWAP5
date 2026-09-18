# SWAP5 publication programme

## Purpose

This document governs the SWAP5 publication lines that share the codebase, qualification infrastructure and some scientific cases but must not silently share the same primary scientific result.

P1 and P2 are established research lines. PUB-GC, PUB-SG and PUB-RC are additional coupling-related candidate lines under active novelty review. Their separation is intentional to prevent duplicate publication, retrospective claim splitting and accidental reuse of one novelty claim in multiple manuscripts.

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

## Coupling-related candidate publication lines

### PUB-GC - COUPLE

Status: **HIGH-PRIORITY CENTRAL COUPLING MANUSCRIPT**.

Primary ownership:

- scientific correctness of SWAP5-MODFLOW6 coupling;
- fixed coupling-plane and hydraulic-head semantics;
- q_bot versus q_u;
- conservative whole-window exchange;
- component state ownership and accepted/trial/committed coupling semantics;
- coupling transaction, retry, rollback and publication;
- scalable SWAP5-MODFLOW6 coupling architecture.

PUB-GC owns the scientific interpretation and qualification of the F-GC30 response/storage quantity `u`. The existence of `u` or of a tangent contract is not by itself a PUB-RC result.

### PUB-SG - SCALE

Status: **active candidate line under separate literature review**.

Current research question:

> Under which combinations of heterogeneous atmospheric forcing, soil properties and groundwater dynamics does an equivalent unsaturated-zone column remain transferable when multiple land-surface units are coupled to groundwater at a coarser spatial scale?

Primary ownership:

- physical validity and failure of spatial aggregation;
- transferability of equivalent unsaturated-zone columns;
- consequences of heterogeneous forcing, soil properties and groundwater dynamics;
- prediction of aggregation error.

The technical ability to support N:1 coupling is infrastructure, not the intended novelty.

### PUB-RC - ACCELERATE

Status: **high-priority experiment within PUB-GC; independent-paper status conditional**.

Current research question:

> Under which hydrological and numerical conditions does explicitly provided finite-window response information reduce the total cost or enlarge the convergence domain of partitioned coupling beyond what can be achieved from black-box interface histories alone, while each component retains independent time integration?

Current disposition:

> Develop the response/acceleration study as a major experiment inside the central PUB-GC manuscript. Split it into a separate PUB-RC manuscript only if the novelty gates demonstrate a reproducible, generalizable information-value regime beyond state-of-the-art black-box multisecant coupling.

PUB-RC must not claim novelty from derivative-informed coupling, interface Jacobians, autonomous/multirate component integration, dynamic hydrological storage response, surrogate-assisted quasi-Newton coupling, or hydrological convergence-regime analysis by themselves.

Research design:

`PUB_RC_ACCELERATE_RESEARCH_DESIGN.md`

Prior-art register:

`PUB_RC_ACCELERATE_LITERATURE_REGISTER.md`

Broader coupling-method publishability review:

`PUB_COUPLING_BROADER_PUBLISHABILITY_REVIEW.md`

### Coupling-paper firewall

The three coupling-related lines answer different questions:

```text
PUB-GC / COUPLE
    Is the coupled hydrological system physically, numerically and transactionally correct?

PUB-SG / SCALE
    When is spatial aggregation of heterogeneous unsaturated-zone response physically transferable?

PUB-RC / ACCELERATE
    When does extra component-provided response information have net value over black-box learned interface information?
```

A result does not become a separate paper merely because it can be plotted under more than one of these headings.

## Publication firewall

The same code, test harness or reference dataset may support multiple publication lines. The same primary scientific inference may not.

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
| MODFLOW coupling architecture | possible architectural consequence only | outside current P2 scope | PUB-GC primary result candidate |
| F-GC30 q_bot/q_u/u scientific interpretation | infrastructure/context only | outside current P2 scope | PUB-GC primary result candidate; PUB-RC may use only as qualified input |
| finite-window supplied response versus learned black-box interface history | outside scope | outside scope | PUB-RC only if RC novelty gates pass |
| spatial aggregation / equivalent unsaturated-zone column transferability | outside scope | outside scope | PUB-SG primary result candidate |
| technical N:1 SWAP-to-groundwater mapping capability | architectural consequence only | outside scope | shared infrastructure; not PUB-SG novelty by itself |

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

### `PUB_GC_RESULT`

Evidence may support a primary result or conclusion in PUB-GC / COUPLE. Examples include qualified coupling quantities, conservative exchange semantics, coupling convergence correctness and the scientific SWAP5-MODFLOW6 interface contract.

### `PUB_SG_RESULT`

Evidence may support a primary result or conclusion in PUB-SG / SCALE. Examples include quantified aggregation error, transferability limits and mechanisms controlling the validity of equivalent unsaturated-zone columns.

### `PUB_RC_RESULT`

Evidence may support a primary result or conclusion in PUB-RC / ACCELERATE only after the RC novelty gates pass. Examples include a demonstrated net information-value regime for supplied finite-window response relative to a strong black-box multisecant comparator. F-GC30 response-coefficient mechanics alone do not qualify.

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
publication_class: PUB_P1_RESULT | PUB_P2_RESULT | PUB_GC_RESULT | PUB_SG_RESULT | PUB_RC_RESULT | PUB_SHARED_INFRASTRUCTURE | PUB_CONTEXT_ONLY | PUB_NOT_CURRENT
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
primary_paper: P1 | P2 | PUB-GC | PUB-SG | PUB-RC | NONE
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

Because all publication topics are active, maintain a periodic literature watch for:

- scientific-model legacy modernization;
- transactional or rollback-safe scientific simulation;
- hydrological component architectures;
- alternative Richards-equation solvers;
- dual-solver or adaptive-solver vadose-zone models;
- regime-dependent numerical model selection;
- partitioned and segregated multiphysics coupling;
- interface quasi-Newton, Anderson and IQN history-reuse methods;
- derivative/tangent-informed co-simulation and FMI developments;
- vadose-zone/groundwater and MODFLOW coupling architectures;
- hydrological convergence analysis;
- spatial aggregation and effective unsaturated-zone representations.

Any new paper that overlaps a primary novelty claim should trigger a review of the relevant research design before manuscript drafting.

## Status

Established: 2026-09-17. Expanded with coupling-related candidate lines PUB-GC, PUB-SG and PUB-RC on 2026-09-18.

PUB-RC is currently conditional, not an assumed standalone paper. Its default disposition is integration into PUB-GC unless the dedicated novelty gates pass.

This programme is documentation and research governance only. It does not change production code, physics, numerical semantics, qualification tolerances or existing canonical evidence.
