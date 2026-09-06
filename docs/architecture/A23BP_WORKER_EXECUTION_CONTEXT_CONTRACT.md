# A23BP worker execution context contract

## Scope

A23BP moves the first substantial Richards-solver numerical workspace from procedure/global lifetime to an explicit per-worker execution context while retaining exact B1.6 Hupsel physics as the serialized reference backend.

## Worker-owned data

For an active column with N nodes, the worker owns active-sized HeadCalc scratch: lower/main/upper Jacobian diagonals, Newton correction, residual, sink/source vectors, conductivity derivative, previous-head vector, flux/gradient vectors, convergence flags, solver warning/history and operation diagnostics.

For Hupsel N=34 the measured scratch payload is 3292 bytes per worker. This is not column state. Eight workers require 26,336 bytes of this payload; storing the same payload on 100,000 columns would incorrectly cost 329,200,000 bytes.

## Diagnostics

The worker records direct HeadCalc calls, Newton iterations, Jacobian builds, linear solves, backtracking attempts, alternative-solver calls and internal timestep retries. The generic transaction result distinguishes total reference-evaluation cost from accepted-route cost.

The Hupsel always-sampled reference transaction records 162 HeadCalc calls, 956 Newton iterations/Jacobian builds/linear solves, 1350 backtracking attempts and 20 internal retries in total. The accepted two-half route records exactly half those HeadCalc/Newton/Jacobian/linear/backtracking counts and 10 internal retries.

## Transaction and physics boundary

A23BL remains transaction owner. A23BO column state remains the physical/forcing/process/numerical continuation contract. A23BP worker scratch is neither committed nor checkpointed as physical state. Rejected trials discard column trial state; worker scratch may be overwritten freely.

## Legacy boundary

The B1.6 physical backend still contains many module-global physical/process variables and is therefore invoked serially in the physical gate. A23BP does not claim full B1.6 thread safety. Parallel testing is limited to independent worker-context ownership itself.

## Jacobian preservation

The normalized `jacobian_F()` block after removing only worker-ownership qualifiers is equivalent at normalized-token level to B1.6. Original and A23BP normalized SHA-256 are both `f522380f8340bb6915196259af191bebccd2d4feabbd7fa71a5a793e20af305e`. No Jacobian formula or solver policy is changed.

## Ownership rule

The worker context may contain numerical scratch, solver history needed only while executing work, and cost diagnostics. It must not become an owner of immutable soil/crop parameters or committed physical column state. Column checkpoint/rollback semantics remain independent of worker reuse.
