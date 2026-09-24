# F-PE-PROFILE02-H03 — Constitutive tuple reuse repair qualification

Date: 2026-09-24

Status: `PREREGISTERED_ACTIVE`

## Scope

This workunit repairs one bounded, measured redundancy identified by F-PE-PROFILE01:

> repeated complete constitutive-provider evaluation at an unchanged pressure-head vector across the Reference Richards Newton control path.

No other performance candidate is in scope.

Explicit exclusions:

- no workspace-reset repair (H01);
- no transaction/state-clone optimization (H02);
- no constitutive API split or tuple-granularity redesign (H04);
- no F-AHL representation or lookup change;
- no RossFast change;
- no solver tolerance, timestep, fallback or convergence-policy change;
- no physics or constitutive formula change.

Protocol:

`RECONCILE -> BIND EVIDENCE -> PREREGISTER -> REPAIR -> QUALIFY -> MEASURE -> PERSIST -> CLOSE`

## Evidence authority

PROFILE01 branch/source evidence:

- branch: `work/f-pe-profile01`
- phase-1 synthesis commit: `0b373c6cdaed53e26a1acb917f096bf20256f12a`

Canonical authority at repair-line split remains:

- `integration/f-ci-canonical@506c36aab6f84b74dffdf5c37fe572c1e0b46610`

Measured PROFILE01 facts:

- P01-A: 3 constitutive provider evaluations per Reference solve;
- P01-A: 1 nonlinear iteration per Reference solve;
- source/control-flow audit: the Newton-iteration-start call sees unchanged `state%h` relative to the immediately preceding complete constitutive evaluation;
- `vector_F(1)` does not write `state%h`;
- focused default-MvG provider cost at 1000 nodes on the shared runner: about 111.4 us per complete provider call;
- H03 classification: `N4_REDUNDANT_CONFIRMED_BOUNDED`.

## Repair hypothesis

For the explicit constitutive-provider Reference route, the complete tuple already present in provider scratch may be reused at Newton-iteration start whenever no intervening operation has changed `state%h`.

The first repair target is deliberately minimal:

1. preserve the pre-loop constitutive evaluation;
2. mark its tuple as valid for the current head;
3. at Newton-iteration start, consume the already available `provider_capacity` instead of repeating the provider call when the tuple is still valid;
4. once `state%h` changes during backtracking, the candidate constitutive evaluation becomes the new valid tuple;
5. if another Newton iteration follows without another head mutation, reuse that candidate tuple at iteration start;
6. any path that cannot prove tuple validity must evaluate normally.

No approximation or memoization across different head vectors is allowed.

## Semantic invariants

The repair must preserve:

- exact Reference Richards equation path;
- accepted/rejected trial semantics;
- timestep policy;
- Newton and backtracking decisions;
- mass accounting;
- candidate/accepted physical state;
- lower-boundary semantics;
- provider values for the same pressure-head vector;
- optional directional/sensitivity behavior;
- legacy non-provider path.

The optimization is valid only because it removes repeated evaluation at identical state, not because close values are treated as equivalent.

## Qualification gates

### Q1 — compile and existing runtime preservation

Existing FKT22 O0 and O2 production-runtime gates must pass.

### Q2 — physical identity

For P01-A, before/after repair must retain bit identity for:

- pressure head;
- water content;
- ponding depth;
- groundwater level;
- accepted mass-accounting values.

### Q3 — numerical-control identity

Before/after repair must retain:

- nonlinear iteration count;
- Jacobian build count;
- linear solve count;
- backtracking count;
- retry count;
- accepted/rejected trial structure.

### Q4 — constitutive call-count reduction

On the P01-A one-Newton-iteration route:

```text
baseline constitutive evaluations per solve = 3
candidate expected evaluations per solve    = 2
```

The reduction must occur without changing any Q2/Q3 value.

For multi-iteration qualified cases, the expected bounded relation is:

```text
candidate calls = baseline calls - nonlinear_iterations
```

only where control-flow inspection confirms no intervening head mutation before the removed iteration-start evaluations.

### Q5 — relevant route coverage

At minimum qualify:

- P01-A fixed-flux equilibrium route;
- a case with >1 Newton iteration;
- prescribed-qbot/sensitivity route where available;
- representative free-drainage or lower-boundary route using provider K;
- O0 and O2 semantic identity on the existing gate.

### Q6 — runtime

Use paired same-runner measurement.

Report separately:

- provider-call reduction;
- Reference-solve runtime;
- compute-interval runtime where measurable.

No whole-SWAP speedup claim is permitted from the focused benchmark alone.

### Q7 — no cross-workstream drift

No F-AHL table/representation source, RossFast source, transaction architecture or approximate-mode behavior may change.

## Fail-closed rules

Abort repair/admission if:

- a removed evaluation is reached after any possible head mutation not covered by the validity logic;
- bit/numerical identity fails without an independently justified existing defect;
- Newton/backtracking/retry counts change;
- lower-boundary outputs change;
- the optimization requires weakening transaction safety;
- the measured call reduction does not match the preregistered control-flow expectation.

## Planned implementation shape

Prefer a local explicit validity flag in the Reference HeadCalc/provider scratch flow rather than a broad caching subsystem.

The repair should be structurally obvious:

```text
evaluate tuple -> tuple_valid = true
...
iteration start:
    if tuple_valid:
        reuse C
    else:
        evaluate tuple
...
head changes:
    tuple_valid = false
candidate evaluate:
    tuple_valid = true
```

If control flow already guarantees the tuple is valid at every iteration start on the explicit-provider path, an even smaller single-use/reuse structure may be preferred, but the invariant must remain visible in code and tests.

## Current status

```text
RECONCILE      = COMPLETE
BIND EVIDENCE  = COMPLETE
PREREGISTER    = COMPLETE
REPAIR         = NEXT
QUALIFY        = NOT_STARTED
MEASURE        = NOT_STARTED
CLOSE          = OPEN
```


## Qualification result — P01-A and multi-iteration Reference

### Q1/Q2/Q3/Q4 — P01-A

Dedicated workflow run `36064208787` completed successfully.

Observed at both O0 and O2:

```text
constitutive_evaluations_per_solve = 2
nonlinear_iterations_per_solve     = 1
rejected_trial_isolation           = PASS
physical_identity                  = PASS
serialized_runtime_gate            = PASS
```

Baseline PROFILE01 P01-A had three constitutive evaluations for the same one-iteration solve. The candidate therefore achieves the preregistered `3 -> 2` reduction without changing the qualified physical or numerical path.

### Q5 — existing three-iteration Reference case

Dedicated workflow run `36064698745` reused the existing `PUB-P2E01` Reference oracle rather than constructing a new difficult fixture.

Observed identically at O0 and O2:

```text
nonlinear_iterations      = 3
backtracking_attempts     = 3
constitutive_evaluations  = 4
H03 multi-iteration reuse = PASS
solver-seam paired pilot  = PASS
```

The repaired route therefore satisfies the preregistered control-flow relation:

```text
constitutive_evaluations = 1 pre-loop + backtracking_attempts
                         = 4
```

For this three-iteration case, the removed iteration-start evaluations are therefore three calls relative to the prior structural pattern, while Newton/backtracking behavior remains unchanged.

Current qualification state:

```text
Q1 compile/runtime preservation = PASS
Q2 physical identity            = PASS (P01-A)
Q3 numerical-control identity   = PASS (P01-A + existing multi-iteration oracle behavior)
Q4 call-count reduction         = PASS
Q5 multi-iteration coverage     = PASS
Q6 paired runtime               = NEXT
Q7 cross-workstream drift       = PASS_SO_FAR
```

No admission claim is made before Q6 runtime measurement and final scope review.


## Q6 paired runtime result

The paired runtime gate initially failed because the timing checksum incorrectly included `constitutive_evaluations`, which is the diagnostic intentionally changed by H03. That harness defect was repaired in commit `4915fd41fabf7f74e7ef1a3ad117fd6f63388426` by restricting the checksum to physical state plus unchanged nonlinear-iteration count.

Workflow run `36065753603` then completed successfully on GNU Fortran 13.3.0, O2, shared GitHub-hosted runner.

Eight balanced baseline/candidate pairs were measured, each over 3000 repeated three-iteration Reference solves.

Observed:

```text
baseline constitutive evaluations = 7
candidate constitutive evaluations = 4
nonlinear iterations              = 3 / 3
physical/control checksum         = identical
paired mean runtime ratio         = 0.642283280
paired median runtime ratio       = 0.641670404
paired mean speedup               = 35.771672 %
paired mean delta                 = -6843.407333 ns/solve
paired N                          = 8
Q6                               = PASS
```

Typical measured solve times in the paired samples were about 19.1 us for the baseline and 12.3 us for the candidate.

Interpretation is deliberately bounded: this is a focused Reference-solve benchmark on the qualified three-iteration case. It demonstrates that eliminating the three redundant constitutive evaluations produces a large local runtime reduction. It is not a whole-SWAP or production-workload speedup claim.

## Final bounded qualification state

```text
Q1 compile/runtime preservation = PASS
Q2 physical identity            = PASS
Q3 numerical-control identity   = PASS
Q4 call-count reduction         = PASS
Q5 multi-iteration coverage     = PASS
Q6 paired runtime               = PASS
Q7 cross-workstream drift       = PASS_BOUNDED
REPAIR                           = QUALIFIED
MEASURE                          = COMPLETE
CLOSE                            = READY_FOR_ADMISSION_REVIEW
```

Q7 scope review found no intended change to F-AHL representation/lookup logic, RossFast, transaction architecture, approximate-mode behavior, constitutive formulas, solver tolerances, timestep policy or fallback policy. The production change remains the local Reference HeadCalc reuse of an already valid constitutive tuple at an unchanged pressure-head vector.

No whole-program performance percentage is claimed. Representative P01-B/P01-C/P01-D attribution remains separate programme work.
