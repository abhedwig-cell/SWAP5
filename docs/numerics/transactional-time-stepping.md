# Transactional time stepping and acceptance

## Scope and authority

SWAP5 separates **calculation of a candidate** from **acceptance of model state**. In the frozen Status-A production baseline, the primary owners of this separation are:

- `src/transaction/mod_transaction_reference.f90` — trial construction, rejection, retry, rollback and accepted transaction-state commit;
- `src/runtime/mod_canonical_interval_runtime.f90` — composition of accepted transactions across a requested canonical interval and publication of the externally committed interval state.

This page documents those frozen semantics. It does not introduce a new timestep controller, retry budget, retry scale, mass tolerance or temporal tolerance, and it does not change the scientific equations solved inside a trial.

The production-owner lineage is F-KT15, admitted through F-CI49 and reconciled after promotion by F-CI49P. The current Status-A traceability record carries that transaction architecture into the frozen baseline and its preservation suites.

## Two different commit boundaries

A useful reviewer distinction is that SWAP5 has two nested state-authority boundaries.

### 1. Transaction acceptance

A transaction covers one attempted subinterval. Candidate work may include a full-step trajectory, two half-step trajectories, or an admitted model-certificate route. None of those candidates is authoritative merely because the solver completed.

Only after the applicable solver, mass and temporal gates pass does the transaction core replace its transaction-level committed state with the accepted candidate.

### 2. Requested canonical-interval publication

`run_canonical_interval` does **not** expose every accepted internal transaction directly as the caller's externally committed state. It first clones the external committed state into a private `working` state. Accepted internal transactions advance that private state.

Only when the complete requested `[t0,t1]` interval has reached its endpoint does the runtime publish `working` as the externally committed state. In the frozen implementation this publication is the single external `move_alloc(working, committed)` at successful interval completion.

Therefore:

```text
trial candidate
    -> accepted transaction state
        -> private canonical-interval working state
            -> externally committed state only after full requested interval completion
```

This distinction is essential when interpreting rollback, retry, restart and external coupling behaviour.

## State categories

**Externally committed state** is the authoritative state visible across successful requested canonical intervals.

**Private canonical working state** contains accepted internal transaction progress while a requested canonical interval is still in progress. It is not externally published authority yet.

**Transaction checkpoint state** is a clone of the transaction's accepted origin from which bounded attempts are constructed.

**Candidate state** is the tentative physical endpoint of a trial route.

**Attempt context** is worker/job-local rollback context such as forcing/time/accounting cursors and trial-only bookkeeping. It is explicitly separate from persistent column state.

**Scratch/workspace** is disposable numerical/process storage with no persistence authority.

A rejected attempt must not leak candidate, attempt-context or scratch effects into later accepted state.

## Transaction lifecycle

At the start of `execute_reference_interval`, the transaction core validates the interval and caller-owned policy. It then clones the accepted transaction state into a checkpoint and captures the corresponding attempt context.

A bounded attempt follows this pattern:

1. restore the checkpoint context;
2. construct candidate state from the checkpoint;
3. execute the model/solver for that candidate route;
4. evaluate solver status;
5. construct and validate complete mass-accounting provenance;
6. evaluate the applicable temporal criterion;
7. either commit the accepted candidate or restore the checkpoint context and enter bounded retry handling.

Retry is therefore a state-authority operation around the scientific calculation, not an additional physical process.

## External full-versus-two-half route

For the admitted external full/half assessment route, the transaction core evaluates two candidate trajectories from the same accepted origin.

### Full candidate

The checkpoint context is restored, a `full_state` is cloned from the checkpoint, and the model advances that state over the active attempt interval. Solver failure rejects the attempt before the candidate can become authoritative.

The full candidate contributes an independent storage and mass-accounting assessment. It is not the state that is ultimately committed by this route.

### Two-half candidate

The checkpoint context is restored again. A separate `half_state` is cloned from the same checkpoint and advanced over two consecutive half intervals. The context after the first half is captured so the second half continues the accepted candidate trajectory rather than restarting from the original checkpoint.

The resulting two-half endpoint is compared with the independently computed full candidate through the admitted temporal-error operator.

### Acceptance gates

Before the two-half candidate can be accepted, the frozen transaction core requires all of the following within the active policy contract:

- the candidate solver work succeeds;
- required storage and external-flux accounting contributions are present;
- mass-accounting terms are finite and marked complete;
- both full and two-half mass residuals satisfy the caller-supplied mass gate;
- the temporal indicator satisfies the caller-supplied temporal gate.

Only then is the accepted half-step context restored and `half_state` moved into the transaction-level committed state. The result records `TX_ROUTE_TWO_HALF` and one transaction commit.

The full candidate remains assessment evidence; it is not silently substituted for the accepted two-half state.

## Model-certificate route

The frozen transaction core also supports the separately admitted model-certificate temporal route. That route constructs a candidate from the same transaction checkpoint discipline and requires:

- successful model/solver completion;
- complete and finite accepted mass accounting;
- mass residual inside the active policy gate;
- an available and valid temporal certificate satisfying the active temporal gate.

If the certificate is unavailable or invalid, the route does not fabricate temporal confidence. It rejects/retries according to the bounded policy. Only after all gates pass is the candidate context restored and the candidate state moved into transaction-level committed state, with route `TX_ROUTE_MODEL_CERTIFIED`.

This does **not** mean that every physical model supplies a temporal certificate, nor that a certificate is a general nonlinear true-error theorem.

## Rejection, rollback and retry

Solver rejection, mass rejection and temporal rejection are separate diagnostic classes, but they share the same state-authority rule: restore the checkpoint context before retry handling.

The frozen `reject_and_retry` operation:

- increments rollback count;
- fails with `TX_STATUS_RETRY_EXHAUSTED` when the caller-owned retry budget has been consumed;
- otherwise increments retry count and applies the caller-owned retry scaling to the next attempted duration.

F-DOC30 deliberately does not publish the source defaults as universal recommended settings. They are implementation-policy values, not scientific constants.

On retry exhaustion, the checkpoint context is restored and no rejected candidate becomes committed state.

## Mass accounting is an acceptance gate

Transaction acceptance is not based on solver convergence alone.

For the full/two-half route, both the independent full candidate and the prospective accepted two-half candidate must have complete, finite accounting and residuals inside the active mass gate. The accepted transaction result carries explicit start/end storage, total inflow, total outflow, residual, completeness and missing-contribution provenance.

At the requested canonical-interval level, accepted transaction mass terms are accumulated only from accepted transactions. After the complete requested interval succeeds, the runtime computes:

```text
storage_change = storage_end - storage_start
residual       = storage_change - (total_in - total_out)
```

Whole-interval mass completeness additionally requires finite terms, at least one accepted transaction, no missing-contribution flags and complete accepted transaction accounting.

A diagnostic result does not override an incomplete mass ledger.

## Canonical-interval orchestration

`run_canonical_interval` clones the caller's `committed` state to a private `working` state before any internal transaction is attempted. It then advances a cursor through one or more accepted internal transaction subintervals.

For each internal transaction:

1. the execution-policy selector may choose a target endpoint and may **tighten but not relax** the caller-owned maximum retry budget;
2. `execute_reference_interval` operates on the private `working` state;
3. diagnostics are accumulated regardless of acceptance outcome;
4. only an accepted transaction contributes accepted mass/interface metadata and advances the private cursor;
5. the accepted transaction must make finite forward progress within the selected target interval.

The runtime returns without external state publication when a transaction fails, when accepted progress is invalid, or when the allowed committed-substep count is exhausted.

Only when the private cursor reaches the requested interval endpoint does the runtime:

- replace external `committed` with `working`;
- mark the requested interval completed;
- record exactly one external commit;
- finalize whole-interval mass accounting;
- publish accepted bottom-interface metadata and eligible accepted sensitivity/directional metadata.

This is why an accepted internal substep and a successfully published requested canonical interval are not synonyms.

## Failure and publication semantics

The external publication rule can be summarized as follows:

| Situation | Transaction candidate | Private working state | External committed state |
| --- | --- | --- | --- |
| Solver/mass/temporal rejection with retry available | discarded | remains at last accepted internal state | unchanged |
| Retry exhausted | discarded | not externally published | unchanged |
| Accepted internal transaction before requested interval end | accepted into transaction/private working state | advances | unchanged |
| Invalid/no-progress/substep-limit canonical return | no further accepted publication | may contain private accepted progress | unchanged |
| Complete requested canonical interval | accepted route only | complete | replaced once by completed working state |

This table describes state authority. It does not imply that diagnostics are erased: rejection/retry/rollback counters remain observable precisely so qualification and operation can distinguish failed candidate work from accepted execution.

## Relationship to the Richards solver

The Richards solver answers the numerical problem for an active trial and exposes solver status and accepted diagnostic metadata. Solver convergence is therefore necessary where that route requires it, but it is **not sufficient for transaction acceptance**.

The transaction layer still owns mass and temporal acceptance, retry and state commit. Conversely, the transaction layer does not redefine the Richards equation, constitutive hydraulics, residual or Jacobian simply because it controls whether a candidate is accepted.

See [Richards reference solver](richards-solver.md) for the frozen nonlinear solve and linear-system details.

## Restart, MultiSWAP and coupling boundaries

[Restart v1](../capabilities/restart-v1.md) reconstructs the admitted committed execution state. It does not turn arbitrary rejected candidates or scratch into persistence authority.

[Serialized MultiSWAP v1](../capabilities/multiswap-v1.md) coordinates multiple qualified column contexts without weakening the committed/candidate boundary. Its frozen Status-A claim remains serialized; this page does not create a parallel real-physics execution claim.

[Groundwater Coupling v1](../science/groundwater-coupling.md) obeys accepted-state publication and adds capability-specific coupling contracts. Its staged interface mass-ledger semantics must not be generalized into the generic transaction core unless separately admitted.

## Temporal-certificate lineage and claim ceiling

Historical F-DOC13 records a restricted time-reference indicator construction. Its exact theorem applies to a constant linear dissipative semi-discrete backward-Euler problem. Later qualification demonstrated bounded transfer/consistency behaviour for the stated nonlinear candidate matrix, but **did not promote the indicator to a general nonlinear true-error bound**.

The normalized historical form is schematically:

```text
C_h = B_inf / H_budget
```

with an explicit finite positive `H_budget` where that capability is used. There is no universal application budget implied by this documentation.

The transaction-level rule is narrower and stronger: optional temporal evidence cannot override a hard mass failure, and missing prerequisites must fail closed rather than fabricate acceptance evidence.

## Reviewer invariants

For the frozen Status-A transaction surface, a reviewer should expect:

- rejected trials do not mutate accepted transaction state;
- rejected attempt context is restored before bounded retry;
- solver success alone does not imply acceptance;
- required mass accounting is explicit and hard-gated;
- temporal acceptance follows only an admitted temporal source;
- an accepted internal transaction advances only the private canonical working state until the requested interval is complete;
- failed/no-progress/substep-limit requested intervals do not partially replace external committed state;
- successful requested-interval publication performs one external commit;
- process/solver code does not silently become global retry or commit policy;
- diagnostics may report rejected work but do not themselves confer state authority;
- restart reconstructs the admitted committed-state contract, not rejected/scratch state;
- performance or orchestration work may not add hidden persistent aliases or weaken transaction semantics.

See [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md), [Theory, code and evidence traceability](../status-a/TRACEABILITY.md) and [Core invariants](../architecture/invariants.md) for the surrounding architecture and evidence boundaries.
