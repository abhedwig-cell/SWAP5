# F-PE-ELASTIC71 — post-qualification closure

Date: 2026-09-30

Status: CLOSED_POPULATION_LEVEL_PERFORMANCE_CONFIRMED

Canonical baseline:
`integration/f-ci-canonical@38b78b3415cee0563eb19efa68b73a6082b3c899`

Owning application policy:
F-PE-ELASTIC69.

Qualified population authority:
- branch: `research/f-pe-elastic71-population-multiswap-performance`;
- qualified postimage: `fc59301d6619c9fc0ac1ba645698224104e47301`;
- result document commit: `46271cf2dd2087e896eac09a3513ab8996178f42`;
- workflow run: `36752155963`;
- job: `110013643154`;
- conclusion: SUCCESS.

## Closed claim

The canonically admitted GENERATED ELAS mode-7 application policy with explicit
caller-owned temporal head budget `0.20 cm` has population-level performance
confirmation on a source-frequency-driven 1024-column mineral-soil population.

Selected frozen BRO/BOFEK profiles and allocated benchmark columns:

- 9024010 / Hn21: 363 columns;
- 8060 / zEZ21: 292 columns;
- 9024090 / cHn21: 202 columns;
- 90210030 / pZg23: 167 columns.

Selection was based on descending frozen maparea frequency among eligible
mineral profiles, not on observed runtime.

## Deterministic population result

At `0.01 cm`:

- completed: 962/1024;
- transaction retries: 22,878;
- temporal rejections: 22,930;
- mass rejections: 0;
- solver rejections: 0.

At `0.20 cm`:

- completed: 1024/1024;
- transaction retries: 1,522;
- temporal rejections: 1,522;
- mass rejections: 0;
- solver rejections: 0.

Therefore the admitted application policy:

- restores completion for 62 additional columns within the frozen retry budget;
- removes 21,356 retries;
- reduces retry burden by approximately 93.35%;
- preserves the hard mass gate;
- does not increase solver rejection.

Aggregate deterministic results are identical for 1, 2 and 4 independent
workers.

Classification:

`QUALIFIED_GENERATED_MODE7_0P20_POPULATION_PERFORMANCE_CONFIRMED`.

## Timing interpretation

Shared-CI timing is supporting evidence only.

Observed `0.20 / 0.01` wall-time ratios:

- 1 worker: about 0.211;
- 2 workers: about 0.247;
- 4 workers: about 0.326.

This corresponds to substantially lower wall time in the bounded benchmark,
but it is not a universal whole-SWAP or MultiSWAP speedup claim.

The 0.20-cm arm scaled best from 1 to 2 workers in this small benchmark.
At 4 independent worker processes, process/scheduling overhead became visible
because the remaining per-column work was already much smaller.

## Runtime boundary

This workunit deliberately used independent worker processes.

The existing admitted OpenMP MultiSWAP worker participant belongs to the
groundwater/bottom-mode-5 coupling route. Reusing it for bottom_mode=7 solely
for timing would change the semantic route.

Therefore ELASTIC71 establishes:

- source-weighted population benefit;
- deterministic worker-count independence;
- coarse parallel scalability;
- no mass or solver regression.

It does not establish final in-process mode-7 MultiSWAP OpenMP scaling.

## Closure

F-PE-ELASTIC71 is closed.

The temporal-budget question is not reopened.

If further work is useful, the next bounded implementation task is a generic
in-process worker/batch execution seam for non-groundwater mode-7 columns,
followed by repeating this exact frozen population benchmark through that
admitted runtime.
