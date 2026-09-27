# F-PE-MULTI02 P2 preregistration — mixed-cost load-balance discriminator

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-MULTI02 P1`

## Trigger

P0 and P1 established that worker-local backend execution:

- preserves q and tangent exactly on the measured homogeneous workload;
- preserves the discrete retry/nonlinear route exactly;
- reaches 1.89x on 2 workers and 2.36x on 4 workers at N=1,000.

The remaining scalability risk is workload heterogeneity.

## Primary question

Does deterministic static worker assignment retain useful speedup when tile costs differ materially, or does difficult-column clustering dominate makespan?

## Frozen comparison

Use the same worker-local participant architecture and numerical policy as P0/P1.

Compare:

1. homogeneous authority population;
2. deterministic mixed-cost population with repeatable easy/moderate/difficult tile classes;
3. identical mixed population under at least two deterministic input orderings.

No physics or numerical-policy change may be introduced merely to create favorable timing.

## Required evidence

For each worker count 1, 2 and 4 report:

- total runtime;
- speedup;
- efficiency;
- per-worker assigned tile count;
- per-worker aggregate attempts;
- per-worker aggregate nonlinear iterations;
- per-worker aggregate backtracking attempts;
- max/mean worker work ratio;
- q/tangent identity versus serial authority;
- aggregate attempts/retries/rejections.

## Gates

Semantic identity remains mandatory.

If 4-worker speedup on the mixed population remains >=2.2x and max/mean worker-work ratio <=1.20, advance directly to application-context integration.

If semantic identity passes but either condition fails, select load-balancing/scheduling as the immediate successor before application-context production shaping.

Do not change c=0.65, BALTOL02, A2C, tangent mathematics, retry policy or publication order.

## Scope

Research-only. No production `src/**` change.
