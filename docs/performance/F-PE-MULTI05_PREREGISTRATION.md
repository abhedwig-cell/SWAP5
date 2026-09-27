# F-PE-MULTI05 — high-core-count production-groundwater scaling

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Canonical parent:
`integration/f-ci-canonical@4ee57d17a3793a58c792d5de9cdd0a38f9e7918a`

Parent production authority:
`F-PE-MULTI04 / PR #666`

Branch:
`work/f-pe-multi05-high-core-scaling`

## Purpose

Measure how far the admitted worker-local production-groundwater architecture scales beyond the currently admitted 1/2/4-worker envelope.

The primary question is system throughput, not another single-column optimization:

> for sufficiently large independent MultiSWAP populations, how does production-shaped SWAP throughput scale as available CPU concurrency increases?

## Research boundary

MULTI04 production policy remains unchanged:
- default workers = 1;
- production-admitted parallel worker counts remain 2 and 4 only;
- unsupported production worker counts continue to fail closed.

MULTI05 may exercise 8/12/16/24 workers only through a research-only build seam that widens the worker-count guard in temporary compiled copies. No `src/**` production change is authorized by this workunit.

The research seam must not change:
- Richards equations;
- temporal c=0.65 policy;
- BALTOL02;
- retry scale;
- nonlinear tolerances;
- tangent mathematics;
- candidate/origin ownership;
- canonical result ordering;
- MODFLOW equations.

## Host classification

Every measurement must record at least:
- OS runner identity;
- logical CPU count visible to the process;
- `OMP_NUM_THREADS` / requested worker count;
- whether requested workers <= visible logical CPUs;
- whether the point is oversubscribed.

A point with more workers than visible logical CPUs is **not** evidence for high-core scaling. It is retained only as oversubscription evidence.

Do not claim 8/12/16/24-core scaling from a standard runner unless those CPUs are actually available to the process.

## P0 baseline and scale sweep

Production-shaped application-context workload derived from MULTI04 P1C.

Target population sizes:
- N=1,000;
- N=10,000;
- N=100,000 where runtime/memory permits.

Requested workers:
- 1;
- 2;
- 4;
- 8;
- 12;
- 16;
- 24.

For each valid point measure replicated median:
- wall-clock trial time;
- speedup versus worker=1 at the same N;
- parallel efficiency = speedup / workers;
- throughput in columns/s;
- exact q checksum;
- exact tangent checksum.

The 1/2/4 points must reproduce the production-admitted semantics and remain compatible with MULTI04 evidence.

## P0 semantics gate

For every research worker count that completes:
- q checksum must equal the worker=1 checksum;
- tangent checksum must equal worker=1;
- repeated output must be deterministic within the fixture;
- no candidate/state leakage is allowed.

Any semantic mismatch closes the high-worker candidate before performance interpretation.

## P0 interpretation gates

MULTI05 is initially characterization, not production admission.

Classify scaling using the largest non-oversubscribed N that completes:

- `STRONG_SCALE`: efficiency >=0.70;
- `USEFUL_SCALE`: efficiency >=0.50 and <0.70;
- `WEAK_SCALE`: efficiency >=0.30 and <0.50;
- `SATURATED`: efficiency <0.30.

These are research classifications, not production acceptance thresholds.

Also report marginal gain from each doubling/increment. A higher worker count that is slower than a lower count is retained as negative evidence.

## P1 successor decision

Exactly one successor is selected from P0 evidence.

### If scaling remains useful through the highest real-core count

Select:
`F-PE-MULTI06 — production admission of extended worker counts`

provided semantic identity is clean.

### If scaling bends materially before available cores are exhausted

Select:
`F-PE-MULTI06 — worker/runtime efficiency decomposition`

and decompose:
- idle fraction/load imbalance;
- OpenMP scheduling overhead;
- batch/grain size;
- memory bandwidth/cache pressure;
- worker-local state footprint;
- synchronization;
- first-touch / affinity where measurable.

### If oversubscription improves throughput after physical/logical CPU saturation

Retain this as an explicit result and open a bounded oversubscription qualification. Do not infer it in advance.

### If high-core evidence cannot be obtained on available CI hardware

Close CI P0 as `HOST_CAPACITY_BLOCKED`, preserve the harness, and move the same frozen experiment to a known high-core execution host. Do not substitute oversubscribed CI numbers for real-core scaling.

## Large-N requirement

The primary production question concerns many-column workloads. Small-N overhead is not allowed to veto scaling that appears only after sufficient amortization.

N=100,000 is the target production-scale discriminator. If it is too expensive on CI, N=10,000 is the minimum useful high-core characterization population, and the reason for not reaching N=100,000 must be recorded.

## No precommitted conclusion

The workunit does not assume:
- linear scaling;
- that workers should equal hardware threads;
- that oversubscription helps;
- that OpenMP is the eventual production mechanism.

The measured curve decides the successor.
