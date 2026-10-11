# F-PE-ELASTIC18 — SWAP grid normalization preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@c1e1fd961b30c21958d050cb974228eb9dfd2364`

Parent authority:
- `F-PE-ELASTIC17_CLOSURE.md`.

## Purpose

Add one stateless adapter that converts raw SWAP node geometry to the normalized
geometry contract consumed by ELASTIC17.

## Source semantics

Repository and official SWAP grid authority establish:
- `z(i)` is node-centre elevation in cm relative to soil surface;
- below-surface nodes therefore have `z <= 0`;
- `dz(i)` is positive compartment thickness in cm;
- first node centre is `z=-0.5*dz`;
- subsequent centres follow cumulative compartment geometry.

## Frozen conversion

For every active node:

`node_depth_m = -z_cm / 100`

`node_thickness_m = dz_cm / 100`.

No other unit or sign convention is admitted.

## Validation

Fail closed when:
- arrays differ in length;
- no nodes;
- any non-finite value;
- any `z > 1e-10 cm`;
- any `dz <= 0`;
- reconstructed top depth is shallower than surface by more than `1e-12 m`;
- compartments overlap or have a gap greater than `1e-10 m`.

Adjacent compartments must therefore tile continuously from the surface.

## Qualification

A1. canonical four-node fixture maps exactly.

A2. heterogeneous compartment thickness maps exactly.

A3. positive-above-surface z fails closed.

A4. non-finite/zero/negative thickness and shape mismatch fail closed.

A5. gap/overlap in raw z/dz geometry fails closed.

A6. normalized output composes through admitted ELASTIC17 identically to direct normalized geometry.

A7. O0/O2 identity.

A8. source scope is exactly one new adapter module; no runtime/kernel/legacy source modified.

## Boundary

No BOFEK/BRO loading, profile selection, soil physics, ELAS inference, parser
syntax or automatic generated-prior request is admitted here.
