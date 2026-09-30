# F-PE-NLGLOB14Z37 result — compiled Fortran manager timing qualification

Date: 2026-09-30

Status:

`Z37_FORTRAN_TIMING_REGRESSION`

Qualification authority:

- workflow run: `36770830831`;
- job: `110076480952`;
- workflow conclusion: SUCCESS;
- benchmark executable completed with finite checksums.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Aggregate result

The compiled production-shaped manager benchmark classifies:

`Z37_FORTRAN_TIMING_REGRESSION`.

Geometric-mean reduced/full timing ratio:

`1.30169`.

Mean deterministic structural work ratio:

`0.796875`.

Thus the current manager route performs about 20.3% less structural linear-solver work but is about 30.2% slower in this compiled microbenchmark.

## Case results

### O05_T13

- active n = 13;
- structural work ratio = 0.8125;
- timing ratio = 1.3056.

### O05_T12

- active n = 12;
- structural work ratio = 0.75;
- timing ratio = 1.3152.

### O14_T13

- active n = 13;
- structural work ratio = 0.8125;
- timing ratio = 1.3001.

### B12_T13

- active n = 13;
- structural work ratio = 0.8125;
- timing ratio = 1.2861.

All checksums remain finite and the benchmark execution itself is valid.

## Interpretation

The reduced algebra is not the bottleneck in the current manager prototype.

The reduced path currently performs additional per-operation work that the full path does not:

- full request construction;
- reduced parameter slicing/allocation;
- reduced base-state allocation/copy;
- reduced workspace initialization;
- tail-array allocation;
- full candidate rematerialization;
- derived-type result copying;
- manager result selection/diagnostic materialization.

Because the numerical linear solve itself is sub-microsecond in this benchmark, these orchestration/allocation costs dominate and erase the structural benefit.

This is consistent with the broader zero-waste performance findings elsewhere in SWAP5: allocation, copying and state preparation can dominate once the numerical kernel becomes small.

## Qualified claim boundary

Qualified:

- current compiled manager prototype is slower in this focused benchmark;
- structural work reduction remains about 20%;
- manager/orchestration overhead dominates the microbenchmark;
- further performance work must target allocation/copy/view overhead rather than the reduced physics.

Not qualified:

- whole-SWAP end-to-end regression;
- impossibility of net speedup after zero-waste optimization;
- production admission.

## Consequence

Do not proceed directly to an application-scale end-to-end benchmark with the current manager implementation.

Open a focused zero-waste successor that removes per-step allocation/copy overhead while preserving the Z34/Z35 manager semantics.

The primary candidate is:

- persistent manager-owned reduced parameter/state/workspace buffers;
- shape changes only when active dimension changes;
- direct view/copy-on-change preparation;
- no repeated tail allocation;
- no redundant full-result copy when reduced route is selected.

After that optimization, repeat the exact frozen Z37 timing benchmark unchanged.

## Production boundary

Research only.

`LEGACY_NUMERICS` remains production default.
