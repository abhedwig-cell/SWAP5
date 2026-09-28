# F-PE-SYSTEM-CLOSE01 — current-host performance frontier closeout

Date: 2026-09-27

Status: `CLOSED_CURRENT_HOST_PERFORMANCE_FRONTIER`

Initial closeout base:
`integration/f-ci-canonical@3632b652a8e493b85b895336d3d9bfbddfa06410`

Reconciliation note, 2026-09-28:
TEMPORAL10 had already qualified one >=5% current-host mechanism when this closeout was merged. F-PE-TEMPORAL11 subsequently completed its production admission evidence and must be included in the final frontier state. The broad search remains closed after that bounded successor is admitted.

## Purpose

Close the current SWAP5 performance search on the available 2-physical-core / 4-logical-CPU GitHub execution host.

This closeout does not claim that SWAP5 cannot scale further on larger hardware.

It records which performance routes have been:
- production-admitted;
- empirically rejected;
- or blocked only by unavailable high-core hardware.

## Admitted gains

### Single-column / exact trial path

The exact single-column line is already closed separately by:
`F-PE-COLUMN-CLOSE01 / PR #669`.

The remaining measured exact per-column candidates had crossed into low expected return.

### Temporal / coupling trial efficiency

Current production includes the qualified history-aware temporal budget and associated exact coupling improvements.

F-PE-TEMPORAL11 production-admits demand-directed constitutive evaluation inside the exact temporal certificate. TEMPORAL10 measured approximately 5.0% worker=4 end-to-end gain at N=10,000 and N=40,000, with exact q/tangent preservation. TEMPORAL11 adds direct-retention certificate equivalence and FSI38 independent-oracle preservation before admission.

### Worker-local MultiSWAP parallel execution

F-PE-MULTI04 production-admitted worker-local groundwater parallel execution.

Representative N=1,000 evidence on the admitted path:
- 2 workers approximately 1.96x;
- 4 workers approximately 2.6x on later preservation runs;
- exact q/tangent identity preserved.

This is the principal steady-state throughput mechanism on the current host.

### Large-N bootstrap

F-PE-SETUP04 / PR #681 removed the dominant quadratic production bootstrap pathology.

Paired production-candidate app-initialize speedups:
- N=1,000: about 1.45x;
- N=10,000: about 6.42x;
- N=40,000: about 32.01x.

At N=40,000:
- canonical baseline app initialize: about 3.59 s;
- admitted candidate: about 0.112 s.

Post-admission SETUP05 showed no second non-physical setup family meeting the preregistered successor threshold.

## High-core scaling: open, not rejected

F-PE-MULTI05 established the high-worker harness.

The available GitHub host exposed:
- 2 physical cores;
- 4 logical CPUs.

Valid evidence:
- 2 workers: near-ideal scaling;
- 4 workers: useful scaling.

Requested 8/12/16/24-worker measurements were oversubscribed and therefore do not answer the real high-core question.

Oversubscription beyond the four visible hardware threads provided no benefit.

Decision:
`HOST_CAPACITY_BLOCKED`.

A trusted self-hosted high-core workflow is prepared for a future machine with label:
`swap5-highcore`.

## Rejected current-host routes

### Multi-process partitioning

Fresh-process measurements initially showed large apparent gains.

Persistent-process decomposition established that the gain came primarily from parallelized setup/context construction.

After initialization:
- persistent 1x4 was equivalent to or slightly faster than 2x2 / 4x1.

SETUP04 subsequently removed the underlying setup pathology.

Decision:
do not adopt multi-process partitioning as the primary steady-state runtime architecture from current evidence.

### Conductivity table / constitutive representation

HYDTABLE01:
- microkernel-positive;
- solver-level approximately 3% slower.

Rejected.

### Exact base-solve micro-optimization

BASE01 selected candidate:
- total q/state trial gain about 2.60%;
- failed composed preregistered gate.

Rejected.

### Compiler / code generation

CODEGEN01:
- O3 slightly slower than O2;
- O3 + march=native about 1% worker=4 gain;
- native + LTO below 1% worker=4 gain.

No candidate met the 5% gate.

### Aggregation allocation

AGG01 reusable exchange buffer:
- N=40,000 worker=4 gain about 0.8%;
- N=10,000 essentially neutral.

Rejected as low return.

### Persistent trial scratch

SCRATCH01:
- N=10,000 worker=4 gain about 4.8%;
- N=40,000 effectively zero.

Failed frozen large-N gates.

### Captured-origin schedule cache

SCHEDCACHE01:
- N=10,000 about 0.3% gain;
- N=40,000 about 0.7% slower.

Rejected.

### OpenMP placement / affinity

AFFINITY01 on the 2-core / 4-thread AMD EPYC runner:
- DEFAULT was the fastest measured worker=4 configuration;
- explicit spread/close placement on threads or cores was approximately 1.6-3.7% slower.

No runtime placement policy is selected.

## Current interpretation

On the currently available host:
- the major bootstrap pathology has been removed;
- the admitted worker-local runtime remains the main throughput mechanism;
- additional compiler, allocation, schedule-cache and affinity changes are below material thresholds;
- the one remaining qualified >=5% temporal constitutive mechanism has been carried through production admission by F-PE-TEMPORAL11;
- single-column exact optimization is already closed as low-return.

The current 4-logical-CPU performance frontier is therefore mature enough to close.

## Reopen conditions

Do not open another broad performance workunit from a local micro-hotspot alone.

Reopen the system-performance line when at least one of the following occurs:

1. a host with >=8 real/logical CPUs becomes available for the frozen MULTI05 high-core experiment;
2. a production-shaped N=100,000+ run exposes a new component owning >=10% of end-to-end wall time;
3. a real coupled MODFLOW/Ribasim workflow materially changes trial/retry/runtime composition;
4. production input or process scope changes enough that the present workload is no longer representative;
5. a new mechanism demonstrates >=5% end-to-end current-host gain or >=10% large-host gain on preregistered evidence without changing required semantics.

## Next performance action when hardware becomes available

Run the frozen high-core sweep:
- N=10,000 first;
- worker counts 1/2/4/8/12/16/24 up to visible hardware concurrency;
- then N=100,000 if resource use is acceptable.

The result should decide between:
- extended worker-count production admission;
- or worker/runtime efficiency decomposition at the point where real-core scaling bends.

## Production boundary

This closeout is documentation/governance only.

No source, physics, solver, tolerance, temporal, tangent, worker scheduling, MODFLOW, transaction, mass or publication semantics change.

## Final decision

`CLOSED_CURRENT_HOST_PERFORMANCE_FRONTIER`

Remaining high-core scaling is parked as an external-hardware dependency, not closed as a negative result.
