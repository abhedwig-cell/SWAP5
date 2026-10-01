# SW-RIB-TOP01-C — surface control-volume research component

Date: 2026-10-01

Status: IMPLEMENTED_RESEARCH_CANDIDATE_NOT_EXECUTED

Branch head:
`5300b2736db07f34f4702de1dc29cb18c9f8504d`

## Implemented

Research-only pure component:

`tests/sw-rib-top01/mod_external_top_surface_transfer.f90`

It materializes the residual external top transfer from:

- previous/candidate local ponding;
- atmospheric source amount;
- evaporation amount;
- positive surface-to-soil entry amount;
- separately identified runoff-to-external amount.

Equation:

`X = dS - A + E + D + O`.

It returns:

- `ribasim_to_swap_cm = X`;
- `legacy_runots_cm = -X`;
- exact algebraic closure residual.

## Important accounting refinement

Runoff `O` is already an explicit external transfer component.

Therefore a no-flooding rainfall/runoff case with:

`A = D + O`

has residual `X=0`.

The interface ledger may later publish net top exchange as `X-O` if desired,
but the residual materializer must not label ordinary runoff itself as missing
external supply. This prevents double booking.

The process decomposition is therefore:

- explicit runoff component `O`: SWAP -> Ribasim;
- residual inundation/supply component `X`: Ribasim -> SWAP when positive,
  or an attribution warning/alternate external contribution when negative;
- legacy `RUNOTS = O-X` only after composing both components.

Accordingly, the research module's field named `legacy_runots_cm` currently
represents `-X` and is **not yet sufficient** as the final legacy RUNOTS
publication when `O>0`.

This is intentionally recorded as a design finding before production use.

## Test cases

`tests/sw-rib-top01/test_surface_transfer.f90` covers:

- zero residual transfer;
- rainfall partitioned into soil entry plus runoff;
- flooding that raises ponding and supplies soil entry;
- rainfall offsetting external flooding supply;
- evaporation increasing required external supply;
- positive/zero/negative residual direction seam;
- invalid negative explicit runoff.

Runner:

`tests/sw-rib-top01/run_surface_transfer.sh`

compiles/runs at O0 and O2.

## Qualification boundary

The gate is persisted but not yet executed by a compiler-backed repository
checkout. No PASS claim is made.

Before TOP01-D, rename/refine the legacy publication field so the component
cannot be mistaken for the final composed `RUNOTS = O-X`.

## Next

TOP01-D:

1. correct the research result API to expose residual supply and composed
   RUNOTS separately;
2. add the pure flooding classifier
   `h_ext > h_sill && h_ext > h_local`;
3. add a research external-head hydraulic view;
4. bind the admitted solver top-flux sign explicitly before deriving `D`.
