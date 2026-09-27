# F-PE-SCHEDCACHE01 result — captured-origin worker schedule cache

Date: 2026-09-27

Status: `CLOSED_LOW_RETURN`

PR:
`#690 — F-PE-SCHEDCACHE01: captured-origin worker schedule cache`

Measured head:
`d053e5d984f4f068d58b467735e0fb38e100a866`

## Candidate

Reuse the selected owner map for repeated trials from one captured accepted origin, invalidating the cache on every new `capture_origins`.

## Results

### N=1,000
- worker=4 speedup: 0.992x;
- no-regression gate: PASS.

### N=10,000
- worker=4 speedup: 1.003x;
- frozen >=1.05x gate: FAIL.

### N=40,000
- worker=4 speedup: 0.993x;
- frozen >=1.08x gate: FAIL.

Exact q and tangent checksums were preserved.

## Decision

Schedule rebuilding is not a material repeated-trial bottleneck on the measured production-shaped workload.

Do not production-admit schedule caching.
