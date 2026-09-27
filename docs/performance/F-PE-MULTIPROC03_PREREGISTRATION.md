# F-PE-MULTIPROC03 — compact worker dispatch qualification

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-MULTIPROC02 / PR #672`

Parent head:
`2574a0adee114b912e3778f88ee0d4b74766e6ae`

Branch:
`work/f-pe-multiproc03-compact-worker-dispatch`

## Trigger

MULTIPROC02 found a strongly size-dependent one-process deficit:
- N=1,000: 2x2 only ~6% faster than 1x4;
- N=10,000: 2x2 ~24% faster;
- N=40,000: 2x2 ~73% faster and 4x1 ~86% faster.

Code inspection identified a concrete mechanism in the parallel application-context path:
each worker scans the complete tile population and filters on `owner(idx)`.

## Candidate

Retain exactly the existing scheduler decision and owner mapping, but compact the owner mapping into per-worker index ranges before entering the OpenMP region.

Frozen requirements:
- static owner mapping unchanged;
- cost-aware owner mapping unchanged;
- static/cost-aware selection threshold unchanged;
- worker-local backend ownership unchanged;
- canonical tile result storage unchanged;
- aggregation/publication order unchanged.

Each worker must visit only indices assigned to it.

## P0 paired qualification

Compare current versus compact dispatch for the same production-shaped 1x4 workload at:
- N=1,000;
- N=10,000;
- N=40,000.

For each N:
- same fixture;
- same 4 workers;
- 5 timing repetitions;
- current and candidate compiled separately from the same head;
- exact q checksum;
- exact tangent checksum;
- deterministic repeated output.

## Performance gates

Candidate advances if:
- semantic identity passes at all N;
- candidate is no more than 2% slower at N=1,000;
- candidate is at least 10% faster at N=10,000;
- candidate is at least 20% faster at N=40,000.

These thresholds are frozen before measurement.

## Interpretation

If the candidate passes, MULTIPROC03 identifies a one-process implementation defect rather than a fundamental need for process partitioning.

If it removes only part of the deficit, retain the gain and continue attribution of the residual process advantage.

If it fails, close compact dispatch and resume cache/working-set attribution.

## Production boundary

P0 uses research-only compiled source copies.
No production `src/**` admission is authorized until paired qualification passes.

No change to physics, tolerances, temporal policy, tangent mathematics, transaction semantics, aggregation or MODFLOW equations.
