# F-GC43 — Production SWAP transaction participant

## Purpose

F-GC43 binds the real SWAP kernel transaction machinery to the coupling-service participant role required by F-GC39 and F-GC41.

The participant is deliberately thin. It does not introduce a second SWAP state machine and it does not own predictor/corrector policy.

## Production binding

The admitted ownership chain is:

```text
kernel_committed_state_t
    |
    +-- capture_checkpoint() --------------------+
    |                                           |
    |                                  immutable coupling origin
    |                                           |
kernel_executor_t.advance_interval(..., checkpoint=origin)
    |
    +-- kernel_candidate_state_t
            |
            +-- rollback_candidate()   non-final corrector
            |
            +-- publication_ready()    non-mutating provenance/window preflight
            |
            +-- commit_candidate()     sole SWAP committed-state mutation
```

A coupling window captures one kernel checkpoint. Every SWAP corrector trial in that window must originate from that checkpoint. A live candidate must be explicitly discarded before another corrector is attempted.

## Publication rule

`publication_ready()` duplicates the externally observable commit predicates relevant to coupling:

- committed state remains ready;
- lineage remains equal to the captured origin lineage;
- committed revision remains equal to the captured origin revision;
- committed time remains the captured/window start time;
- candidate lineage/revision matches the captured origin;
- candidate interval exactly matches the coupling window;
- the kernel result completed the exact requested window.

The preflight is non-mutating.

Actual SWAP publication still calls `kernel_executor_t%commit_candidate`. F-GC43 never writes committed physical state, revision or committed time directly.

If kernel commit were to reject after a successful F-GC41 publication preflight, that is state-drift/programming failure after the publication point, not a rollback-safe scientific rejection.

## Qualification envelope

The owner fixture uses the real kernel checkpoint/candidate/commit implementation with a deterministic physical-model fixture. It proves:

1. capture uses a real `kernel_checkpoint_t`;
2. repeated correctors are computed from the same accepted origin;
3. corrector trials do not mutate committed SWAP state;
4. publication preflight is non-mutating;
5. only kernel commit advances revision/time/state;
6. stale origin is rejected before participant publication;
7. O0 and O2 produce identical stable qualification markers.

## Evidence boundary

F-GC43 qualifies the production SWAP transaction participant binding. It does not yet qualify a complete real SWAP application case coupled to live MODFLOW6. That remains the next bounded end-to-end application capability.

No groundwater physics, tangent policy, N:1 scaling, Ribasim or irrigation semantics change here.
