# PPA-WU05-A5 P1/P2 local receipt-conservation result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / TOP_RECEIPT_OWNERSHIP_CONFIRMED`

## Upstream QMpLatSs authority

Exact SWAP 4.3.1 source tracing identifies the producer/consumer contract.

### Producer — boundtop.f90

When ponding exceeds the macropore surface threshold, `boundtop` calculates potential lateral overland inflow:

`QMpLatSs = pond * dt / RsRoMp`

with source-defined resistance/capping.

### Matrix top-flux coupling — PONDRUNOFF

The same `QMpLatSs` is then removed from the matrix/surface top flux:

`q0hlp = q0 - QMpLatSs/dt`.

This makes `QMpLatSs` an explicit partition of the existing top/surface receipt, not an additional external source.

### Ponding mass check — headcalc.f90

For surface-connected macropores, the ponding balance includes:

`+ ArMpSs*(NRaiDt+NIrd+Melt)*dt + QMpLatSs`.

Thus the direct vertical macropore share and lateral overland macropore share are both removed from the ordinary surface/matrix route and booked into the macropore route exactly once.

### Return path — macrorate.f90

After domain capacity limitation and cross-domain redistribution, remaining top excess is returned through:

`QMpLatSs = QMpLatSs - FlwInTopExcesTot`.

The returned share therefore becomes available again to the main SWAP surface/runoff route.

## Local multi-domain harness

A reduced source-shaped three-domain harness was constructed with:

- top-area partition;
- domain capacity limits;
- global accumulated top excess;
- source-shaped cross-domain redistribution;
- returned remaining share.

Four regimes were screened:

1. mixed direct/lateral input with one constrained domain;
2. lateral-only input with redistribution;
3. severely capacity-limited vertical input;
4. unconstrained mixed input.

For every case:

`accepted_vertical + accepted_lateral + returned = requested_vertical + requested_lateral`

to machine precision.

## Strongly limited example

Requested:

- vertical top amount: `0.50 cm`;
- lateral top amount: `0.00 cm`.

Total available macropore capacity:

`0.06 cm`.

Result:

- accepted macropore amount: `0.06 cm`;
- returned to surface route: `0.44 cm`;
- residual: 0.

This confirms the source ownership model requires a **returned surface receipt**, not a generic external overflow sink.

## P1/P2 conclusion

`TOP_PARTITION_AND_EXCESS_REDISTRIBUTION_CONSERVE_THE_ORIGINAL_SURFACE_RECEIPT`.

The source-authoritative R2 contract should therefore represent top partition as a transactional receipt split with:

- requested direct vertical amount;
- requested lateral amount;
- accepted direct vertical amount;
- accepted lateral amount;
- redistributed amount;
- returned/unaccepted surface amount.

No extra external water source or generic overflow sink is needed for this surface-connected route.

## Implementation consequence

The next typed A5 process component should expose a top-partition result separately from the continuation state.

The outer surface/top-boundary owner remains authoritative for the returned share.

Macropore state should only receive accepted amounts.

## Next step

Implement a typed research `macropore_top_partition_result_t` and multi-domain partition evaluator, then bind accepted top amounts into the A4 process candidate without changing the outer coupling controller.
