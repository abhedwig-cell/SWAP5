# F-PE-MULTI01 P1 result — production groundwater serial scaling

Date: 2026-09-27

Status: `PASS_PARALLEL_SUCCESSOR_JUSTIFIED`

PR:
`#661 — F-PE-MULTI01: current-canonical MultiSWAP scaling rebaseline`

Authority run:
`36307477079`

Job:
`p1-groundwater-scaling`

## Production-shaped scope

P1 measures the current production groundwater application-context route with:

- bottom mode 5;
- Richards temporal-history continuation;
- model-certificate temporal acceptance;
- production c=0.65 history-aware temporal policy;
- accepted-origin heads;
- history seed aligned with TEMPORAL08 production authority;
- one tile per groundwater cell.

Current bootstrap ownership is preserved: the participant registry shares one mutable serialized Reference backend, so trial execution is serial.

No production source is modified.

## Scaling

Median repeated trial cost:

- N=10: 0.260696 ms, 26.070 us/tile;
- N=100: 2.637147 ms, 26.371 us/tile;
- N=1,000: 27.110081 ms, 27.110 us/tile.

The per-tile cost is nearly constant over two orders of magnitude in N.

Other repeated phases are small relative to trial execution.

At N=1,000:

- tangent query: about 0.040 ms;
- discard: about 0.160 ms;
- trial_cell_heads: about 27.11 ms.

Thus repeated runtime is dominated by independent per-tile participant/physical work, not tangent aggregation or discard.

Q and tangent checksums scale consistently with N.

## Ownership interpretation

The current serial behavior is an ownership constraint, not evidence that physical tile work is inherently serial.

The generic worker-pool P0 demonstrates that the current codebase can execute independent physical columns concurrently when each worker owns independent mutable backend/workspace state.

The production groundwater route instead binds many participants to one shared mutable Reference backend.

Concurrent calls through that shared backend are not authorized.

## Decision

Advance one successor:

`F-PE-MULTI02 — worker-local production groundwater backend parallelization`.

The successor must retain:

- independent participant accepted-origin state;
- worker-local mutable backend/workspace state;
- deterministic canonical aggregation/publication;
- identical q/tangent results within roundoff;
- identical retry/acceptance decisions;
- no candidate/state/ledger leakage.

Frozen P2 performance gates from MULTI01:

- sufficiently large-N 2-worker speedup >= 1.5x;
- sufficiently large-N 4-worker speedup >= 2.2x.

No physics or numerical policy change is authorized.
