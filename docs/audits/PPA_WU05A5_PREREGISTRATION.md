# PPA-WU05-A5 preregistration — full macropore process composition

Date: 2026-09-30

Status: `PREREGISTERED / RESEARCH_ONLY / PRODUCTION_HELD`

Baseline: `PPA-WU05-A4@8345f25924b7ca3cf87633a8901063f365df0c73`

Canonical source dependency surface last reconciled through:
`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Purpose

Complete the remaining source-bound macropore process-composition surface on top of the qualified A4 typed controller.

A5 changes the research focus from numerical coupling control to physical process completeness.

## Upstream authority

A5 inherits:

- exact B1.11 source authority and seven-field continuation state from A1/A2;
- A3 corrected-reference process map;
- A4 typed outer coupling controller;
- real-Richards strict and max-three coupling routes;
- crack-history and rapid-drain accepted-state trajectory qualification.

A5 does not reopen those results unless contradictory exact-source evidence appears.

## Priority process gaps

### A5-P1 top-boundary partition

Reconstruct exact B1.11 ownership for direct vertical macropore inflow, lateral/ponded macropore inflow, matrix top-boundary remainder, rainfall/irrigation/melt partition, and no-double-count whole-column receipt.

### A5-P2 excess redistribution

Reconstruct exact behavior when top macropore input exceeds immediate storage/rate capacity, macropore compartments fill, or excess is redirected/ponded/runoff-owned. No synthetic overflow rule from A3/A4 may be promoted as source authority.

### A5-P3 full compartment/domain geometry

Move from the A4 single active research compartment to multiple compartments and domains with source-bound bottom-connected storage, refined interface semantics, and dynamic crack geometry across nodes.

### A5-P4 distributed exchange

Replace the one-node research exchange with a vector field over active macropore compartments while preserving internal exchange cancellation, accepted candidate ownership, and locally conservative accepted vertical flux reconstruction.

### A5-P5 drainage topology

Extend rapid drainage to multiple contributing compartments/domains with source-bound drain-base/domain-bottom relations, storage caps and kD weighting, and one external drainage receipt.

### A5-P6 full restart/replay

Serialize only physical/history continuation state, recompute geometry/rate scratch after restore, and qualify deterministic accepted-state replay with rejected-trial isolation.

## Research sequence

1. exact source-to-process map for P1/P2;
2. local Python falsification harnesses for partition/excess behavior;
3. multi-compartment/domain local model;
4. bind process vector to the qualified A4 controller;
5. focused real-Richards verification of adversarial representatives only;
6. full restart/replay qualification.

GitHub Actions is formal verification only. Broad sweeps belong in local/reduced research harnesses.

## Core hypotheses

- H1: top macropore inflow can be represented as an explicit partition of the existing top-boundary receipt without changing whole-column external water ownership.
- H2: source-defined excess redistribution can be expressed without creating an additional external source/sink.
- H3: the seven-field A2 continuation surface remains sufficient when multiple domains and compartments are activated.
- H4: derived geometry remains regenerable from accepted state/configuration.
- H5: distributed matrix/macropore exchange cancels internally to roundoff over the full column.
- H6: rapid drainage remains a single external owner after full multi-domain composition.
- H7: restart/replay is deterministic from the seven-field continuation state plus immutable configuration.

## Hard holds

- no production macropore activation;
- no canonical admission;
- no hidden module-global continuation state;
- no mass-tolerance relaxation;
- no reuse of A3 synthetic overflow as source truth;
- no MultiSWAP/thread-safety claim in A5.

## Exit

A5 may close as:

- `QUALIFIED_FULL_SINGLE_COLUMN_PROCESS_COMPOSITION_READY_FOR_PRODUCTION_SHAPING`;
- `QUALIFIED_COMPOSITION_WITH_SOURCE_DEFECT_FOLLOWON_REQUIRED`;
- `CONTINUATION_STATE_SURFACE_FALSIFIED`;
- `MASS_OWNERSHIP_FALSIFIED`;
- or an explicit source/physics blocker.
