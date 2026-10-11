# PUB-ME D1 execution checkpoint

Status: **EXECUTION_DESIGN_FROZEN_BEFORE_D1_PROBE**

Publication owner: `PUB-ME`

Experiment family: `D1 — rejected candidate mutates committed physical state`

## Immutable design authority

The scientific design is not owned by this execution branch.

- preregistration branch: `work/pub-me-literature-pass2`
- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- design status: `PREREGISTERED_DESIGN_BEFORE_EXECUTION`

No D1 outcome may change the frozen B0/B1/B2 definitions, D1 semantics, interpretation classes or publication falsification rule.

## Execution authority

- execution base: `integration/f-ci-canonical@d0a41c39d7ff95db99bcf8360ac9b474fdf164d7`
- clean physical control: current-canonical `tests/publication/test_pub_p1e02_postsolver_rollback.f90`
- clean-control provenance: historical PUB-P1E02 / PR #185, replayed from current canonical for this workunit

## D1 defect semantics

D1 requires a real physical trial beginning from accepted state `S_n`, followed by rejection after physical work, where candidate execution has nevertheless changed committed physical state.

The preregistered design permits `STRUCTURAL_PREVENTION` when the admitted public interface makes that invalid operation unconstructable. Structural prevention must be demonstrated through executable/API probes, not inferred only from documentation.

## Reconciled implementation fact before execution

At the execution base:

- `kernel_committed_state_t%physical_state` is private;
- `kernel_advance_interval` receives `committed_state` as `intent(in)`;
- candidate execution is seeded by `clone` into a separate allocatable `working` state;
- the physical model receives `working`, not the committed carrier;
- publication to committed state occurs only in `kernel_commit_candidate` after origin/revision/time checks.

Therefore a write-through mutant cannot be injected through the admitted API without either breaking encapsulation or modifying production source. This workunit will not weaken production encapsulation merely to manufacture a fault.

## Frozen D1 probes

### P0 — clean post-solver rejection control

Replay the current P1E02 physical route. Required observations:

- real Reference physical execution occurred before rejection;
- candidate was not committed;
- accepted state/revision/time remain unchanged;
- accepted mass ledger remains unchanged.

This establishes the matched clean execution only. Its direct immutability assertion belongs to B2 and must not be mislabeled as B1.

### P1 — public-API compile-negative write-through probe

Compile a qualification-only program that attempts to obtain mutable access to `kernel_committed_state_t%physical_state` through the public type and write through it during a hypothetical candidate path.

Expected result for `STRUCTURAL_PREVENTION`:

- compilation is rejected because the physical component is private / inaccessible;
- no alternate public mutable reference to committed physical state exists on this route.

A compile rejection counts only because the preregistration explicitly permits structural prevention when the invalid operation is unrepresentable through the admitted interface.

### P2 — runtime clone-isolation probe

Through public APIs only:

1. initialize committed physical state;
2. obtain a public snapshot / candidate-working clone;
3. mutate the returned clone in a qualification-only context;
4. re-snapshot committed state;
5. prove the committed physical state, revision and time are unchanged.

This proves that publicly observable state extraction does not return an alias to authoritative storage.

## Comparator scoring

- B0: successful-run/reference endpoint observations only.
- B1: strong conventional scientific-software qualification, excluding direct candidate-to-accepted authority assertions.
- B2: B1 plus direct structural/transition-authority checks.

For D1, `STRUCTURAL_PREVENTION` is assigned only if P1 and P2 both support the public-interface barrier and P0 confirms the matched physical rejection route remains clean.

This workunit does not predeclare whether B1 would detect a hypothetical implementation that removed the barrier. That requires a separate executable mutant only if it can be constructed without changing the production authority being evaluated.

## Hard exclusions

- no `src/**` mutation;
- no `reference/**` mutation;
- no relaxation of access control;
- no test-only backdoor added to production types;
- no mutant admitted or merged as production behavior;
- no D2-D6 execution in this workunit;
- no claim that private state or cloning is itself novel;
- no claim that D1 alone supports the standalone PUB-ME paper.

## Next permitted action

Implement P0-P2 as qualification-only tests/runners, bind their source dependencies to this execution base, run under at least O0/O2 where meaningful, and classify D1 strictly according to the preregistered interpretation categories.