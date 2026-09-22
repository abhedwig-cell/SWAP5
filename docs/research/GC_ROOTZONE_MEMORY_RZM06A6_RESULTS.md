# GC-RZM06A6 node-profile audit result

Date: 2026-09-22  
Preregistration: `bf201af7c604a94b3fe36bc5ef1eb7674156c8f6`  
Qualified workflow: `35733571697`, job `106765051719`  
Production changes: none

## Decision

RZM06A6 is qualified as:

`QUALIFIED_NO_AGGREGATE_MASKING__FOUR_NODE_H2_CEILING`.

This is a carrier-scope decision, not an H2 support or falsification.

## Reconstruction gate

The new read-only node diagnostic exposed, from the committed snapshot:

- pressure head per node;
- water content per node;
- z;
- dz.

For baseline and all six fixed A5 histories, the existing aggregate diagnostics reconstructed from the node state within floating-point roundoff, well inside the frozen `1e-13` gate.

Thus the A5 aggregate signal is not an artefact of a faulty observable calculation.

## Node-level result

For the two no-relaxation EARLY/LATE pairs, the largest differences were approximately:

- pressure head: `2.06e-3` in native HeadCalc head units;
- water content: `1.98e-6`;
- total profile storage: `2.804e-6` in the geometry-derived native length unit;
- first-moment shift: `1.428e-6` in the geometry-derived native length unit.

Critically, all four node-storage differences have the same sign for each R0 pair. Therefore

`sum(abs(delta storage_i)) ≈ abs(delta W_profile)`

to roundoff. There is no upper/lower-node cancellation hidden by the total-water observable, and M1 is not suppressing a much larger compensating redistribution pattern.

After the common R50 relaxation, node-level differences collapse to roundoff, matching the aggregate result.

## Geometry and unit audit

The focused carrier has four nodes:

`z = [-0.25, -0.75, -1.50, -2.50]`

`dz = [0.50, 0.50, 1.00, 1.00]`.

The research bridge explicitly treats this geometry as metre-scale. Therefore `sum(theta*dz)` is a length in the geometry unit and the normalized first moment is also in that geometry unit.

The C/Python field names ending in `_cm` are historical and semantically misleading for these geometry-derived observables. Hydraulic pressure heads, by contrast, retain the native HeadCalc centimetre convention.

The upper 0.30 m root-zone diagnostic overlaps only the first 0.50 m node. On this fixture it is therefore not a genuinely multi-node root-zone distribution diagnostic.

## Consequence

A2 through A6 have now exhausted the useful H2 search space of this focused four-node carrier:

- head-history constructions hit transition admissibility limits;
- stronger top forcing was outside the admissible envelope;
- admitted timing histories produced a small, saturating memory signal;
- common relaxation erased that signal;
- node-level inspection confirms the signal is genuinely small rather than hidden by aggregation.

The frozen H2 thresholds are not relaxed.

The next step is a carrier transition: preserve the transactional research protocol and H2 criteria, but bind the falsification experiment to a richer real-SWAP vertical profile/discretization rather than continue tuning forcing on the four-node FSI fixture.
