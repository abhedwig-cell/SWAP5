# F-PE-SCHED01 — post-qualification closure

Date: 2026-09-30

Status: CLOSED_SIZE_ONLY_WORKER_POLICY_FALSIFIED

Canonical baseline:
`integration/f-ci-canonical@a9bf62afd08b30087c3385709f94e4143d9de006`

Qualified research authority:
- branch: `research/f-pe-sched01-worker-count-threshold`;
- qualified postimage: `841a22d57aa82068e38e5167827c9b7cfe839ad4`;
- result document commit: `789d1f7ec1e65dbcca233cda794f57016ca83cce`;
- workflow run: `36758008783`;
- job: `110033084079`;
- conclusion: SUCCESS.

## Closed result

A worker-count policy based only on the number of columns is not supported.

On exact generated profile 8016, the preregistered 1/2/4-worker size sweep
selected 2 workers at every tested population size:

- N=256;
- N=1024;
- N=4096;
- N=16384.

No 1->2 or 2->4 size transition was observed.

At the same time, F-PE-MULTI07 had already shown that cheaper source-weighted
profile batches of 167..363 columns were fastest with 1 worker.

Therefore column count alone cannot explain the worker optimum.

Classification:

`SIZE_ONLY_WORKER_COUNT_POLICY_FALSIFIED`.

## Preserved semantics

Across all SCHED01 worker-count comparisons:

- completed and committed counts remained exact;
- retry counts remained worker-count invariant;
- mass failures remained zero;
- aggregate mass publication remained complete;
- multiworker physical concurrency was observed;
- no production source changed.

## Design consequence

Worker-count selection must depend on predicted physical work, not only N.

A qualified successor may use immutable pre-trial cost information, consistent
with the already qualified MULTI03/MULTI04 cost-aware scheduling architecture.

It must not use post-trial outcomes from the same interval to choose that
interval's worker count.

## Closure

F-PE-SCHED01 is closed.

Do not introduce N-only worker thresholds into production.

The next bounded research question is F-PE-SCHED02: aggregate immutable
pre-trial cost -> worker-count selection.
