# F-PE-MULTI02 P1 result — discrete-route semantic authority

Date: 2026-09-27

Status: `PASS_DISCRETE_ROUTE_IDENTITY`

PR:
`#662 — F-PE-MULTI02: worker-local production groundwater parallelization`

Authority run:
`36308261798`

Job:
`p1-discrete-semantics`

## Scope

P1 reuses the P0 worker-local mode-5 groundwater population and compares worker counts 1, 2 and 4 for N=10, 100 and 1,000.

The test adds research-only participant diagnostics exposure. Production source semantics are unchanged.

## Result

For every N, q and tangent differences between serialized and parallel execution are exactly zero in the measured outputs.

The discrete numerical route is also identical.

N=10, all worker counts:

- attempts: 40;
- accepted substeps: 20;
- retries: 20;
- temporal rejections: 20;
- solver rejections: 0;
- nonlinear iterations: 120;
- backtracking attempts: 120.

N=100, all worker counts:

- attempts: 400;
- accepted substeps: 200;
- retries: 200;
- temporal rejections: 200;
- solver rejections: 0;
- nonlinear iterations: 1,200;
- backtracking attempts: 1,200.

N=1,000, all worker counts:

- attempts: 4,000;
- accepted substeps: 2,000;
- retries: 2,000;
- temporal rejections: 2,000;
- solver rejections: 0;
- nonlinear iterations: 12,000;
- backtracking attempts: 12,000.

## Interpretation

Worker-local backend execution preserves not only the final q/tangent response but also the temporal retry path and nonlinear solve trajectory on this nontrivial retrying population.

This removes the main semantic concern left after P0.

## Decision

Advance to P2 performance replication and the preregistered mixed-cost/load-balance discriminator.

Production admission remains out of scope until thread-safety and live MODFLOW6 coupling are separately qualified.
