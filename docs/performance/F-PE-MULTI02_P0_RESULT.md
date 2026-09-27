# F-PE-MULTI02 P0 result — worker-local backend ownership and scaling proof

Date: 2026-09-27

Status: `PASS_WORKER_LOCAL_OWNERSHIP_AND_SPEED_GATES`

PR:
`#662 — F-PE-MULTI02: worker-local production groundwater parallelization`

Authority run:
`36307993584`

## Ownership proof

A research-only production-bootstrap variant replaced the single groundwater backend binding with independent mutable backend instances while retaining:

- the same participant registry;
- per-tile accepted-origin ownership;
- per-tile candidate ownership;
- immutable prepared hydraulic parameters;
- the same temporal-history state;
- the same c=0.65 temporal-budget policy;
- the same context aggregation and discard semantics.

Serial worker-local ownership was compared against the current shared-backend serialized authority for N=10, 100 and 1,000.

Observed:

- q checksum difference: exactly 0 for every N;
- tangent checksum difference: exactly 0 for every N;
- candidate discard preserves committed revisions;
- serial runtime remains in the same band, with candidate/baseline ratios about 1.01, 0.98 and 1.04.

Thus backend ownership can be separated without changing the measured serialized physical response.

## Parallel research proof

A second research harness bound participants round-robin to 1, 2 or 4 independent mutable Reference backends and executed trials with a matching static round-robin OpenMP schedule.

At N=1,000:

- 1 worker: 34.047 ms;
- 2 workers: 17.990 ms, speedup 1.893x, efficiency 0.946;
- 4 workers: 14.425 ms, speedup 2.360x, efficiency 0.590.

At N=100:

- 2 workers: 1.925x;
- 4 workers: 2.372x.

Real concurrency was observed:

- max simultaneous solves = 2 for the 2-worker arm;
- max simultaneous solves = 4 for the 4-worker arm.

For every compared arm:

- maximum q difference = 0;
- maximum tangent difference = 0.

## Frozen speed gates

MULTI02 preregistered sufficiently-large-N gates:

- 2 workers >= 1.5x;
- 4 workers >= 2.2x.

At N=1,000:

- 2 workers = 1.893x: PASS;
- 4 workers = 2.360x: PASS.

## Interpretation

The production groundwater workload is not inherently serial.

The current serial behavior follows from shared mutable backend/workspace ownership. When mutable solver state is worker-local, the same participant physics can execute concurrently and clears both preregistered speed gates on the P0 homogeneous population.

This does not yet authorize production parallelism.

## Next gate

P1 must add discrete-route authority:

- identical attempts;
- identical accepted-substep count;
- identical retries;
- identical temporal rejections;
- identical solver rejections;
- no participant candidate leakage after discard;
- deterministic repeated aggregate q/tangent results.

P1 must also retain the worker-local ownership invariant and must not call the current shared production backend concurrently.
