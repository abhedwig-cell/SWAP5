# F-PE-ELASTIC17 — horizon-to-node mapping result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic17-clean-admission`

Qualified clean postimage:
`37f80868970b277282ee52621df9055d4c6f4ede`

Clean extraction base:
`integration/f-ci-canonical@b7e5acf9ea297d3d59f0b28202d34a0ccc96dd5e`

Workflow run:
`36559979790`

Job:
`109378232222`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_horizon_node_mapper.f90`.

No existing production source is modified.

The mapper performs only deterministic geometry-to-descriptor assignment.

It does not:
- fetch BOFEK/BRO;
- evaluate Staringreeks retention;
- classify soil regime;
- infer ELAS;
- modify runtime state;
- alter solver policy.

## A1 single-horizon mapping

Multiple node compartments fully contained in one horizon receive that
horizon's descriptor exactly.

PASS.

## A2 exact horizon-boundary alignment

A node ending exactly on a horizon boundary and the next node beginning exactly
on that boundary map to the shallower and deeper horizons respectively.

PASS.

## A3 straddling fail closed

A node compartment that crosses a source horizon boundary is rejected as:

`NODE_STRADDLES_HORIZON_BOUNDARY`.

No mapped output survives.

PASS.

## A4 horizon geometry validation

The mapper rejects before assignment:
- material gaps;
- material overlaps;
- zero/negative horizon thickness;
- invalid ordering.

PASS.

## A5 source-profile coverage

A node compartment outside the source horizon profile is rejected.

PASS.

## A6 invalid/non-finite input

Non-finite node geometry and non-finite source descriptor values fail closed.

PASS.

## A7 descriptor bit identity

Mapped density and reference-theta values are copied bit-identically from their
owning source horizon.

No averaging or fitted transformation occurs.

PASS.

## A8 ELASTIC16 composition

Mapped all-MINERAL descriptors passed through the admitted ELASTIC16 assembly
and produced the exact same parameter postimage as manually constructed
node-local descriptor tuples.

PASS.

## A9 peat provenance preservation

A PEAT source horizon maps faithfully as PEAT.

The mapper does not reclassify it.

The downstream admitted ELASTIC16/14 policy then rejects generated-prior
assembly for that node exactly as intended.

PASS.

## A10 O0/O2 identity

Focused mapping outputs are identical at O0 and O2.

PASS.

## A11 source scope

Production delta is exactly:

`src/adapter/mod_fmr_elastic_storage_horizon_node_mapper.f90`.

No runtime, kernel or legacy production source changes.

PASS.

## Mapping semantics

The qualified rule is complete-compartment containment.

For node centre depth `d` and thickness `t`:

`node_top = d - t/2`

`node_bottom = d + t/2`.

A source horizon owns the node only when the complete interval is contained
inside that horizon within the fixed `1e-10 m` representation tolerance.

A centre-point-only rule is not admitted.

A mixed-material node is not silently approximated.

## Admission meaning

A green ELASTIC17 admits only normalized horizon-to-node descriptor mapping.

Inputs remain normalized in metres below surface.

Still outside scope:
- raw SWAP `z/dz` unit conversion;
- BOFEK/BRO profile retrieval;
- layer-to-node resampling by averaging;
- mixed-material compartment approximation;
- file syntax;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
