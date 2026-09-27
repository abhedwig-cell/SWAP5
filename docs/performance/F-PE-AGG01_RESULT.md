# F-PE-AGG01 result — reusable groundwater aggregation buffer

Date: 2026-09-27

Status: `CLOSED_REJECTED_LOW_RUNTIME_GAIN`

PR:
`#685 — F-PE-AGG01: reusable groundwater aggregation buffer`

Measured head:
`906831c6677b9d5c445ee56b148964619bd08c97`

Workflow run:
`36353632432`

## Candidate

Replace per-cell allocate/populate/aggregate/deallocate with one reusable temporary exchange buffer per `trial_cell_heads` call, while keeping `aggregate_groundwater_cell_tiles` unchanged.

## Results

### N=1,000

- worker=1 speedup: 1.164x;
- worker=4 speedup: 0.997x;
- no-regression gate: PASS.

### N=10,000

- worker=1 speedup: 0.983x;
- worker=4 speedup: 0.996x;
- frozen >=1.05x worker=4 gate: FAIL.

### N=40,000

- worker=1 speedup: 1.006x;
- worker=4 speedup: 1.008x;
- frozen >=1.10x worker=4 gate: FAIL.

q and tangent checksums were exact in every paired comparison.

## Interpretation

Repeated per-cell heap allocation is not a material limiter of the current 4-worker production-shaped trial path.

The candidate changes large-N worker=4 runtime by less than 1%.

## Decision

Reject the reusable aggregation-buffer candidate as a production performance mechanism.

Do not production-admit this change from AGG01 evidence.
