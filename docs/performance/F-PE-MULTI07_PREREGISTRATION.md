# F-PE-MULTI07 — production MultiSWAP scaling frontier

Date: 2026-10-01

Status: PREREGISTERED_RESEARCH

Issue: #668

Baseline:
`integration/f-ci-canonical@81b7feda17f53a94ab4e5877467cc4499de6f568`

Branch:
`research/f-pe-multi07-production-scaling-frontier`

## Purpose

Determine the production-relevant scaling frontier of the already admitted
worker-local MultiSWAP architecture. The work unit must explain where scaling
stops paying back rather than merely report a speedup at one worker count.

This is performance research. It does not change physics, mass policy,
transaction semantics, temporal policy, or coupling ownership.

## Prior authority

F-PE-MULTI04 admitted bounded worker-local groundwater execution for worker
counts 2 and 4 and established exact deterministic result semantics.

F-PE-MULTI06 is already assigned to GENERATED ELAS mode-7 worker-pool
admission and is not reused here.

The current MultiSWAP performance objective explicitly states that more workers
are not automatically faster and that future work should move to
application-scale evidence.

## Research questions

For a fixed qualified workload:

1. How does wall-clock throughput scale with worker count?
2. Where is the saturation point on the tested host?
3. Does oversubscription ever improve throughput?
4. How much scaling loss is attributable to load imbalance versus runtime
   overhead?
5. Does deterministic dynamic/cost-aware scheduling materially outperform
   static scheduling for heterogeneous workloads?
6. How different is isolated MultiSWAP scaling from end-to-end
   MultiSWAP/MODFLOW scaling?

## Phase A — benchmark qualification

Before any scaling claim:

- pin exact code commit and compiler/runtime environment;
- record physical and logical core counts;
- record worker count, affinity/pinning policy and repeat/warm-up policy;
- use a timed region that excludes setup/I/O where appropriate and names what
  is excluded;
- prove worker-count identity under the existing qualified result/mass
  semantics;
- make the workload large enough that measurement/scheduling setup is not the
  dominant cost.

No GitHub-hosted runner may establish a portable production scaling frontier.
CI may be used for correctness/preservation only.

## Phase B — isolated MultiSWAP scaling

Use two workload classes:

### B1 homogeneous

A geometry-homogeneous, production-valid profile population intended to expose
parallel execution overhead without deliberate load imbalance.

### B2 heterogeneous-cost

A production-valid population with materially different per-column solve work.
Where geometry ownership prevents a mixed in-process registry, heterogeneity
must remain within the admitted geometry boundary or be represented as
separate production-valid batches. Do not bypass the geometry contract for the
benchmark.

Worker sweep:

- always include 1, 2 and 4;
- extend through available physical/logical cores on the measurement host;
- include at least two oversubscribed points when the host permits it.

For each point report at minimum:

- median wall-clock runtime over repeated runs;
- speedup relative to worker 1;
- parallel efficiency;
- throughput;
- worker busy/idle distribution where observable;
- max/mean worker load;
- retry/solver-work totals needed to prove workload identity.

## Phase C — scheduling attribution

Compare the admitted deterministic static and cost-aware/dynamic scheduling
routes where both are valid for the same workload.

A scheduling benefit may be claimed only if solver work and accepted physical
results are identical and the runtime difference survives repeat measurement.

## Phase D — coupled route

Only after isolated scaling is qualified, repeat a bounded worker sweep on the
actual MultiSWAP/MODFLOW production route.

Attribute the difference between isolated and coupled scaling to named
categories where evidence permits: SWAP compute, scheduling, synchronization,
publication/serialization, and MODFLOW/coupler work.

## Decision outputs

The result must provide host-scoped decisions, not a universal worker count:

- smallest worker count within 5% of best observed median throughput;
- observed saturation point;
- whether oversubscription is useful on the tested host/workload;
- whether cost-aware/dynamic scheduling pays back;
- isolated versus coupled scaling loss.

The 5% band is a decision rule for selecting the conservative near-best worker
count. It is not a physics or admission tolerance.

## Falsification criteria

The following are valid negative results:

- additional workers do not improve production throughput;
- oversubscription is consistently neutral or harmful;
- dynamic/cost-aware scheduling overhead exceeds its load-balance benefit;
- host variability prevents a stable ordering;
- coupled serial/synchronization work dominates enough that isolated scaling
  does not translate end-to-end.

Such outcomes are to be persisted, not tuned away.

## Stop conditions

Stop with a blocker rather than broaden scope if:

- qualified worker-count result/mass identity fails;
- the benchmark requires changing physics or numerical tolerances;
- geometry ownership must be violated;
- no suitable host with enough independently usable cores is available for the
  requested frontier;
- runtime noise prevents reproducible ordering after the preregistered repeat
  strategy.

## Non-goals

- no automatic worker-count selector in this work unit;
- no pZg23 solver repair;
- no reopening of the strict 0.01 cm research oracle;
- no claim that one host's optimum is portable to another host;
- no production admission based only on GitHub-hosted CI timing.
