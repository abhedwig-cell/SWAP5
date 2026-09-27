# F-PE-MULTIPROC04 closeout — persistent-process steady-state decomposition

Date: 2026-09-27

Status: `CLOSED_SETUP_TARGET_SELECTED`

PR:
`#675 — F-PE-MULTIPROC04: persistent-process steady-state decomposition`

## Decision

Persistent 1x4 / 2x2 / 4x1 runtime is equivalent within a few percent at N=10,000 and N=40,000.

The earlier large process-partitioning gain is therefore attributable primarily to setup/application-context construction rather than repeated SWAP trial execution.

At N=40,000:
- 1x4 setup: 3.987 s;
- 2x2 setup: 1.641 s;
- 4x1 setup: 1.264 s;
- persistent trial wall remains about 0.87-0.89 s for all configurations.

## Consequence

Do not production-admit multi-process partitioning as a steady-state runtime optimization.

Select:
`F-PE-SETUP01 — large-N production application-context setup decomposition`

No production `src/**` change is authorized by MULTIPROC04.

## Closure

`CLOSED_SETUP_TARGET_SELECTED`
