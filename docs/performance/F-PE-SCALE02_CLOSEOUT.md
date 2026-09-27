# F-PE-SCALE02 closeout — production-scale throughput

Date: 2026-09-27

Status: `CLOSED_CURRENT_4CPU_LARGE_N_FRONTIER`

## Decision

The admitted production-groundwater route remains stable through N=100,000 on the available 4-logical-CPU host once the research-fixture stack limit is removed.

Worker=4 throughput:
- N=10,000: ~34.7k columns/s;
- N=40,000: ~25.3k columns/s;
- N=100,000: ~26.0k columns/s.

The 10k-to-40k transition indicates a cache/working-set effect, but there is no further degradation from 40k to 100k.

No new memory/data-layout optimization is selected.

The current unresolved performance question is high-core-count scaling on hardware with more than four visible logical CPUs.

The standard-stack N=100,000 segfault is classified as a research-fixture stack artifact.

## Closure

`CLOSED_CURRENT_4CPU_LARGE_N_FRONTIER`
