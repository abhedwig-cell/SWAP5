# F-TB01 — Hard Water-Mass Gate Contract

## Non-negotiable invariant

Mass conservation is a hard SWAP5 architecture invariant. Standalone, MultiSWAP, coupling, fallback, reduced/coarse/alternative solver and performance modes must conserve water. There is no profile switch that makes water disappearance an accepted performance trade-off.

## Canonical ledger equation

For a qualified interval `[t0,t1]`, with a single documented sign convention:

`DeltaStorage = Sum(Inputs) - Sum(Outputs)`

The ledger enumerates all active water-bearing terms rather than hiding balancing corrections. Depending on active physics, terms include:

- precipitation/rainfall;
- irrigation;
- runoff/outflow;
- evaporation;
- transpiration/root extraction;
- drainage;
- bottom boundary flux;
- surface/ponding storage change;
- snow storage change;
- macropore-domain storage and inter-domain transfers;
- groundwater/interface transfers;
- any optional component storage/transfer explicitly active in the composed system.

Internal transfers appear symmetrically or are excluded from external totals by a declared accounting rule; they may not create or remove net water.

## Machine-readable gate fields

A water-bearing test case declares at least:

- `required: true`;
- ledger/sign-convention version;
- storage components expected active;
- external input/output terms expected active;
- closure evaluation rule and unit;
- interface-conservation rule when coupled;
- transaction rule;
- qualification evidence for any numerical roundoff handling.

The validator SHALL reject a water-bearing mandatory case that omits the mass gate.

## Transaction semantics

For a rejected trial:

- committed physical storage is unchanged;
- committed time/revision/lineage is unchanged;
- committed cumulative mass ledger is unchanged;
- trial scratch/diagnostics may be discarded or reused only as non-authoritative numerical information.

Only commit transfers trial results into committed state/ledger, exactly once.

## Coupling semantics

For direct SWAP–groundwater coupling, the interface contract requires head compatibility and opposite flux signs. The mass gate tests the interface flux identity under the qualified convention:

`q_SWAP + q_GW = 0`

No head-residual tolerance can authorize an interface water leak. Multiple surface tiles are area-weighted by runtime/coupler composition; the weighting ledger must close. A separate deep-vadose transfer component, when active, owns its own storage and conserves transition mass during activation/deactivation or routing changes.

## Performance/fallback semantics

A bounded-cost fallback can alter numerical method only within its admitted scope. It may not relax or disable the hard mass gate. A case that meets runtime targets but fails mass is `FAIL`, never a performance-qualified success.

## Roundoff is not a concession

Implementations may require a machine-precision-aware closure expression because floating-point summation is finite precision. Such a rule is itself frozen, unit-aware, scale-aware and evidence-backed. It distinguishes representational arithmetic from missing water; it is not a tunable scientific mass-loss budget.