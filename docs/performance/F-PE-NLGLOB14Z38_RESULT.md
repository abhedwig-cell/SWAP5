# F-PE-NLGLOB14Z38 result — zero-waste persistent manager fast path

Date: 2026-09-30

Status:

`Z38_PERSISTENT_MANAGER_TIMING_REGRESSION`

Qualification authority:

- workflow run: `36771542143`;
- compiled timing job completed SUCCESS;
- benchmark execution completed with finite checksum and no measured steady-state buffer reallocations.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Aggregate result

The persistent manager replay classifies:

`Z38_PERSISTENT_MANAGER_TIMING_REGRESSION`.

Geometric-mean reduced/full timing ratio:

`1.11563`.

Mean structural work ratio:

`0.796875`.

The persistent zero-waste path therefore removes most of the Z37 regression, but the focused microkernel is still about 11.6% slower.

## Case timing

- O05_T13: ratio ~1.1320
- O05_T12: ratio ~1.0678
- O14_T13: ratio ~1.1321
- B12_T13: ratio ~1.1320

## Allocation result

The persistent context behaves as intended.

Per case:

- request buffer reallocations: 1 total during initial setup;
- full-candidate buffer reallocations: 1 total during initial setup;
- workspace shape reallocations during measured execution: 0.

There are no steady-state reallocations in the measured blocks.

## Improvement versus Z37

Z37 geometric-mean ratio:

~1.3017.

Z38 geometric-mean ratio:

~1.1156.

Thus persistent buffers remove a large majority of the manager timing penalty.

The remaining fixed overhead is dominated by view/request refresh, full-candidate materialization and manager diagnostics/copy activity.

## Important benchmark scale

The full frozen microkernel executes in roughly 0.14 microseconds per operation.

That is far smaller than a real Richards nonlinear solve.

The benchmark therefore intentionally magnifies fixed manager overhead.

Z38 is valid for its frozen timing question, but its 11.6% regression must not be interpreted as whole-SWAP runtime regression.

## Consequence

Do not keep optimizing the sub-microsecond TRIDAG microkernel.

The next workunit should benchmark the actual compiled Richards solve-service, where constitutive evaluation, residual/Jacobian work and nonlinear iterations provide the realistic cost scale over which fixed manager overhead is amortized.

## Production boundary

Research only.

`LEGACY_NUMERICS` remains production default.
