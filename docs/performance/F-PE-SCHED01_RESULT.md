# F-PE-SCHED01 — workload-aware mode-7 worker-count threshold result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_SIZE_ONLY_WORKER_SELECTION_RESULT

Branch:
`research/f-pe-sched01-worker-count-threshold`

Qualified postimage:
`841a22d57aa82068e38e5167827c9b7cfe839ad4`

Canonical baseline:
`integration/f-ci-canonical@a9bf62afd08b30087c3385709f94e4143d9de006`

Workflow run:
`36758008783`

Job:
`110033084079`

Conclusion:
SUCCESS.

## Question

Can the already admitted GENERATED ELAS + mode-7 worker pool choose between
1, 2 and 4 workers from population size alone?

## Frozen profile and policy

The exact MULTI06 profile-8016 authority was reused:

- BOFEK/BRO profile 8016 / EZg21;
- exact 16-node geometry;
- exact Staringreeks retention;
- GENERATED ELAS;
- bottom_mode = 7;
- swkimpl = 0;
- RICHARDS_TEMPORAL_HISTORY;
- explicit caller-owned head budget = 0.20 cm;
- initial interval = 0.015625 day;
- max retries = 8.

Within every population the same sixteen h0/forcing combinations were repeated
deterministically.

## Size sweep

Five repeated in-process timings were obtained for every combination of:

- N = 256, 1024, 4096, 16384;
- workers = 1, 2, 4.

The median times were:

| N | 1 worker | 2 workers | 4 workers | selected worker |
| ---: | ---: | ---: | ---: | ---: |
| 256 | 0.009515 s | 0.006188 s | 0.006645 s | 2 |
| 1024 | 0.037929 s | 0.024266 s | 0.025613 s | 2 |
| 4096 | 0.151537 s | 0.099291 s | 0.105177 s | 2 |
| 16384 | 0.682565 s | 0.474282 s | 0.495304 s | 2 |

Selection used the preregistered rule:

- find the minimum median time;
- choose the smallest worker count within 5% of that minimum.

All four tested sizes select 2 workers.

## Deterministic correctness

For every N:

- completed columns equal N;
- committed columns equal N;
- retry count is identical for worker counts 1, 2 and 4;
- mass failures = 0;
- rejected columns = 0;
- aggregate mass publication is complete;
- multiworker runs show real physical concurrency.

Frozen retry totals:

- N=256: 368;
- N=1024: 1472;
- N=4096: 5888;
- N=16384: 23552.

Production source delta:
empty.

## Threshold result

The preregistered step-threshold construction produces:

`SCHED01_THRESHOLD_MODEL = NONE`.

There is no observed 1->2 or 2->4 transition inside the tested size range.

More importantly, this result cannot be generalized into a size-only worker
policy because MULTI07 already established the opposite behavior on a cheaper
source-weighted population:

- its profile batches of 167..363 columns were fastest with 1 worker;
- profile 8016 in SCHED01 is already faster with 2 workers at N=256.

Population size therefore does not determine the worker optimum by itself.

## Interpretation

The missing variable is per-column work.

A useful worker selector must include an immutable pre-trial cost measure in
addition to N.

This agrees with the earlier MULTI03/MULTI04 scheduling evidence, where
predecessor-history cost successfully distinguished balanced from adverse
worker assignment.

For worker-count selection, the relevant abstraction is therefore closer to:

`predicted total physical work = sum(pretrial column cost)`

rather than:

`worker count = f(number of columns)`.

## Decision

Classification:

`SIZE_ONLY_WORKER_COUNT_POLICY_FALSIFIED`.

Do not introduce N-only worker thresholds into production.

The qualified successor question is a cost-aware worker-count selector using
only immutable pre-trial information.

## Successor boundary

SCHED02 may investigate worker-count selection from aggregate immutable
pre-trial cost.

It must not:

- use observed post-trial retries to choose workers for that same interval;
- use wall time feedback inside the physical transaction;
- modify physics or temporal budgets;
- reinterpret MULTI03 scheduling cost as a physical state variable;
- force 4-worker use when predicted work does not justify it.
