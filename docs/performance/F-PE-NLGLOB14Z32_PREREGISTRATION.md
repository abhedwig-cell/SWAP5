# F-PE-NLGLOB14Z32 preregistration — stable n=13 interface-equation attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@c400b02d9956f35c9c20fac09f94b34d5e2ee09f`

Parent authority:

- Z31R: `QUALIFIED_Z31R_REGIME_LOCALIZED_BIAS`;
- tail 12:16 / n=12 is machine-scale neutral;
- measurable drift begins in stable tail 13:16 / n=13;
- first chatter family is negligible;
- adaptive manager still reduces deterministic solver work by about 20%.

## Purpose

Identify the exact equation-level source of the stable n=13 / tail 13:16 reduced-versus-full discrepancy.

Z32 is attribution only.

It must not modify the moving-interface physics or introduce a correction.

## Frozen fixtures

Use exactly:

- O05 / HEAD / dt = 6.25e-5 d;
- O05 / RUNOFF / dt = 6.25e-5 d;
- unchanged dynamic-top semantics;
- qbot = 0;
- unchanged full-reference and reduced candidate solvers.

The full-reference trajectory remains accepted-state authority.

Reduced candidates are observer-only and may not advance the trajectory.

## Frozen n=13 observation points

After the first chatter family has settled to tail 13:16, observe stable n=13 candidates from identical full-reference origins at:

1. first stable post-settlement interval;
2. approximately 280 d;
3. 320 d;
4. 400 d;
5. 480 d;
6. 514.5 d, before the later 13:16 -> 14:16 transition family.

Use the first nominal step at or after each requested time for which the full origin and full candidate both remain tail 13:16 and ownership is stable.

If one requested point is not available, report coverage explicitly; do not move it to an event interval.

## Frozen decomposition

For each observed interval compute full and reduced values from the same origin.

### Interface face

For face 13/14 report:

- origin flux;
- full endpoint flux;
- reduced endpoint flux;
- trapezoidal full interface flux;
- trapezoidal reduced interface flux;
- full-minus-reduced flux difference.

### Guard node 13

Report:

- origin theta13;
- full theta13;
- reduced theta13;
- full storage increment;
- reduced storage increment;
- full node-13 temporal residual;
- reduced guard residual;
- full-minus-reduced residual.

### Reconstructed tail 14:16

Per node report:

- full endpoint pressure head;
- reconstructed reduced pressure head;
- head difference;
- full theta;
- reduced theta;
- storage increment difference.

Also report:

- summed tail storage increment full;
- summed tail storage increment reduced;
- full-minus-reduced tail storage;
- maximum reconstructed-tail Darcy-flux mismatch.

### Nominal interval

Report:

- full ledger;
- reduced ledger;
- signed ledger difference;
- max h difference;
- max theta difference;
- Newton iterations and reduced dimension.

## Frozen mechanism classes

### `QUALIFIED_Z32_INTERFACE_FLUX_MISMATCH`

Use if the dominant non-roundoff discrepancy is already present in the face-13/14 trapezoidal flux term and accounts for >=80% of the guard-equation difference.

### `QUALIFIED_Z32_TAIL_RECONSTRUCTION_MISMATCH`

Use if the dominant discrepancy comes from reconstructed tail head/flux/storage terms, with >=80% attribution to nodes 14:16.

### `QUALIFIED_Z32_GUARD_STORAGE_MISMATCH`

Use if face flux and reconstructed-tail terms are roundoff-equivalent but the guard-node storage term differs materially.

### `QUALIFIED_Z32_MIXED_INTERFACE_MECHANISM`

Use if no single component reaches the 80% attribution criterion consistently across both fixtures.

### `Z32_ATTRIBUTION_COVERAGE_FAILED`

Use if fewer than 4/6 frozen stable n=13 points are available in either fixture.

## Numerical significance rule

A component is treated as roundoff-scale only when its absolute contribution is <= 64 machine eps times an appropriate local scale.

Do not introduce an empirical physical tolerance.

## Consequence

A single-component positive attribution authorizes a separately preregistered correction candidate that changes only the implicated reduced equation/reconstruction term.

A mixed result requires one further decomposition before any correction.

## Stop rules

Do not:

- alter dt or forcing;
- alter full-reference trajectory;
- let reduced candidates drive state;
- tune thresholds;
- redistribute mass;
- add hysteresis or anti-chatter logic;
- introduce a fitted correction.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z32

BASELINE: `380bc7ab3160d28818244c0478855846ac6837a7`

BRANCH: `research/f-pe-nlglob14z32-n13-interface-attribution`

NEXT SAFE STEP: materialize observer-only stable n=13 decomposition and execute both fine fixtures.

## Production boundary

Research attribution only.

`LEGACY_NUMERICS` remains production default.
