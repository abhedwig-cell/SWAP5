# F-PE-NLGLOB14Z36 result — compact holdout and timing qualification

Date: 2026-09-30

Status:

`QUALIFIED_Z36_COMPACT_HOLDOUT_READY_FOR_FORTRAN_TIMING`

Qualification authority:

- preregistered four-case holdout;
- local-container execution after preregistration;
- persisted evidence: `docs/performance/F-PE-NLGLOB14Z36_LOCAL_EVIDENCE.json`;
- local runner SHA-256: `ecb7a9291bda57019cf1af00fea0d44503265c6b5652449d9bb99b956423e089`.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z36-compact-holdout-timing@bd6cb3059a09b5aecd8d96ad25314a73904d13ec`

## Aggregate result

The frozen compact holdout classifies:

`QUALIFIED_Z36_COMPACT_HOLDOUT_READY_FOR_FORTRAN_TIMING`.

All 4/4 frozen cases pass the physical comparison gates with no fallback-required case.

## Holdout coverage

### O05_T13

- active dimension: 13;
- full/reduced iterations: 1 / 1;
- work ratio: 0.8125;
- max h difference: 0;
- max theta difference: 0;
- top-flux difference: 0;
- ledger difference: 0;
- resulting tail: 13:16 in both routes.

### O05_T12

- active dimension: 12;
- full/reduced iterations: 1 / 1;
- work ratio: 0.75;
- all frozen physical differences: 0;
- resulting tail: 12:16 in both routes.

### O14_T13

- active dimension: 13;
- work ratio: 0.8125;
- all frozen physical differences: 0;
- resulting tail: 13:16 in both routes.

### B12_T13

- active dimension: 13;
- work ratio: 0.8125;
- all frozen physical differences: 0;
- resulting tail: 13:16 in both routes.

## Structural work result

Mean deterministic work ratio:

`0.796875`.

Maximum case ratio:

`0.8125`.

Thus the compact heterogeneous holdout preserves approximately 20.3% average deterministic nonlinear algebra-work reduction.

No case has a work ratio above 1.0.

## Python local timing

The frozen local Python timing protocol gives a mean reduced/full median timing ratio of approximately:

`1.0185`.

Individual ratios are approximately 1.013–1.022.

Therefore the Python dense-Jacobian research harness is slightly slower despite the lower algebra dimension.

This does not contradict the structural work result. Python interpreter overhead and the reconstruction/orchestration path dominate this tiny one-iteration microbenchmark.

Per preregistration, Python timing is not a scientific or production performance gate.

## Interpretation

Z36 broadens the same-origin reduced/full equivalence beyond O05:

- O14 passes;
- B12 passes;
- both n=12 and n=13 geometries pass;
- no fallback is needed;
- structural work reduction remains near 20%.

This is sufficient evidence to stop using the Python harness for performance judgment.

The next performance question must be answered in compiled Fortran on the production-shaped manager seam.

## Qualified claim boundary

Qualified:

- 4/4 compact holdout physical equivalence;
- O05, O14 and B12 coverage;
- n=12 and n=13 reduced dimensions;
- zero fallback incidence in the frozen set;
- mean deterministic work reduction about 20.3%;
- readiness for focused Fortran timing.

Not qualified:

- production Fortran wall-clock speedup;
- BOFEK-wide portability;
- production admission;
- production default change.

## Consequence

Open one focused compiled timing successor.

It should benchmark the full and reduced production-shaped paths in one executable process with:

- fixed frozen states;
- sufficient repetitions;
- warm-up excluded;
- manager overhead included;
- work counters retained;
- no long GitHub trajectory campaign.

## Production boundary

Research only.

`LEGACY_NUMERICS` remains production default.
