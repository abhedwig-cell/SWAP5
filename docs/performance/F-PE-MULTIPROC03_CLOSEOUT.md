# F-PE-MULTIPROC03 closeout — compact worker dispatch

Date: 2026-09-27

Status: `CLOSED_REJECTED_SELECT_PERSISTENT_PROCESS_DECOMPOSITION`

PR:
`#673 — F-PE-MULTIPROC03: compact worker dispatch qualification`

## Decision

Compact worker dispatch does not explain or materially repair the large-N 1x4 deficit.

Measured steady-state gain:
- N=1,000: -1.1%;
- N=10,000: -0.65%;
- N=40,000: +0.57%.

Semantic identity passed.

The candidate fails the frozen N=10,000 and N=40,000 performance gates and is rejected.

## New discriminator

The paired measurement reveals that persistent 1x4 trial execution is much cheaper than the process-launch wall time used by MULTIPROC01/02.

Therefore the immediate next question is whether process partitioning remains advantageous after all application contexts are persistent and initialized.

Select:
`F-PE-MULTIPROC04 — persistent-process steady-state decomposition`

No production `src/**` change is authorized.

## Closure

`CLOSED_REJECTED_SELECT_PERSISTENT_PROCESS_DECOMPOSITION`
