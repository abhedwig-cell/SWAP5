# F-PE-SOLVE01 P2A preregistration — N:1 live scale mechanics

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH`

Parent:
`F-PE-SOLVE01 P2`

## Purpose

Before claiming a full heterogeneous production-shaped MultiSWAP scale result, first qualify the scaling mechanics of discarded-trial solve elimination on a live N:1 topology:

- one live MODFLOW6 cell;
- N real SWAP participants;
- area-weighted aggregate response;
- exact final validation before publication;
- E0 versus E4.

P2A is an infrastructure/performance qualification step, not the final P2 physical authority.

## Scale levels

Frozen:

- N = 1;
- N = 100;
- N = 1,000.

N = 10,000 may be added only if N = 1,000 completes within practical CI cost.

## Topology

All N SWAP tiles belong to one groundwater cell.

Area fractions are uniform:

`f_i = 1/N`.

The aggregate response is:

`q_cell = sum_i f_i q_i`.

All tiles use real transaction participants and real Richards trials.

## P2A workload

Use one difficult mid-regime hydraulic profile for all tiles.

This homogeneous profile is intentional: P2A isolates N-scaling mechanics from heterogeneity.

The final P2 phase, if P2A succeeds, must restore the preregistered heterogeneous difficult material/regime composition.

## Policies

### E0

Every live corrector request executes all N SWAP trials exactly.

### E4

An exact aggregate anchor is computed from all N SWAP participants.

Up to three subsequent discarded corrector responses are served from:

`q(h) = q_anchor + J_anchor (h-h_anchor)`.

At refresh and final validation, all N SWAP participants are evaluated exactly.

Only exact validated tile candidates may commit.

## Measurements

At each N and policy:

- initialization time;
- coupled-corrector wall-clock;
- MODFLOW iteration count;
- exact tile-trial count;
- approximate aggregate response count;
- validation count;
- validation failures;
- final head;
- final aggregate exchange;
- per-tile commit count;
- ledger publication count.

## P2A success criteria

The N:1 mechanism is considered scale-capable if:

1. N = 1,000 completes successfully;
2. E4 exact tile-trial count is at least 40% below E0 on a workload with at least four live corrector requests;
3. E4 produces a positive coupled wall-clock gain at N = 1,000;
4. final exact aggregate endpoint matches E0 within existing coupled authority;
5. every tile commits exactly once;
6. no approximate candidate is published.

P2A does not require the final P2 1.5x speedup gate.

## Stop condition

If the live N:1 infrastructure itself cannot scale to N = 1,000 without dominating runtime or violating publication ownership, stop before building the heterogeneous P2 matrix.

## Handoff

If P2A passes, build the final heterogeneous P2 authority using the same N:1 machinery with the frozen difficult material/regime mixture and the original P2 advancement gates.
