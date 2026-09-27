# F-PE-SOLVE01 P2A preregistration — N:1 SWAP scale mechanics

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH`

Parent:
`F-PE-SOLVE01 P2`

## Purpose

Before claiming a full heterogeneous live MultiSWAP/MODFLOW scale result, qualify the N-scaling mechanics of discarded-trial solve elimination itself.

P1 has already established live MODFLOW6 robustness for E4/EH on the existing F-GC44 corrector.

P2A therefore isolates the SWAP-side N:1 scaling question:

- one groundwater-cell aggregate;
- N real SWAP participants;
- real transaction/Richards trials;
- area-weighted aggregate response;
- exact final validation and commit;
- E0 versus E4.

P2A is an infrastructure/performance qualification step. It is not the final P2 live-coupling authority.

## Scale levels

Frozen:

- N = 1;
- N = 100;
- N = 1,000.

N = 10,000 may be added only if N = 1,000 completes within practical CI cost.

## Topology

All N SWAP tiles represent one N:1 groundwater-cell aggregate.

Area fractions are uniform:

`f_i = 1/N`.

The aggregate response is:

`q_cell = sum_i f_i q_i`.

Every exact aggregate evaluation executes real SWAP participant trials for all N tiles.

## Workload

Use the frozen eight-request difficult same-origin corrector block already used in SOLVE01:

`+0.001, +0.01, -0.001, -0.01, +0.001, -0.001, +0.01, -0.01 cm`.

Repeat the block enough times for stable timing.

P2A may use one homogeneous difficult hydraulic profile because its purpose is N-scaling mechanics.

To isolate scale mechanics from the already-characterized temporal-policy frontier, the research harness freezes a direct-accept temporal head budget of `0.02 cm` for both E0 and E4. The qualified BALTOL02 dt-scaled Reference balance floor is replayed inside the harness. Neither choice constitutes production admission.

The final P2 phase, if P2A succeeds, must restore the preregistered heterogeneous difficult material/regime composition.

## Policies

### E0

Every corrector request executes all N SWAP trials exactly.

### E4

An exact aggregate anchor is computed from all N participants.

Up to three subsequent discarded corrector responses are served from:

`q(h) = q_anchor + J_anchor (h-h_anchor)`.

At refresh and final validation, all N participants are evaluated exactly.

Only exact validated tile candidates may commit.

## Relation to live authority

P2A does not replace P1.

Live MODFLOW6 robustness remains established by P1.

P2A answers whether the solve-elimination mechanism retains its advantage as the number of real SWAP participants grows.

The final P2 authority must combine both properties in a production-shaped live workload.

## Measurements

At each N and policy:

- initialization time;
- repeated corrector wall-clock;
- exact tile-trial count;
- approximate aggregate response count;
- exact refresh count;
- exact final-validation count;
- final aggregate q;
- per-tile SWAP commit count;
- per-tile ledger commit count where available.

## P2A success criteria

The mechanism is scale-capable if:

1. N = 1,000 completes successfully;
2. E4 exact tile-trial count is at least 50% below E0;
3. E4 produces at least 30% repeated-corrector wall-clock gain at N = 1,000;
4. exact final aggregate q/state authority is preserved at commit;
5. every tile commits exactly once;
6. no approximate candidate is published.

P2A does not require the final P2 1.5x end-to-end application gate.

## Stop condition

If SWAP-side N:1 execution itself scales poorly enough to erase the solve-elimination gain by N = 1,000, stop before building the final heterogeneous live P2 matrix.

## Handoff

If P2A passes, build the final heterogeneous live P2 authority using the same solve-elimination policy and the original P2 advancement gates.
