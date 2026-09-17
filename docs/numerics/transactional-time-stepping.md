# Transactional time stepping and acceptance

## Why SWAP5 separates calculation from acceptance

SWAP5 treats a model interval as a transaction. Numerical and physical routines may calculate a tentative result, but the result becomes authoritative only when the attempt is accepted and committed.

This architecture is intended to make retry, rollback, restart and coupling behaviour explicit without redefining the underlying scientific equations.

## State categories

**Committed state** is accepted persistent authority.

**Candidate state** is the tentative endpoint/process result of the active attempt.

**Scratch/workspace** is disposable numerical/process storage with no persistence authority.

A rejected attempt must not leak candidate or scratch effects into the next accepted state.

## Attempt lifecycle

The admitted pattern is:

1. begin from committed authority;
2. construct the trial/candidate context;
3. execute the numerical and physical work;
4. assess solver status and applicable scientific/numerical criteria;
5. accept and commit, or reject;
6. if retry is permitted, restore/retain the committed authority and make the next bounded attempt.

Rollback therefore protects state authority; it is not a new physical process.

## Step-doubling and execution decisions

The SWAP5 architecture contains an explicit execution-policy layer for bounded timestep assessment. Historical implementation work introduced explicit decision states such as accepting a full attempt, accepting an independently valid two-half-step result where the admitted policy permits it, or retrying.

These decisions are separate from the underlying process calculation. An execution controller may choose between already qualified candidate outcomes only within its admitted contract; it may not create new physics by policy.

## Temporal certificate lineage

Historical F-DOC13 records a restricted time-reference indicator construction. Its exact theorem applies to a constant linear dissipative semi-discrete backward-Euler problem. Later qualification demonstrated bounded transfer/consistency behaviour for the stated nonlinear candidate matrix, but **did not promote the indicator to a general nonlinear true-error bound**.

The normalized form recorded by that lineage is schematically:

```text
C_h = B_inf / H_budget
```

with an explicit finite positive `H_budget` where that capability is used. There is no universal application budget implied by this documentation.

The important architectural rule is more general: an optional numerical certificate cannot override a hard mass failure, and missing prerequisites must fail closed rather than fabricate confidence.

## Restart

Restart v1 persists the admitted **committed** execution state required for qualified continuation. It does not claim that arbitrary scratch or rejected candidate state is serialised.

This is why restart belongs to persistence/transaction semantics as well as file/state representation.

## MultiSWAP and coupling

Serialized MultiSWAP v1 coordinates multiple qualified column contexts without weakening the committed/candidate boundary.

Groundwater Coupling v1 likewise follows accepted-state publication semantics: tentative coupling outputs do not become authoritative external state merely because they were computed during a trial.

## Review invariants

A reviewer should treat the following as hard architecture expectations for the frozen Status-A scope:

- rejected trials do not mutate committed scientific state;
- accepted state is committed exactly once;
- retry begins from accepted authority;
- process/solver code does not silently become global execution policy;
- external publication follows accepted state;
- restart reconstructs the admitted committed-state contract;
- performance work cannot add hidden persistent aliases or change transaction semantics.

See [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md) and [Core invariants](../architecture/invariants.md) for the controlling architecture documentation.
