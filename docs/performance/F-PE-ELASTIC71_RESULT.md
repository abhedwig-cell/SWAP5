# F-PE-ELASTIC71 — population-level GENERATED mode-7 MultiSWAP performance result

Date: 2026-09-30

Status: QUALIFIED_POPULATION_LEVEL_PERFORMANCE_CONFIRMATION

Branch:
`research/f-pe-elastic71-population-multiswap-performance`

Qualified postimage:
`fc59301d6619c9fc0ac1ba645698224104e47301`

Canonical baseline:
`integration/f-ci-canonical@38b78b3415cee0563eb19efa68b73a6082b3c899`

Workflow run:
`36752155963`

Job:
`110013643154`

Conclusion:
SUCCESS.

## Source-weighted population

The population was selected before timing from the frozen BRO/BOFEK
`soilarea_normalsoilprofile` relation.

The four most frequent eligible mineral profiles were:

| profile | soil unit | source mapareas | benchmark columns |
| --- | --- | ---: | ---: |
| 9024010 | Hn21 | 1990 | 363 |
| 8060 | zEZ21 | 1597 | 292 |
| 9024090 | cHn21 | 1106 | 202 |
| 90210030 | pZg23 | 917 | 167 |

Total:
`1024` logical columns.

Each profile used its exact frozen geometry, Staringreeks retention and
GENERATED ELAS parameter preparation. Within each profile population, the
columns cycled deterministically over four initial pressure heads and four
forcing perturbations.

## Deterministic result

### Strict 0.01 cm benchmark

- completed: `962 / 1024`;
- exhausted/non-complete within the frozen retry budget: `62`;
- transaction retries: `22,878`;
- temporal rejections: `22,930`;
- mass rejections: `0`;
- solver rejections: `0`.

### Admitted 0.20 cm application policy

- completed: `1024 / 1024`;
- exhausted/non-complete: `0`;
- transaction retries: `1,522`;
- temporal rejections: `1,522`;
- mass rejections: `0`;
- solver rejections: `0`.

The 0.20-cm arm therefore:

- restores completion for 62 additional columns;
- reduces transaction retries by `21,356`;
- reduces retry count by approximately `93.35%`;
- preserves zero mass rejections;
- preserves zero solver rejections.

Aggregate deterministic counts were identical with 1, 2 and 4 independent
workers.

## Accepted-step distribution

For 0.01 cm, accepted columns are distributed far down the refinement ladder,
including 211 accepts at the eighth bin and 228 at the ninth bin.

For 0.20 cm, 523 columns accept the initial 0.015625-day interval, with most of
the remaining accepted columns concentrated in the third and fourth bins. No
columns require the deep eighth/ninth refinement bins used by the strict arm.

This is consistent with the mechanism identified in ELASTIC70: the practical
budget removes repeated temporal rejection rather than changing hard mass or
solver convergence policy.

## Timing

Timing was measured on shared GitHub Actions infrastructure and is descriptive,
not a portable benchmark.

### 0.01 cm

| workers | wall time s | throughput columns/s | worker speedup |
| ---: | ---: | ---: | ---: |
| 1 | 0.33293 | 3,075.7 | 1.00 |
| 2 | 0.15777 | 6,490.6 | 2.11 |
| 4 | 0.13997 | 7,316.0 | 2.38 |

### 0.20 cm

| workers | wall time s | throughput columns/s | worker speedup |
| ---: | ---: | ---: | ---: |
| 1 | 0.07024 | 14,577.9 | 1.00 |
| 2 | 0.03902 | 26,241.7 | 1.80 |
| 4 | 0.04556 | 22,473.5 | 1.54 |

Policy wall-time ratio, `0.20 / 0.01`:

- 1 worker: `0.211`;
- 2 workers: `0.247`;
- 4 workers: `0.326`.

Thus the faster policy is between roughly 67% and 79% lower wall time in this
bounded shared-CI population benchmark.

The 4-worker 0.20-cm timing is slower than its 2-worker timing. This is not a
physical or solver regression: deterministic outputs are identical. It shows
that once transaction work is strongly reduced, independent process startup
and scheduling overhead becomes material for this small 1024-column benchmark.

## Worker interpretation

The worker experiment deliberately uses independent processes rather than the
existing groundwater OpenMP participant executor.

Reason:

- the admitted OpenMP MultiSWAP participant route currently belongs to the
  groundwater/bottom-mode-5 coupling contract;
- this workunit qualifies bottom_mode=7;
- reusing or modifying the mode-5 participant solely to obtain a thread timing
  would change the semantics under test.

Therefore the worker result establishes:

- independent profile-specific execution is parallelizable;
- deterministic aggregate semantics do not depend on worker count;
- coarse population throughput improves from one to two workers;
- process overhead limits the small fast-policy benchmark at four workers.

It does not yet establish final in-process mode-7 MultiSWAP OpenMP scaling.

## Decision

Classification:

`QUALIFIED_GENERATED_MODE7_0P20_POPULATION_PERFORMANCE_CONFIRMED`.

The 0.20-cm GENERATED ELAS mode-7 application policy is no longer supported
only by single-profile or direct-scan evidence. On a source-frequency-driven
1024-column mineral-soil population it materially improves both completion and
transaction work while preserving the hard mass and solver gates.

## Scope boundary

This result does not establish:

- national SWAP runtime reduction;
- an exact final MultiSWAP worker scaling factor;
- MODFLOW coupling speedup;
- performance for peat/organic profiles excluded by the GENERATED mineral
  prior policy;
- arbitrary optional-process combinations;
- permission to increase the budget above 0.20 cm.

The next performance question, if pursued, is implementation-oriented:
provide a generic in-process worker/batch execution seam for non-groundwater
mode-7 columns and measure this same frozen population through that admitted
runtime. No further temporal-budget calibration is required.
