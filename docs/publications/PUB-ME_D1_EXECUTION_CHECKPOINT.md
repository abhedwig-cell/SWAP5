# PUB-ME D1 execution checkpoint

Status: **D1_EXECUTION_NOT_YET_STARTED__DESIGN_FROZEN**

Checkpoint date: 2026-09-18

## Authority

- publication PR: #199
- publication branch: `work/pub-me-literature-pass2`
- publication head before this checkpoint: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- stacked base: `work/pub-gc-scientific-contract@2d0a9ea26dbb6048e60e67dcf6882a1b03664d61`

## Frozen design already available

- `PUB-ME_D1_D6_PREREGISTERED_EXPERIMENT_MATRIX.md`
- primary comparison: strong conventional scientific-software baseline B1 versus B1 + explicit transition-authority oracles B2
- D1 defect family: rejected candidate mutates committed physical state
- required rejection point: after real physical solver execution
- production/reference physics must not be modified to create the fault
- fault injection must remain qualification-only and must never become production authority

## Execution objective

Build the smallest reproducible D1 prospective experiment around an already-qualified post-solver rejection route.

The experiment must provide:

1. matched clean control;
2. test-only faulty route that leaks one candidate-state mutation into committed state before a later rejection;
3. identical physical initial state, forcing, solver route and rejection condition between control and mutant except for the injected leak;
4. B1 observation set recorded without consulting B2-only transition-authority assertions;
5. B2 direct committed-state immutability oracle;
6. downstream continuation check only after the immediate detection comparison has been frozen.

## Bounded execution plan

### D1-A RECONCILE
Identify the currently admitted post-solver rejection test/harness and exact production dependencies. Do not recover the whole repository.

### D1-B DESIGN BINDING
Freeze the exact clean fixture, mutation location, observation points and B1/B2 oracle partition before compiling the mutant.

### D1-C IMPLEMENT
Add qualification-only test/harness code and a dedicated workflow. No `src/**` or `reference/**` mutation is permitted unless a separate scientific decision explicitly reopens scope.

### D1-D QUALIFY
Run matched control and mutant under O0/O2. Persist raw markers and classify detection as:
- NO_INCREMENTAL_VALUE
- EARLIER_DETECTION
- UNIQUE_DETECTION
- STRUCTURAL_PREVENTION
- INVALID_EXPERIMENT

### D1-E CLOSE
Freeze result and nonclaims before any D2 work begins.

## Timeout recovery rule

After every completed substage above, update this checkpoint before starting the next tool-heavy step. A timeout must resume from the latest recorded substage and only reconcile relevant delta.

## Current next permitted action

Search only for the admitted post-solver rejection route and its exact test/runner dependencies, then update this checkpoint with the chosen fixture.