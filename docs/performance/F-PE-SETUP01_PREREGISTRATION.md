# F-PE-SETUP01 — large-N production application-context setup decomposition

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-MULTIPROC04 / PR #675`

Parent head:
`bd6411a1bbf4568e415401c9675b144cbbcaf081`

Branch:
`work/f-pe-setup01-large-n-context-setup`

## Trigger

MULTIPROC04 showed that persistent repeated trial throughput is effectively equivalent across 1x4 / 2x2 / 4x1, while one-time setup differs strongly at large N.

At N=40,000:
- 1x4 setup: ~3.987 s;
- 2x2 setup: ~1.641 s;
- 4x1 setup: ~1.264 s;
- persistent repeated trial wall: ~0.87-0.89 s for all configurations.

The next performance target is therefore large-N setup/application-context construction rather than process partitioning of steady-state trials.

## Purpose

Decompose the one-process production-shaped 1x4 setup path and identify exactly one measured setup family for optimization.

## P0 stages

Instrument research-only fixture copies and report wall time for:

1. Python process/library load;
2. `initialize_config`;
3. `app%initialize`;
4. reference-head/topology/predictor construction;
5. `app%materialize_groundwater_context`;
6. `capture_origins`;
7. first warm trial + tangent + discard.

Primary populations:
- N=10,000;
- N=40,000.

Optional characterization:
- N=1,000.

## Measurement rules

- same production-shaped TEMPORAL08 fixture;
- worker count = 4;
- 5 fresh-process repetitions per N;
- replicated median by stage;
- total measured stage sum reconciled against outer setup wall;
- no production `src/**` changes.

## Selection rule

Advance exactly one family if it:
- owns >=25% of N=40,000 setup wall; or
- grows disproportionately from N=10,000 to N=40,000 and owns >=15% at N=40,000.

If no isolated family meets either rule, close SETUP01 as no single setup target and retain setup parallelism only as an architectural observation.

## Interpretation priorities

If `initialize_config` dominates:
- inspect repeated per-tile immutable physical/template/state construction and allocation.

If `app%initialize` dominates:
- inspect registry/backend/bootstrap copies and per-tile mutable state construction.

If `materialize_groundwater_context` dominates:
- inspect plan/topology/context copying, validation and ledger/participant materialization.

If warm trial dominates:
- classify the earlier setup delta as first-use/warm-state cost rather than pure construction.

## Production boundary

Research-only timing instrumentation.

No physics, tolerances, temporal policy, tangent mathematics, transaction semantics, aggregation order or MODFLOW equations change.