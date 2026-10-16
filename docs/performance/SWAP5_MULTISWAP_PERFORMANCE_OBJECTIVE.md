# SWAP5 / MultiSWAP performance objective

Date: 2026-09-30

Status: PROPOSED_CANONICAL_OBJECTIVE

Baseline:
`integration/f-ci-canonical@cd2929e0cee9520b3af740ab254c6ed61a1eca08`

## Objective

The performance objective for SWAP5 / MultiSWAP is:

> Minimize physically necessary compute work per column while preserving hard
> mass accounting and application-relevant accuracy, and use parallel workers
> only when the remaining workload is large enough for parallel overhead to pay
> back.

The objective is not:

- maximize worker count;
- obtain linear speedup with core count;
- force one universal temporal accuracy target;
- preserve research-oracle tolerances as production requirements.

## Priority order

Performance work follows this order:

1. remove unnecessary physical/numerical work;
2. use an application-owned accuracy/temporal policy;
3. preserve hard mass independently of practical accuracy policy;
4. reduce retry/refinement work;
5. only then scale remaining work across workers;
6. choose worker count from workload characteristics rather than assuming more
   workers are faster.

## Established evidence

### Practical temporal policy

For the bounded GENERATED ELAS + mode-7 application profile:

- explicit caller-owned temporal head budget: `0.20 cm`;
- bottom_mode=7;
- swkimpl=0;
- admitted temporal history;
- hard mass unchanged.

This policy is application-owned and is not a generic SWAP default.

### Retry reduction

The frozen 1024-column GENERATED-ELAS population reduced transaction retries
from:

- 22,878 at the strict 0.01 cm research benchmark
- to 1,522 at the admitted 0.20 cm application policy.

Completion improved from 962/1024 to 1024/1024 in that bounded population.

### Worker semantics

The generic in-process worker pool is admitted for the bounded
GENERATED-ELAS/mode-7/temporal-history profile.

Worker counts 1, 2 and 4 preserve deterministic transaction, commit and mass
semantics in the qualified scope.

### Worker scaling

More workers are not automatically faster.

For the 1024-column source-weighted population after retry reduction:

- 1 worker was fastest;
- 2 workers were slightly slower;
- 4 workers were materially slower.

For the heavier profile-8016 workload, 2 workers outperformed 1 and 4 workers
even at N=256.

Therefore column count alone is not a valid worker-count policy.

### Scheduler research

F-PE-SCHED01:

`SIZE_ONLY_WORKER_COUNT_POLICY_FALSIFIED`.

F-PE-SCHED02:

lagged committed solver work remains a plausible scheduling abstraction, but
qualification was blocked by a localized pZg23 second-interval solvability
hole.

No automatic mode-7 worker-count selector is admitted.

Worker count therefore remains explicit application/runtime policy.

## Localized pZg23 blocker

The PZG23-01..06 attribution chain localized one calibration blocker to:

- profile 90210030 / pZg23;
- h0=+2 cm;
- positive forcing +0.035 and +0.050 cm/day;
- second accepted-state interval.

The blocker is:

`QUALIFIED_PZG23_MULTI_CRITERION_LOCAL_NONLINEAR_BLOCKER`.

It is not:

- worker/OpenMP related;
- hard-mass related;
- temporal-history content;
- hidden solver scratch;
- fixed by increasing MaxIt;
- primarily fixed by increasing MaxBackTr;
- a near-threshold single-tolerance problem.

No production repair is justified solely to complete scheduler calibration.

## Production decision rules

### Accuracy

Application-relevant error budgets may be looser than strict research-oracle
bounds when supported by qualified evidence.

Strict research tolerances must not silently become production requirements.

### Mass

Hard physical mass accounting is independent of practical accuracy policy and
must not be relaxed for performance.

### Temporal work

Prefer fewer accepted-state retries/refinements when application accuracy and
hard mass remain qualified.

### Parallelism

Worker count is a runtime scheduling choice, not a physics parameter.

Do not assume:

`workers = available cores`.

Prefer the smallest worker count that achieves near-best throughput for the
current workload.

### Scheduler admission

Do not admit an adaptive worker-count selector until it is qualified on a
common production-valid domain.

Do not remove difficult profiles from the evidence set merely to obtain a clean
scheduler fit.

## Geometry boundary

The current legacy Richards closure still owns MOD_grid at compile time.

Different BOFEK geometries therefore remain separate geometry-homogeneous
profile batches for qualified in-process mode-7 execution.

Heterogeneous geometry in one runtime registry is not yet qualified.

## Performance roadmap

Further work is justified when it addresses one of these application-scale
questions:

1. production-scale throughput on substantially larger column populations;
2. more expensive physical process combinations where worker parallelism may
   pay back;
3. runtime-owned heterogeneous geometry if it becomes a material batching
   bottleneck;
4. adaptive worker selection only after a common valid calibration domain is
   available;
5. end-to-end MultiSWAP/MODFLOW performance on the actual coupled production
   route.

Do not reopen:

- strict 0.01 cm oracle completion;
- wider temporal-budget scans without application evidence;
- pZg23 local solver tuning solely for scheduler calibration;
- small synthetic worker-count sweeps without a production decision attached.

## Success criterion

The intended outcome is not a fixed speedup factor.

SWAP5/MultiSWAP is successful when:

- per-column solve work is minimized within the admitted application accuracy
  envelope;
- hard mass remains exact under the canonical acceptance policy;
- runtime overhead is small relative to useful physical work;
- worker count is selected conservatively from workload characteristics;
- large applications achieve throughput sufficient for practical regional and
  coupled use without requiring a separate surrogate system solely for speed.

## Current decision

The current bounded production direction is:

- keep the 0.20 cm GENERATED-ELAS mode-7 application policy;
- keep hard mass unchanged;
- keep explicit worker-count ownership;
- use one worker for small/cheap profile batches unless application evidence
  supports more;
- use 2 workers for heavier profile classes only when measured/qualified;
- defer automatic worker selection;
- move future performance work to application-scale evidence rather than
  further local micro-tuning.
