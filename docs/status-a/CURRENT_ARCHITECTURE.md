# SWAP5 Status-A current architecture

Date: 2026-09-16

This page describes the architecture that is current for the admitted Status-A baseline. It is deliberately narrower than older target-architecture documents. Target documents remain useful design history, but they do not establish that a future layer, API or execution mode is already admitted.

Current authority is anchored to canonical commit `992a5c657bfe10a10100f92e0cb77c4825ae65b6` and scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`.

## Architectural principle

SWAP5 makes the boundary between computation and accepted model state explicit. A numerical or physical process may calculate a tentative result without that result becoming authoritative. The transaction/runtime layer decides when candidate effects become committed and when they must be discarded or restored.

This is the main architectural distinction to keep in mind when comparing the admitted SWAP5 runtime with the historically more implicit execution/state relationships in SWAP 4.3.1. It does not by itself assert different scientific equations.

## Current layers and ownership boundaries

| Layer | Current responsibility | Does not own |
| --- | --- | --- |
| Legacy / reference | Reference behaviour, historical equations/contracts and preservation expectations used by admitted scientific capabilities. | Current runtime commit policy or current implementation status. |
| Process | Computes physical process contributions and bounded candidate results according to admitted scientific contracts. | Global trial acceptance, retry policy or rollback authority. |
| Solver | Computes a numerical candidate for the active trial under the applicable solver contract. | Whether that candidate becomes committed model state. |
| Runtime / transaction | Owns the attempt lifecycle and the transition between trial, acceptance, retry and rollback. | The scientific equation set merely because it controls execution. |
| Committed / persistent state | The authoritative accepted model state from which subsequent accepted execution proceeds. | Tentative failed/rejected trial effects. |
| Candidate / trial state | Tentative state associated with the current attempt until acceptance. | External authority before commit. |
| Scratch / workspace | Disposable numerical/process workspace used during calculation. | Persistent scientific state. |
| Persistence / restart | Captures and restores the admitted Restart v1 committed-state contract. | A claim that rejected candidate/scratch state is persistent authority. |
| MultiSWAP orchestration | Coordinates the admitted serialized MultiSWAP v1 execution over qualified real-physics paths. | Parallel/concurrent real-physics execution. |
| Coupling / adapter | Defines bounded internal/external coupling seams. Groundwater Coupling v1 obeys transactional accepted-state publication; the external gateway is the admitted structural boundary. | Arbitrary backend physics or a broad MODFLOW implementation. |
| Diagnostics | Observes and reports execution/scientific diagnostics used for qualification and operation. | State acceptance simply because a diagnostic is emitted. |
| Test / qualification infrastructure | Establishes scientific, numerical, architectural and preservation evidence outside the production semantics. | Production-state mutation. |

## State model

### Committed state

Committed state is the accepted authority. A successful trial does not become authoritative merely because a solver or process routine has produced values. Commit is the boundary at which the accepted candidate becomes the state used by subsequent execution and external publication.

### Candidate state

Candidate state belongs to a trial/attempt. It may contain physically meaningful tentative values, but until the attempt is accepted it must not be treated as the persistent model authority. A rejected attempt is therefore not a partially committed run.

### Scratch and workspace

Scratch/workspace supports calculation but carries no independent persistence contract. It may be allocated, reused or rebuilt within the admitted execution design as long as doing so does not change the scientific/state contract. Performance work such as F-PE11 must remain inside this boundary.

## Trial, accept, retry and rollback

The admitted transaction model separates these operations:

1. establish the trial from accepted authority;
2. execute the numerical/physical candidate work;
3. assess the attempt under the applicable solver/execution criteria;
4. accept and commit the candidate, or reject it;
5. on retry, restore/retain the accepted authority and start the permitted next attempt rather than carrying rejected candidate effects forward.

Rollback is therefore a state-authority operation, not a new physical process. The solver can report attempt status and candidate results, while execution policy decides what permitted action follows.

## Solver and execution-policy separation

A solver answers the bounded numerical problem for an attempt and exposes the information needed to assess it. Execution policy owns decisions such as accepting the full attempt, selecting an independently valid accepted result where the admitted policy allows that, or retrying under the bounded controller contract.

This separation prevents solver internals from implicitly becoming global commit policy and prevents retry mechanics from silently changing scientific state ownership.

## Mass accounting and publication

Physical process code remains responsible for the fluxes/storage terms defined by its scientific contract. Transactional acceptance determines which candidate state and associated accepted accounting become authoritative. Qualification/testbank evidence checks the relevant conservation and preservation contracts.

For admitted Groundwater Coupling v1, state publication is bounded by the accepted-state contract. Tentative/rejected coupling state is not the external authoritative publication simply because it was computed during an attempt.

## Restart v1

Restart v1 belongs to the persistence layer. Its purpose is to reconstruct the admitted committed execution state so continuation has the qualified semantics. The Status-A claim is bounded to the admitted Restart v1 contract and does not imply that every transient workspace or every possible future execution mode is serialised.

## Serialized MultiSWAP v1

MultiSWAP v1 is admitted as serialized orchestration of the qualified real-physics execution path. The orchestration layer coordinates multiple admitted column/execution contexts without changing the ownership rule that each accepted state is produced through the transaction boundary.

No current Status-A claim is made for parallel or concurrent real-physics MultiSWAP execution.

## Groundwater Coupling v1 and external gateway

Groundwater Coupling v1 is admitted as the bounded current groundwater capability chain, including the internal transient coupling contract and accepted-state publication/rollback semantics established by its canonical qualification and closure.

The external groundwater gateway v1 is a structural adapter boundary. It is the place through which a concrete external groundwater implementation can conform to SWAP5 ownership and transaction semantics. Status-A does not turn that boundary into a claim that a broad MODFLOW backend, arbitrary coupling schedule or future backend evolution is already admitted.

## Performance semantics and F-PE11

F-PE11 is constrained by the architecture rather than exempt from it. Call-local allocation/scaling changes or measurements may improve/characterize execution behaviour only if they preserve process results, state ownership, transaction semantics and applicable preservation tests.

The Status-A F-PE11 closure must not be paraphrased as a universal whole-model speedup or MultiSWAP speedup. It also does not admit automatic rebatching, execution-class switching, GPU work or new persistent per-column state.

## Authority boundaries

Architecture pages from earlier phases may describe desired generic kernels, APIs, adapters or migration endpoints. Use them as target/design history only. For what is actually admitted now, use this page together with [SWAP5 Status-A current status](CURRENT_STATUS.md) and [Theory, code and evidence traceability](TRACEABILITY.md).