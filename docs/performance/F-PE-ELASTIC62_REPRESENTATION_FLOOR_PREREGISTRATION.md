# F-PE-ELASTIC62 — representation-floor attribution preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authorities:
- F-PE-ELASTIC60 — QUALIFIED_HALF1_TOTAL_BALANCE_FLOOR_CANDIDATE
- F-PE-ELASTIC61 — QUALIFIED_VERIFICATION_TOTAL_BALANCE_FLOOR_CAUSALITY
- PUB-P2E07 — qualified Reference cancellation/representation-floor diagnostic
- F-PE-BALTOL02 — production-admitted scaled Reference balance floor

Parent postimage:
`research/f-pe-elastic61-total-balance-sensitivity@dd39ca8c628a0efd2f58264aab8d33acf2c57a74`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

Are the six strict half1 total-balance failures consistent with the already
qualified P2E07 theta-input representation floor, rather than with a physically
meaningful unresolved water-balance defect?

## Frozen cases

Exactly the six baseline strict half1 failures:
- profile 8016;
- h0 = -20 cm;
- delta = +0.035 and +0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- half-step dt = 0.00048828125 day;
- compartment balance tolerance = 1e-12;
- total balance tolerance = 1e-12.

No tolerance is changed in ELASTIC62.

## P2E07 node-local floor

For node i, reproduce the P2E07 storage-input quantization scale:

`floor_i = 0.5 * (spacing(theta_internal_i) + spacing(theta_base_i)) * dz_i / dt`.

Where:
- `theta_internal_i` is the failed internal Reference state;
- `theta_base_i` is the half1 base-state water content;
- `dz_i` is compartment thickness;
- dt is the actual half1 solve duration.

Record:
- max local floor;
- node of max local floor;
- sum of local floors;
- dt * max local floor;
- dt * sum local floors.

## Residual comparison

Record from the failed half1 solve:
- max abs local residual;
- node of max local residual;
- abs total residual sum.

Diagnostic ratios:

`R_local = max_abs_local_residual / max_local_floor`.

`R_total = abs(sum residual) / sum(local floors)`.

Interpretation boundary:
- R <= 1 means the observed residual is at or below this diagnostic
  representation scale;
- this does not prove one specific arithmetic operation caused the residual;
- it does not define a replacement tolerance.

## Existing admitted BALTOL02 floor

Also report:

`BALTOL_depth = 2.8e-16 cm`.

`BALTOL_rate = max(1e-12, BALTOL_depth/dt)`.

At the frozen half1 dt this admitted rate is expected to remain 1e-12.

ELASTIC62 must not change BALTOL02.

## Hypotheses

H1. The max local residual is at or below the P2E07 local representation floor.

H2. The total residual sum is at or below the conservative sum of the P2E07
node-local floors.

H3. The aggregate integrated representation scale can exceed the single
BALTOL02 integrated-depth floor for this heterogeneous 16-node profile.

H4. OFF/FIXED/GENERATED remain identical because the failed trajectory is
unsaturated.

## Gates

A1. Exactly six strict half1 cases execute.

A2. O0/O2 diagnostics agree.

A3. Every floor/residual diagnostic is finite and nonnegative.

A4. P2E07 formula is reproduced exactly as preregistered.

A5. No tolerance, solver, physics or production source change.

## Decision

ELASTIC62 is diagnostic only.

A positive result may justify a separate research workunit on how a total-balance
criterion should aggregate node-local representation floors.

It does not authorize changing BALTOL02 or any production tolerance.
