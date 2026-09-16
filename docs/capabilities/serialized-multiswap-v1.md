# Serialized MultiSWAP v1

Serialized MultiSWAP v1 is the admitted SWAP5 orchestration capability for executing multiple qualified real-physics column contexts **serially** while preserving the same transaction and state-ownership rules that apply to one column.

## Scientific and architectural role

MultiSWAP is not a new soil-water equation. It is an execution/composition capability: multiple logical SWAP columns or tiles can be coordinated while each admitted physical solve remains subject to its own qualified scientific and transactional contract.

The Status-A claim is intentionally restricted to serialized real-physics execution. The orchestration layer may coordinate contexts and aggregate admitted observables, but it does not gain authority to change process physics or bypass trial/accept/rollback semantics.

## State ownership

For each qualified column context:

- committed state remains the accepted authority;
- candidate effects remain tentative until acceptance;
- rejected attempts must not leak into later accepted execution;
- orchestration metadata must not become an alternative scientific state authority.

The aggregate result is therefore composed from accepted column results, not from partially accepted or rejected trial states.

## Mass and observable preservation

The current Status-A preservation authority reports same-tree replay of the serialized MultiSWAP observable and aggregate-mass checks on the pinned scientific production tree. These checks establish the bounded composition claim used by Status-A; they do not establish arbitrary future execution topologies.

## Evidence route

For current review, follow the chain summarized in [Status-A traceability](../status-a/TRACEABILITY.md):

`serialized orchestration contract -> production implementation in 50346642… -> MultiSWAP qualification/admission -> Status-A acceptance -> same-tree observable and aggregate-mass replay`

The mixed-smoke and permanent regression suites provide additional preservation coverage where their dependency contracts apply.

## Explicit nonclaims

Serialized MultiSWAP v1 does **not** claim:

- parallel or concurrent real-physics execution;
- thread-safe or process-safe shared scientific state under arbitrary concurrency;
- automatic rebatching or execution-class switching;
- a general performance speedup;
- unrestricted coupling to arbitrary external groundwater backends;
- that future newly admitted process state is automatically MultiSWAP-safe.

Those are separate capability decisions and require separate qualification.

## Review questions

When reviewing a MultiSWAP-sensitive change, check:

1. Does each column retain an unambiguous committed/candidate boundary?
2. Are aggregate quantities formed only from accepted authority?
3. Does a failure/retry in one context preserve the required isolation contract?
4. Are any new shared mutable objects being introduced across column contexts?
5. Is a performance change being mistaken for a new execution-semantics admission?

See [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md) for the runtime ownership model.