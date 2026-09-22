# SWAP5-MODFLOW6 fixed-interface drainage ownership contract

Status: **canonical authority for the bounded fixed-interface profile**

This contract applies to the bounded fixed-interface groundwater profile closed by
`F-GC_FIXED_INTERFACE_COUPLING_CONTRACT.json`.

## Current admitted profile

The admitted drainage owner is `NONE`.

Active SWAP drainage response is excluded by the production bootstrap. No MODFLOW
drain package or surface-water route is admitted here as an alternative owner of
the same physical drainage process. The coupling mass ledger is accounting only
and can never own a physical drainage route.

This is deliberately narrower than the research testbank. Analytical drainage
oracles remain regression evidence and do not widen production physics.

## One-route, one-owner rule

Before any physical drainage route is admitted, application topology must assign
that route to exactly one owner:

- `SWAP`;
- `MODFLOW`; or
- `SURFACE_WATER`.

For that same physical route, all other model-side representations must be absent
or explicitly disabled. Coupler bookkeeping is not a fourth physical owner.

A route with unresolved ownership fails closed. A topology that represents the
same physical drainage route in more than one owner is invalid, even if the
resulting coupled calculation converges or its total water balance happens to
close.

## Admission evidence for a future route

A future drainage widening requires route identity and destination to be explicit,
plus accepted component budgets showing that the drainage amount appears exactly
once and that the fixed-interface groundwater transfer remains separately
equal-and-opposite. Such a widening is outside the present closeout.
