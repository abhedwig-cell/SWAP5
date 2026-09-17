# Paper 1 research design

## Working title

Evidence-preserving modernization of time-stepped scientific models: transactional execution and qualification-gated migration in SWAP

## Scope

This paper is about controlled scientific software evolution, not about new SWAP process physics and not about a new numerical soil-water solver.

The scientific unit of analysis is an architectural migration step in a mature time-stepped environmental model. The paper asks whether substantial software restructuring can be performed while the accepted scientific behaviour remains controlled, observable and auditable throughout the migration.

## Primary research question

How can a mature time-stepped scientific model be structurally transformed while preserving its established scientific behaviour and maintaining auditable evidence of equivalence throughout the migration?

## Primary novelty claim

The intended contribution is not legacy-code rewriting, modularization, solver abstraction, automated testing or rollback in isolation. Each of those has substantial prior art.

The candidate contribution is the combination of:

1. an executable scientific reference path that remains available during migration;
2. explicit ownership of authoritative physical state, forcing, numerical configuration, results and numerical scratch;
3. speculative interval execution in which trial state is not authoritative physical state;
4. explicit accept, retry, reject and single-commit semantics;
5. scientific invariants such as conservation and behaviour preservation that remain independent of software layout;
6. qualification gates that must be satisfied before an architectural successor is admitted;
7. retention of the old path until the replacement path has passed its stated evidence gate.

The paper must demonstrate that this combination is a usable migration method, not only describe it as an architecture preference.

## Literature boundary

The paper must explicitly position itself against at least the following bodies of work:

- Nyenah et al. (2025), *The process and value of reprogramming a legacy global hydrological model*, Geoscientific Model Development, https://doi.org/10.5194/gmd-18-5635-2025. This is the closest precedent for sustainable reprogramming of a legacy hydrological model while preserving model output.
- Clark et al. (2015), *A unified approach for process-based hydrologic modeling: 1. Modeling concept*, Water Resources Research, https://doi.org/10.1002/2015WR017198, plus the companion implementation paper https://doi.org/10.1002/2015WR017200. SUMMA establishes that systematic separation of model alternatives, process representations and numerical choices is not new.
- General research-software and numerical-framework literature on rollback, adaptive timestepping, model-component interfaces and behaviour-preserving refactoring. These are prior-art ingredients and must not be claimed as individually novel.

The paper is viable only if it remains more specific than "modern software engineering applied to SWAP".

## Hypotheses

### H1 - behavioural preservation under gated migration

A mature time-stepped scientific model can undergo substantial architectural restructuring without material change to its qualified scientific behaviour when each migration slice is evaluated against an executable reference and explicit scientific acceptance criteria.

### H2 - authoritative-state separation

Explicit separation of committed physical state from trial state makes failure, retry and rollback paths scientifically testable and prevents rejected numerical trajectories from becoming hidden physical history.

### H3 - separability of architecture and numerical implementation

When physical state, forcing, numerical policy, solver scratch and process contracts have explicit ownership, selected numerical implementations can change without requiring reimplementation of the surrounding process physics.

## What the paper must not claim

Do not claim that:

- SWAP5 introduces rollback as a new computational concept;
- modular scientific software is new;
- replacing global variables with typed data is itself a scientific contribution;
- behaviour-preserving refactoring is new;
- a new version number makes SWAP a new scientific model;
- SWAP5 is scientifically superior merely because its source structure is cleaner;
- RossFast accuracy, speed or admissibility is a result of this paper.

## Study design

The empirical study is a longitudinal case study of the migration from the qualified SWAP 4.3.1 reference behaviour to the SWAP5 architecture.

The SWAP-specific migration sequence is used as evidence, but the paper should abstract it into a general method. A provisional generic sequence is:

```text
reference shield
    -> scientific invariants
    -> explicit data ownership
    -> transactional execution
    -> component and solver boundaries
    -> qualification
    -> admission
    -> legacy retirement only after evidence
```

The current repository migration slices provide the concrete case-study trace:

- M0 Reference shield
- M1 Typed external boundary
- M2 Data ownership split
- M3 Transactional interval execution
- M4 Soil-water solver boundary
- M5 Process-contract extraction
- M6 Coupling kernel contract
- M7 MultiSWAP runtime and scalable storage
- M8 Legacy retirement

These names are implementation history. The manuscript should extract the transferable method rather than present M0-M8 as universal terminology.

## Required evidence

### Behaviour preservation

For a representative qualification suite, compare the qualified reference and migrated execution paths at more than final output-file level.

Required classes of evidence:

- state trajectories;
- integrated top and bottom water fluxes;
- relevant internal continuation state;
- water-balance closure;
- process-relevant outputs;
- solver route and retry diagnostics where relevant.

Candidate summary measures include:

- maximum or distributional state deviation over time;
- cumulative flux deviation;
- final and cumulative mass-balance residual;
- route-specific agreement after retry or fallback.

Tolerances must be declared before interpreting the result.

### Transactional fault injection

Dedicated tests should demonstrate at least:

1. rejected trial leaves committed physical state unchanged;
2. accepted endpoint is committed exactly once;
3. integrated fluxes are not double counted across retry paths;
4. rerunning from the same committed state is deterministic or tolerance-consistent;
5. changing only warm-start numerics does not materially change the accepted physical solution;
6. non-midnight and non-day intervals are supported without introducing different physics;
7. water balance closes across normal and retry paths.

### Architectural consequence

At least one substantial successor capability must demonstrate that the new boundaries have practical scientific value. Candidate examples are:

- replacement of the reference soil-water solver behind the same transaction and state lifecycle;
- rollback-safe coupling over a generic interval;
- scaled execution without duplicating the scientific kernel.

For this paper, such a capability is evidence of architectural separability only. Its own scientific performance belongs elsewhere.

## Candidate figures

### Figure 1 - legacy versus target responsibility structure

Show how mixed legacy responsibilities are separated into external adapters, physical state, forcing, runtime policy, kernel/process components, numerical solver and diagnostics.

### Figure 2 - transactional interval semantics

```text
committed state S(t0)
        |
     checkpoint
        |
       trial
        |
 provisional result
     /         \
 reject       accept
   |             |
 retry         commit
   |             |
 S(t0)          S(t1)
```

The figure must distinguish authoritative physical state from numerical scratch and warm-start information.

### Figure 3 - qualification-gated migration method

Show migration slices as evidence gates, not merely software milestones.

### Figure 4 - behavioural preservation through migration

Candidate design: per migration slice, show maximum state deviation, integrated-flux deviation and water-balance residual relative to the qualified reference.

## Candidate tables

### Table 1 - prior art versus claimed contribution

Columns: topic, existing literature, SWAP5 usage, not claimed, candidate contribution.

### Table 2 - migration evidence matrix

Columns: migration step, responsibility changed, protected scientific invariant, qualification cases, tolerance, result, remaining limitation.

### Table 3 - fault-injection evidence

Columns: injected failure or alternate route, expected state semantics, observed result, conservation check, qualification verdict.

## Publication threshold

This paper is not manuscript-ready until all three conditions hold:

1. representative legacy trajectories remain qualified after substantial architectural migration;
2. transactional semantics are proven by directed failure and retry tests, not only normal runs;
3. at least one later capability uses the new boundaries without requiring a second application lifecycle or duplication of the process physics.

## Primary journal route

Primary target: *Environmental Modelling & Software*, provided the manuscript makes the method transferable beyond SWAP and includes substantial quantitative evaluation.

Fallback route: *Geoscientific Model Development* if the final contribution remains more tightly coupled to the SWAP5 implementation history.

## Explicit publication firewall

Paper 1 may mention RossFast only as an architectural probe. It must not contain the main RossFast versus Reference accuracy analysis, speed-up curves, hydrological regime maps, solver-admissibility boundaries or scientific solver-selection conclusions.

Those are reserved for Paper 2.

## Current readiness

Status: research design established, evidence accumulation active.

Existing repository architecture already supports the central concepts of explicit ownership, transactional interval execution, a retained reference mode and a common soil-water solver boundary. The remaining publication task is to organize and, where necessary, extend the evidence so that the claims above are tested rather than merely described.
