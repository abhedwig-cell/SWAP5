# GC-RZM06A6 node-profile and observable audit preregistration

Date: 2026-09-22  
Machine-readable authority: `bf201af7c604a94b3fe36bc5ef1eb7674156c8f6`  
Production changes: none

## Purpose

RZM06A5 established a repeatable early-versus-late forcing memory, but the largest aggregate distribution-moment separation remained about 70 times below the frozen H2 threshold and disappeared after common relaxation.

Before another forcing construction is attempted, RZM06A6 audits the committed state itself.

The question is whether the aggregate diagnostics are faithfully describing a genuinely small profile difference, or whether the first moment is hiding larger compensating changes between nodes.

## Carrier under audit

The carrier runs the real HeadCalc route through the serialized-reference backend and supplies the explicit B110 constitutive-hydraulics provider. The normal `swkimpl=0` route therefore does not rely on the simple fallback MvG stubs for its constitutive update.

The vertical layout is nevertheless the focused four-node FSI fixture:

- `z = [-0.25, -0.75, -1.50, -2.50]`;
- `dz = [0.50, 0.50, 1.00, 1.00]`.

The bridge already documents this geometry as metre-scale. Hydraulic pressure heads retain the native HeadCalc centimetre coordinate.

## New diagnostic

A research-only, read-only C ABI will expose from the current committed snapshot:

- active node count;
- pressure head per node;
- water content per node;
- z per node;
- dz per node.

It may not mutate the committed state, revision, time or interface ledger and has no production authority.

## Fixed histories

A6 does not search trajectories. It replays these frozen RZM06A5 representatives:

- baseline;
- NEG, N=100, R=0, EARLY and LATE;
- POS, N=100, R=0, EARLY and LATE;
- NEG, N=100, R=50, EARLY and LATE.

Each non-baseline history uses `dt=0.01 d`, fixed `H_c=H*`, and the exact A5 EARLY/LATE sequence definitions.

## Reconstruction gate

From node data, reconstruct:

`W = Σ(theta_i dz_i)`

`M1 = Σ(theta_i dz_i z_i) / W`

and upper-0.30 m root water using the same geometric-overlap rule as the existing aggregate diagnostic.

Every reconstructed aggregate must match the existing committed-profile diagnostic within absolute tolerance `1e-13` in its native geometry unit. Failure closes A6 as `OBSERVABLE_RECONSTRUCTION_FAILURE`.

## Node-level diagnostics

For the three fixed EARLY/LATE pairs, A6 reports:

- node-wise pressure-head differences;
- node-wise water-content differences;
- node-wise storage differences `delta(theta_i dz_i)`;
- maximum absolute node pressure-head and water-content difference;
- L1 redistributed storage `Σ|delta(theta_i dz_i)|`;
- signed total-storage difference;
- aggregate `delta W` and `delta M1`.

No new numerical threshold is introduced to label aggregate masking. The vectors and scale ratios are evidence; the scientific continuation decision follows only after qualification.

A6 does not inspect E_c and does not alter or reinterpret the frozen H2 thresholds.
