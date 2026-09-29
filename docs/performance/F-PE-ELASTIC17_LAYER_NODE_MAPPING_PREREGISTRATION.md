# F-PE-ELASTIC17 — source horizon to SWAP node mapping preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_MAPPING_RESULTS

Baseline:
`integration/f-ci-canonical@7ea6fc05ef589e3adb3e26ef1d436e514604197f`

Parent authority:
- `F-PE-ELASTIC12_CLOSEOUT.md`;
- `F-PE-ELASTIC13_CLOSEOUT.md`;
- `F-PE-ELASTIC14_CLOSURE.md`;
- `F-PE-ELASTIC15_CLOSURE.md`;
- `F-PE-ELASTIC16_CLOSURE.md`.

## Purpose

Define and qualify one deterministic mapping from source-bound BOFEK/BRO soil
horizons to SWAP node-local ELAS descriptors.

The source data are horizon based.

The admitted ELASTIC16 assembly consumes one resolved descriptor per active
SWAP node.

ELASTIC17 closes only this geometric mapping gap.

## Scientific and coordinate conventions

SWAP scientific authority defines vertical coordinate `z` as positive upward.

Below the soil surface, node coordinates are therefore negative.

ELASTIC17 does not consume raw SWAP `z` or assume a hidden unit conversion.

Its input contract is already normalized geometry in meters below the soil
surface:

- node centre depth `node_depth_m >= 0`;
- node thickness `node_thickness_m > 0`;
- horizon top depth `top_depth_m >= 0`;
- horizon bottom depth `bottom_depth_m > top_depth_m`.

A later grid adapter may convert SWAP-native geometry to this normalized
contract.

## Source horizon descriptor

Each horizon carries only already resolved physical metadata:

- dry bulk density `rho_dry_g_cm3`;
- volumetric water content at the frozen ELAS reference state
  `theta_ref_cm3_cm3`;
- explicit ELASTIC14 regime code.

ELASTIC17 does not:
- compute theta from pressure head;
- evaluate Staringreeks retention;
- classify peat/mineral;
- fetch BOFEK/BRO;
- infer a soil code.

## Mapping rule

For node `i`:

`node_top = node_depth_m(i) - 0.5 * node_thickness_m(i)`

`node_bottom = node_depth_m(i) + 0.5 * node_thickness_m(i)`.

A node may receive a horizon descriptor only when its complete physical
compartment is contained inside one source horizon.

For source horizon `j`:

`top_j <= node_top`

and

`node_bottom <= bottom_j`.

A node centre alone is never sufficient evidence.

## Boundary tolerance

A fixed geometric tolerance is used only for floating-point representation:

`tol = 1e-10 m`.

Containment uses:

`node_top >= top_j - tol`

and

`node_bottom <= bottom_j + tol`.

The tolerance may not be used to bridge a material gap or to absorb a
meaningful straddling compartment.

## Horizon validity

Before node mapping, source horizons must be:

- finite;
- strictly positive thickness;
- ordered by increasing top depth;
- non-overlapping;
- contiguous within `tol`;
- descriptor values finite where numeric;
- cover every requested node compartment.

A gap or overlap greater than `tol` invalidates the entire mapping.

## Straddling rule

If one node compartment intersects more than one horizon because a material
boundary lies strictly inside that compartment, classification is:

`NODE_STRADDLES_HORIZON_BOUNDARY`.

The entire mapping fails closed.

No:
- thickness-weighted mixing;
- nearest-horizon assignment;
- centre-point assignment;
- averaging of density, theta or ELAS

is authorized by ELASTIC17.

This preserves the physical meaning that one node-local constitutive parameter
set represents one source material.

## Exact boundary alignment

A node compartment may end exactly at one horizon boundary and the adjacent
node may begin exactly at that boundary.

This is valid.

The upper node belongs to the shallower horizon and the lower node to the deeper
horizon because complete-compartment containment is unambiguous.

## Output contract

On success return one descriptor per node:

- `rho_dry_g_cm3`;
- `theta_ref_cm3_cm3`;
- regime;
- source horizon index.

The descriptor tuple must be bit-identical to the owning source horizon values.

No new fitted or averaged quantity is produced.

## Qualification matrix

A1. one-horizon profile maps multiple contained nodes exactly.

A2. multi-horizon profile with node boundaries exactly aligned to horizon
boundaries maps each node to the correct source horizon.

A3. a node whose compartment straddles a horizon boundary fails closed.

A4. source horizon gap, overlap, reverse ordering or zero/negative thickness
fails closed before node assignment.

A5. node outside the source profile fails closed.

A6. invalid/non-finite node geometry or source numeric descriptor fails closed.

A7. mapped descriptor tuples are bit-identical to direct source-horizon tuples.

A8. mapped all-MINERAL descriptors compose through admitted ELASTIC16 exactly
as direct manually constructed node descriptors.

A9. a mapped PEAT node remains mapped faithfully, then is rejected by
ELASTIC16 generated-prior assembly; ELASTIC17 does not hide or reclassify it.

A10. O0/O2 identity.

A11. source scope is exactly one new stateless adapter module and its tests/docs;
no existing runtime/kernel/legacy source is modified.

## Admission boundary

A green ELASTIC17 admits only deterministic horizon-to-node descriptor mapping.

It does not admit:
- raw SWAP `z/dz` unit conversion;
- BOFEK/BRO data loading;
- profile selection;
- interpolation across material boundaries;
- a file grammar;
- automatic generated-prior request;
- mixed-material node approximation.
