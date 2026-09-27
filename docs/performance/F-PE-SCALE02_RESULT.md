# F-PE-SCALE02 result — post-SETUP04 production-scale throughput

Date: 2026-09-27

Status: `CLOSED_MILD_LARGE_N_DEGRADATION_NO_MEMORY_CLIFF`

PR:
`#687 — F-PE-SCALE02: post-SETUP04 production-scale throughput characterization`

Measured head:
`4dca0a74fc54363b091219a354edb419ee70580b`

## Standard-stack result

The standard GitHub runner completed:
- N=10,000;
- N=40,000;

but the generated large-N fixture segfaulted at N=100,000.

The failure occurred before a valid throughput result was produced.

## Stack discriminator

The generated research fixture uses large automatic Fortran arrays for tiles, cells, predictors and areas.

With `ulimit -s unlimited`, the otherwise unchanged N=100,000 run completed successfully.

Therefore the N=100,000 standard-stack failure is classified as a research-fixture stack artifact, not a demonstrated SWAP production-capacity failure.

## Throughput

### N=10,000

- worker=1: 0.757502025 s;
- worker=2: 0.389684147 s;
- worker=4: 0.288255738 s;
- 2-worker speedup: 1.943887x;
- 4-worker speedup: 2.627882x;
- worker=4 throughput: about 34,691 columns/s.

### N=40,000

- worker=1: 3.788417091 s;
- worker=2: 1.937717631 s;
- worker=4: 1.579140693 s;
- 2-worker speedup: 1.955092x;
- 4-worker speedup: 2.399037x;
- worker=4 throughput: about 25,330 columns/s.

### N=100,000

Unlimited-stack discriminator:
- worker=1: 9.436876271 s;
- worker=2: 4.887306390 s;
- worker=4: 3.842405812 s;
- 2-worker speedup: 1.930895x;
- 4-worker speedup: 2.455981x;
- worker=4 throughput: about 26,025 columns/s.

q and tangent checksums remained exact.

## Throughput retention

Worker=4 throughput relative to N=10,000:
- N=40,000: about 0.730;
- N=100,000: about 0.750.

This falls in the preregistered `MILD_DEGRADATION` band.

However, throughput from N=40,000 to N=100,000 is effectively stable and slightly higher at N=100,000.

Therefore the data show a working-set/cache transition between 10k and 40k, but no continuing large-N memory cliff.

## Decision

Do not open a new memory/data-layout optimization solely from SCALE02.

The observed degradation is material enough to record but does not worsen from 40k to 100k and does not meet the preregistered `MATERIAL_LARGE_N_DEGRADATION` threshold (<0.70 retention).

The unresolved scaling question remains high-core-count behavior on a real >4-logical-CPU host.

## Harness note

Future N=100,000 CI characterization should avoid large automatic OpenMP fixture arrays, preferably by heap-allocating the generated research arrays rather than relying on unlimited stack.
