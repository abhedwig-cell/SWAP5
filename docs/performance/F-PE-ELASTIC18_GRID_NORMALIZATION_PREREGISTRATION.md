# F-PE-ELASTIC18 — SWAP grid normalization preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

Parent authority:
- `F-PE-ELASTIC17_CLOSURE.md`;
- admitted ELASTIC16 descriptor assembly;
- SWAP scientific vertical-coordinate convention: `z` positive upward.

## Purpose

Add one stateless adapter that converts an explicitly typed SWAP-style
centimetre grid to the normalized ELASTIC17 geometry contract in metres below
soil surface.

This work unit closes only the sign/unit/grid-geometry seam.

## Unit authority

The adapter API names its raw inputs explicitly:

- `z_cm(:)`;
- `dz_cm(:)`.

No untyped `z(:)` or `dz(:)` array is accepted.

Repository evidence supporting this contract includes:
- the established ROM/HeadCalc grid materializer argument `--dz-cm`, which
  constructs `MOD_grid z`, `dz` and `disnod` directly from centimetres;
- the admitted SWAP/Richards length convention in which hydraulic heads,
  storage-depth diagnostics and flux-depth rates use centimetres / cm/day;
- the scientific convention that vertical `z` is positive upward.

ELASTIC18 therefore makes the centimetre assumption explicit at its boundary
rather than silently assigning a unit to a generic array.

## Frozen normalization

For every active node:

`node_depth_m = -0.01 * z_cm`

`node_thickness_m = 0.01 * dz_cm`.

No `abs(z)` is allowed.

A positive raw `z_cm` is invalid for a below-surface soil compartment.

## Grid geometry contract

The grid must represent contiguous compartments beginning at the soil surface.

Define cumulative top depth in centimetres:

`top_1 = 0`

`top_i = sum(dz_cm(1:i-1))`.

Expected node centre:

`expected_z_cm(i) = -(top_i + 0.5*dz_cm(i))`.

The supplied `z_cm(i)` must equal this expected centre within:

`tol_cm = 1e-8 cm`.

This is a representation tolerance only.

The adapter rejects:
- gaps implied by centre positions;
- overlaps implied by centre positions;
- reversed node order;
- a profile whose first compartment does not begin at the surface;
- positive/below-sign-inconsistent node centres.

## Input validity

Require:
- non-empty arrays;
- identical z/dz lengths;
- all finite;
- every `dz_cm > 0`;
- every `z_cm <= 0`;
- exact contiguous-centre geometry within tolerance.

## Output contract

On success return arrays:
- `node_depth_m(:)`;
- `node_thickness_m(:)`.

They are the only geometry representation passed to ELASTIC17.

No physical descriptor or ELAS value is changed or created.

## Qualification matrix

A1. established uniform cm grid converts exactly to metres below surface.

A2. heterogeneous contiguous compartment thicknesses convert exactly.

A3. positive z, non-finite z/dz, zero/negative thickness and shape mismatch
fail closed.

A4. centre positions inconsistent with cumulative dz fail closed, including
gap/overlap/reordered cases.

A5. converted normalized geometry composes with admitted ELASTIC17 and produces
the same horizon ownership as directly supplied normalized metre geometry.

A6. a raw grid whose compartment straddles a source horizon remains rejected by
ELASTIC17 after normalization; ELASTIC18 may not hide the straddle.

A7. O0/O2 identity.

A8. production source scope is exactly one new stateless adapter module; no
existing runtime/kernel/legacy source is modified.

## Admission boundary

A green ELASTIC18 admits only explicit cm-grid normalization.

It does not admit:
- a generic unit-detecting adapter;
- grid resampling;
- compartment splitting;
- BOFEK/BRO lookup;
- soil-horizon selection;
- file parsing;
- automatic generated-prior activation.
