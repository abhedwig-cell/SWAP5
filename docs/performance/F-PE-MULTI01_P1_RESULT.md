# F-PE-MULTI01 P1 result — production groundwater serial scaling

Date: 2026-09-27

Status: `PASS_PARALLEL_SUCCESSOR_JUSTIFIED`

PR:
`#661 — F-PE-MULTI01: current-canonical MultiSWAP scaling rebaseline`

Current-head authority:
- branch head exercised: `0cb0811fc4118c4acafe36bc182c65051cc1943b`;
- workflow run: `36307581257`;
- job: `p1-groundwater-scaling`.

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

- N=10: `0.159822 ms`, `15.982 us/tile`;
- N=100: `1.630083 ms`, `16.301 us/tile`;
- N=1,000: `16.618811 ms`, `16.619 us/tile`.

The per-tile cost is nearly constant over two orders of magnitude in N.

Other repeated phases are tiny relative to trial execution.

At N=1,000:

- tangent query: about `0.0124 ms`;
- discard: about `0.0778 ms`;
- `trial_cell_heads`: about `16.62 ms`.

Thus repeated runtime is dominated by independent per-tile participant/physical work, not tangent aggregation or discard.

Q and tangent checksums scale consistently with N.

## Ownership interpretation

The current serial behavior is an ownership constraint, not evidence that physical tile work is inherently serial.

The generic worker-pool P0 demonstrates that the codebase can execute independent physical columns concurrently when each worker owns independent mutable backend/workspace state.

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

Frozen performance gates from MULTI01:

- sufficiently large-N 2-worker speedup >= 1.5x;
- sufficiently large-N 4-worker speedup >= 2.2x.

No physics or numerical policy change is authorized.
