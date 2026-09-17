# PUB-ME literature cluster: transactional and speculative simulation

Status: **adversarial prior-art note**

Review date: 2026-09-18

Purpose: test whether `PUB-ME` can legitimately claim novelty for transactional execution, candidate/accepted state, rollback, retry or commit semantics.

## Finding

The generic transaction pattern is **not novel** in simulation.

Prior work includes explicit transactional architectures for simulation, speculative simulation with provisional state and rollback/commit, numerical time-stepping libraries with accepted/rejected stages, and co-simulation methods that save/restore state and repeat a communication interval.

Therefore `PUB-ME` must not claim to invent transactions, speculative execution, rollback, rejected timesteps, checkpoint/restore or accepted-state semantics in the abstract.

## Sources

### Hoverd and Sampson (2010)

**A Transactional Architecture for Simulation**. 15th IEEE International Conference on Engineering of Complex Computer Systems. DOI: 10.1109/ICECCS.2010.7.

Establishes:
- explicit transfer of database transaction concepts into simulation architecture;
- simulation updates can be treated transactionally;
- consistency/replication concepts can be adapted while maintaining simulation validity.

Does not establish in the reviewed material:
- a method for behavior-preserving replacement of a mature process-based environmental model;
- scientific trajectory equivalence to a legacy reference;
- numerical conservation/restart qualification;
- change-aware qualification-evidence continuity during multi-year migration.

Consequence:
- the word `transactional` cannot carry the novelty claim;
- any use of transaction language in `PUB-ME` must be framed as an adaptation of established computing/simulation ideas to a specific scientific-evolution problem.

### Reversible/speculative parallel discrete-event simulation literature

Example: reversible languages and incremental state saving in optimistic parallel discrete-event simulation (2020). This literature explicitly describes event executions as speculative/provisional, rollback to prior state on causality conflict, and eventual commit when rollback is no longer possible.

Establishes:
- speculative simulation state;
- rollback and re-execution;
- a distinction between provisional execution and committed history.

Does not establish:
- scientific equivalence during architectural migration of an existing deterministic process model;
- evidence-gated semantic successor/admission logic.

Consequence:
- even `provisional -> rollback -> commit` is not itself novel.

### Santini et al. (2015)

**Hardware-Transactional-Memory Based Speculative Parallel Discrete Event Simulation of Very Fine Grain Models**. IEEE HiPC. DOI: 10.1109/HiPC.2015.45.

Establishes:
- speculative updates to simulation state can be executed as transactions;
- state recoverability is a central execution concern.

Consequence:
- implementation-level transactional state recovery is prior art.

### Andelfinger and Uhrmacher (2024 publication record; article DOI 10.1177/00375497231158930)

**Synchronous speculative simulation of tightly coupled agents in continuous time on CPUs and GPUs**.

Establishes:
- projected states are either discarded/rolled back or committed as the next current state.

Consequence:
- explicit candidate/current state language exists in simulation research outside environmental modelling.

### FMI / co-simulation rollback literature

Braun and Fritzson (2022), **Numerically robust co-simulation using transmission line modeling and the Functional Mock-up Interface**, SIMULATION 98(11), DOI 10.1177/00375497221097128.

Related FMI step-revision work describes speculative execution of FMUs, restoration to the previous state, and subsequent advancement with the selected step.

Establishes:
- save/restore and rollback are standard capabilities considered in co-simulation;
- iterative and conservative coupling methods may require re-execution of a communication interval.

Consequence:
- rollback-safe coupling is not a new concept in isolation.

### PETSc TS

Current PETSc time-step adaptation explicitly distinguishes accepted and rejected stages/steps and repeats a rejected step with a modified timestep; failed nonlinear stages can cause rejection.

Establishes:
- accept/reject/retry semantics are mature numerical-library practice.

Consequence:
- `PUB-ME` cannot treat numerical retry or accepted timestep selection as an invention.

## Remaining possible distinction

After this cluster, the candidate `PUB-ME` distinction is narrower:

> not transactional simulation itself, but the use of an explicit scientific-state authority boundary as one part of an evidence-preserving method for replacing the architecture of an already established process model while continuously qualifying equivalence to a declared scientific reference.

To remain publishable, the paper must demonstrate that this combination solves a real scientific-software evolution problem that ordinary rollback/transaction frameworks do not solve.

In particular, it should empirically connect:

1. accepted versus speculative state;
2. scientific trajectory/balance/restart preservation;
3. bounded migration decisions;
4. evidence dependency and invalidation/replay;
5. later substitution/coupling without silently moving the reference denominator.

## Strong falsification condition

If subsequent literature review finds a mature scientific-simulation modernization method that already combines these five elements and demonstrates them longitudinally on a legacy model, `PUB-ME` must be narrowed substantially or cease to be protected as a standalone novelty paper.
