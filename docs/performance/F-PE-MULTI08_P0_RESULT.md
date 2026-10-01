# F-PE-MULTI08 P0 — frontier feasibility and research-seam decision

Date: 2026-10-01

Status: QUALIFIED_DESIGN_RESULT

Baseline:
`integration/f-ci-canonical@81b7feda17f53a94ab4e5877467cc4499de6f568`

## Finding

The current generic in-process physical worker pool is production-admitted only
for worker counts 2 and 4. Worker count 1 delegates exactly to the serialized
route. Any other count is rejected before physical execution.

Therefore issue #668 cannot obtain an 8/16/24/oversubscribed frontier by merely
parameterizing the existing production benchmark.

The existing MULTI04 application-context harness is also frozen around 1/2/4,
while MULTI06/MULTI07 provide a physically real mode-7 workload and exact
worker-count identity evidence for 1/2/4.

## Decision

Do not broaden production admission in order to measure scaling.

MULTI08 will use a research-only characterization seam that reuses the same:

- worker-local Reference backend type;
- transaction controls;
- deterministic assignment semantics;
- physical column executor;
- canonical result collection and mass checks.

The research seam may request worker counts above 4, but it must not alter the
production admission gate in `mod_fmr_parallel_worker_pool.f90`.

Only if a materially useful scaling region exists beyond worker 4 may a
separate admission work unit be proposed.

## Benchmark family

Primary workload: the already-qualified GENERATED ELAS mode-7 profile-8016
physical population, enlarged by deterministic replication while preserving
independent committed state per logical column.

Initial research sweep:

- workers: 1, 2, 4, then powers/intermediate counts supported by the host;
- population sizes: at least 256, 1024 and one materially larger population;
- repeats: minimum 5 measured repeats after one warm-up where runtime permits;
- affinity: record OpenMP binding/places and host topology.

The benchmark must retain exact completion, retry and mass identity across
worker counts.

## Host rule

A host may characterize only worker counts for which it can actually form the
requested OpenMP team.

GitHub-hosted CI remains a correctness/preservation environment, not authority
for the production scaling frontier.

## Next gate

P1: implement the smallest research-only scalable harness without changing
production source, and prove 1/2/4 identity against the admitted worker-pool
authority before using it above 4.
