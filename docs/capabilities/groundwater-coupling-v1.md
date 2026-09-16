# Groundwater Coupling v1

Groundwater Coupling v1 is the bounded Status-A groundwater capability chain. It combines an admitted internal coupling contract with transaction-safe publication semantics and a structural external gateway boundary.

## Scientific and coupling role

The groundwater capability connects the SWAP column to an admitted lower-boundary/coupling context without giving an external model direct ownership of tentative SWAP state. Scientific exchange remains subject to the owning coupling contract and the accepted execution state.

The external groundwater gateway is therefore an adapter boundary, not an assertion that one particular broad groundwater backend has become part of the Status-A scientific core.

## Accepted-state publication

The central ownership rule is:

**computed is not the same as published.**

A coupling attempt may calculate tentative exchange/state information, but externally authoritative publication follows accepted-state semantics. If an attempt is rejected or rolled back, its tentative coupling result must not survive as though it were accepted model state.

This rule is important for reproducibility, retry behaviour and conservation across coupled execution.

## Status-A evidence chain

The production implementation is contained in scientific baseline `50346642…`. The capability-specific qualification chain runs through the F-GC workunits, including the bounded external gateway and end-to-end qualification, and closes through F-GC28 before inclusion in the Status-A authority.

Current preservation authority includes same-tree F-GC29 targeted groundwater tests, mixed-smoke coverage and preservation of accepted-state publication/rollback behaviour.

Use [Status-A traceability](../status-a/TRACEABILITY.md) to enter the exact capability authority chain.

## What v1 covers

Within its bounded admitted contract, Groundwater Coupling v1 establishes that:

- the coupling seam is explicit rather than hidden in unrelated solver/global state;
- tentative coupling work respects the transaction boundary;
- accepted state is the publication authority;
- the external gateway provides the structural location for a conforming external implementation;
- the qualified groundwater capability composes with the admitted preservation/runtime surface covered by its tests.

## Explicit nonclaims

Groundwater Coupling v1 does **not** claim:

- a broad or unrestricted MODFLOW backend;
- arbitrary coupling schedules or temporal interpolation policies;
- automatic correctness of every future external groundwater implementation;
- concurrent real-physics MultiSWAP coupling;
- that an adapter interface alone proves the scientific validity of a backend;
- new groundwater physics beyond the admitted v1 contract.

These remain separate future capability decisions.

## Review questions

For a groundwater-sensitive change, check:

1. Which side owns each exchanged state or flux before and after acceptance?
2. Can a rejected attempt publish or retain tentative external state?
3. Are units, signs, time support and aggregation rules explicit at the boundary?
4. Is mass/accounting closure preserved through coupling composition?
5. Does the change alter only an adapter implementation, or does it alter the scientific coupling contract?
6. Which targeted and mixed-smoke preservation evidence must be replayed because of the dependency change?

See also [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md) and [Mass-accounting contract](../verification/mass-accounting-contract.md).