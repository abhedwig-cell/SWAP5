# F-PE-SCHEDCACHE01 — captured-origin worker schedule cache qualification

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Canonical parent:
`integration/f-ci-canonical@faba48edaea9fd128407c584fc4c911747f5f283`

Branch:
`work/f-pe-schedcache01-origin-schedule-cache`

## Trigger

The parallel groundwater application-context path rebuilds its worker schedule on every trial by:
- querying a pretrial cost proxy for every participant;
- constructing static ownership;
- computing load ratios;
- optionally sorting by cost and rebuilding a cost-aware owner map.

The participant cost proxy is based on the captured origin's temporal-history scale. Within one captured application context, repeated corrector trials share that accepted origin.

## Candidate

Cache the selected worker owner map after the first trial from a captured origin.

Rules:
- invalidate the cache at every `capture_origins`;
- first parallel trial after capture builds the schedule exactly as today;
- subsequent trials reuse the cached owner map and schedule diagnostics;
- discard/retry of candidates does not invalidate the cache because the accepted origin is unchanged;
- a new captured origin always forces rebuild.

No change to:
- cost proxy definition;
- static/cost-aware threshold;
- scheduler selection logic;
- worker-local backend ownership;
- canonical result order.

## Paired qualification

Production-shaped MULTI04 fixture:
- N=1,000;
- N=10,000;
- N=40,000.

Five measured repeated trials after one warm-up.

Primary:
- worker=4.

Semantic requirements:
- exact q checksum;
- exact tangent checksum;
- deterministic repeated output;
- same schedule class/load diagnostics after warm-up;
- same success/failure behavior.

## Performance gates

Advance only if:
- N=1,000 candidate <=1.02 * baseline;
- N=10,000 worker=4 speedup >=1.05x;
- N=40,000 worker=4 speedup >=1.08x.

## Production boundary

Research-only compiled source copy.

No production `src/**` change before qualification.
No physics, tolerance, temporal, tangent, aggregation, transaction, publication or worker-ownership semantic change.
