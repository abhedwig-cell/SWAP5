# F-PE-MULTIPROC03 P0 result — compact worker dispatch

Date: 2026-09-27

Status: `P0_COMPACT_DISPATCH_REJECTED`

PR:
`#673 — F-PE-MULTIPROC03: compact worker dispatch qualification`

Measured head:
`6cb7d0ad155be3406389f134d651efae1151dc58`

Workflow run:
`36349714345`

## Candidate

The candidate preserved the existing scheduler decision and owner mapping, but compacted owned tile indices into per-worker ranges so each worker visited only its assigned tiles.

No production source was changed; P0 used temporary compiled source copies.

## Results

### N=1,000

- baseline: 0.038087834 s;
- compact: 0.038511927 s;
- speedup: 0.988988x;
- candidate regression: about 1.11%;
- frozen no-regression gate: PASS.

### N=10,000

- baseline: 0.379892109 s;
- compact: 0.382364944 s;
- speedup: 0.993533x;
- frozen >=1.10x gate: FAIL.

### N=40,000

- baseline: 1.538145212 s;
- compact: 1.529358296 s;
- speedup: 1.005745x;
- frozen >=1.20x gate: FAIL.

q and tangent checksums were identical in every paired comparison.

## Interpretation

The repeated full-population owner scan is not the source of the large MULTIPROC01/MULTIPROC02 process-partitioning advantage.

Compact dispatch changes steady-state 1x4 trial runtime by approximately zero to one percent across the measured N ladder.

A second observation is more important.

MULTIPROC02 measured N=40,000 1x4 elapsed time of 7.384 s because the multi-process orchestration clock started before each subprocess initialized its application context, performed warm-up, executed the measured trial and exited.

The paired MULTIPROC03 process, after initialization and warm-up, measures the actual repeated 1x4 trial at about 1.538 s.

Therefore a large fraction of the earlier N-dependent process advantage may arise from parallelizing per-process initialization / application-context construction rather than from faster persistent steady-state physical trial execution.

This does not invalidate MULTIPROC01 as an end-to-end process-launch throughput measurement, but it limits the earlier inference that multiple processes necessarily accelerate a long-lived production application context.

## Decision

Reject compact dispatch as a production performance mechanism.

Select:
`F-PE-MULTIPROC04 — persistent-process steady-state decomposition`

The successor must isolate:
- one-time process/application-context initialization;
- warm-up;
- persistent repeated trial execution;
- process-partitioned persistent execution.

The central comparison must be steady-state 1x4 versus persistent 2x2 and 4x1 after all processes are initialized and ready.

