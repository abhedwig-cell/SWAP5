# F-PE-MULTIPROC02 P0 result — population-size discriminator

Date: 2026-09-27

Status: `P0_SIZE_DEPENDENT_PROCESS_ADVANTAGE`

PR:
`#672 — F-PE-MULTIPROC02: process-partitioning gain attribution`

Measured head:
`23df7764a79aec63534d1ce24133481e1fa38a46`

Workflow run:
`36349387165`

## Frozen comparison

Same total logical column work on the same 4-logical-CPU host:
- 1x4 = one process, four workers;
- 2x2 = two processes, two workers each;
- 4x1 = four processes, one worker each.

## N ladder

### N=1,000

- 1x4: 0.122491166 s, 8,163.854 columns/s;
- 2x2: 0.115209296 s, 8,679.855 columns/s, 1.063206x versus 1x4;
- 4x1: 0.129925912 s, 7,696.694 columns/s, 0.942777x versus 1x4.

### N=10,000

Inherited MULTIPROC01 authority:
- 1x4: 0.861060493 s, 11,613.586 columns/s;
- 2x2: 0.692112698 s, 14,448.514 columns/s, 1.244104x;
- 4x1: 0.696793944 s, 14,351.445 columns/s, 1.235746x.

### N=40,000

- 1x4: 7.384210385 s, 5,416.964 columns/s;
- 2x2: 4.276059924 s, 9,354.406 columns/s, 1.726873x;
- 4x1: 3.962953794 s, 10,093.481 columns/s, 1.863310x.

Aggregate q and tangent checksums matched for every configuration at every measured N.

## Interpretation

The process-partitioning advantage grows strongly with population size:
- approximately +6% for 2x2 at N=1,000;
- approximately +24% for 2x2 at N=10,000;
- approximately +73% for 2x2 at N=40,000.

For 4x1 the pattern is even stronger:
- slightly slower than 1x4 at N=1,000;
- approximately +24% at N=10,000;
- approximately +86% at N=40,000.

This rejects a purely fixed process-launch explanation.

## Code localization

Inspection of `application_context_trial_cell_heads` identifies a concrete N-dependent dispatch mechanism in the parallel path.

After ownership has been assigned, the current implementation executes:

```fortran
!$omp parallel do ... num_threads(self%worker_count)
do w = 1, self%worker_count
  do idx = 1, size(self%tiles)
    if (owner(idx) /= w) cycle
    ...
  end do
end do
```

Each worker scans the complete tile population and skips non-owned tiles.

Therefore dispatch scanning costs scale approximately with:

`worker_count * tile_count`

rather than with the number of owned tiles alone.

Process partitioning reduces the size of each application context and therefore reduces this repeated full-population scan. The 4x1 configuration also uses the serial execution path and avoids this parallel dispatch structure entirely.

This mechanism is a strong causal candidate for the observed size dependence. It is not yet proven to account for the complete gain.

## Decision

Advance:

`F-PE-MULTIPROC03 — compact worker dispatch qualification`

The successor must test a research-only compact per-worker index representation that:
- preserves the already selected owner mapping;
- preserves static versus cost-aware scheduler decisions;
- preserves canonical tile result order;
- causes each worker to visit only its assigned tiles;
- preserves exact q/tangent and retry/nonlinear trajectory;
- measures 1x4 against the current implementation at N=1,000 / 10,000 / 40,000.

If compact dispatch removes most of the 1x4 deficit, process partitioning itself is not the principal architecture requirement.

If the deficit remains material after compact dispatch, continue with cache/working-set attribution.

