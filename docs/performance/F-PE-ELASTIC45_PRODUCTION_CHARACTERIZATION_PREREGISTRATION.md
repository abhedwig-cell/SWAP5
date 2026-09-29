# F-PE-ELASTIC45 — generated ELAS production-application numerical characterization

Date: 2026-09-29

Status: PREREGISTERED_RESEARCH_ONLY

Baseline:
`integration/f-ci-canonical@b6c9079c209eb6d1fe2db2fd61ff330941770166`

Work branch:
`research/f-pe-elastic45-production-characterization`

Parent authority:
- `F-PE-ELASTIC09_RESULT.md`;
- `F-PE-ELASTIC13_RESULT.md`;
- `F-PE-ELASTIC42_RD_END_TO_END_RESULT.md`;
- `F-PE-ELASTIC44_CLOSURE.md`.

## Research question

Characterize how three already-defined ELAS states affect the admitted production
Reference/Full-Richards application path under one identical controlled dynamic
forcing experiment:

1. ELAS OFF;
2. explicit uniform `1.0e-6 cm^-1`;
3. generated BOFEK/BRO mineral prior from the admitted ELASTIC24/33/44 chain.

The manual `1e-6` case is a descriptive comparison anchor only. It is not a
default, recommendation or parameter-policy candidate.

## Frozen real-source case

Use frozen BRO artifact SHA-256:

`f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

Use the deterministic real mineral profile already qualified by ELASTIC42:

`normalsoilprofile_id = 90116260`.

Materialize its exact ELASTIC33 row interchange from the frozen source artifact.
Construct one model node per source horizon, with node center and thickness
matching the source horizon geometry exactly.

The real BOFEK/BRO profile is authority for generated ELAS and grid geometry.
This work unit does not claim that the controlled hydraulic conductivity
fixture constitutes a complete real-site hydraulic calibration.

## Controlled hydraulic fixture

For each node, use the admitted Staringreeks retention parameters belonging to
that source horizon's Staringreeks block where available. Keep all non-ELAS
numerical and forcing settings identical across the three variants.

Where a production parameter is outside the ELASTIC20 retention catalog,
retain one fixed preregistered stable fixture value across all variants. Such
values are experimental controls, not inferred source data.

## Dynamic experiment

Use the admitted ELASTIC09 production application owner and serialized
Reference backend.

Start each variant from the same pressure-head field. Construct its initial water
content consistently from its own constitutive parameterization before the run.

Use identical top/bottom forcing across variants and one bounded non-equilibrium
perturbation. The perturbation may be reduced, but not increased, if the first
pre-registered forcing fails to complete any variant. Any such reduction must be
recorded as qualification-driven stabilization rather than hidden.

No convergence tolerance, retry policy or timestep policy may differ between
variants.

## Measurements

Record per variant:
- admitted/completed/committed class;
- accepted substeps;
- solver iterations;
- nonlinear iterations;
- internal retries;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- mass storage start/end;
- total input/output;
- mass residual;
- final pressure-head summary;
- final water-content summary;
- ponding;
- groundwater level.

Wall-clock runtime may be reported only as secondary descriptive evidence.
Solver-work counters are the primary numerical-effort measures.

## Gates

A1. frozen source hash and exact profile 90116260 identity: PASS.

A2. generated variant is produced by admitted ELASTIC44 composition and has
finite positive node-local ELAS: PASS.

A3. OFF variant is exact ELAS-inactive; manual variant is exactly
`1.0e-6 cm^-1` at every active node.

A4. all three variants use identical grid, non-ELAS numerical policy and
forcing.

A5. all three production application runs complete and commit with the existing
hard mass gate.

A6. per-variant solver-work and physical summary metrics are emitted.

A7. O0/O2 metrics are bit/numerically identical under the existing deterministic
qualification contract.

A8. generated-prior values remain within the already qualified ELASTIC13
physical policy and explicit/user ownership is not altered.

A9. zero production `src/**` changes. This is characterization only.

## Interpretation boundary

This experiment may establish that ELAS state changes numerical work under the
tested controlled case. It cannot establish:
- that `1e-6` is physically preferable;
- a universal speedup;
- a universal convergence benefit;
- a new timestep policy;
- a new ELAS fitting relation;
- geographic-coordinate support.

Performance observations must not be used to tune or choose the physical ELAS
prior.

## Decision classes

Green completion with interpretable metrics:
`QUALIFIED_PRODUCTION_APPLICATION_CHARACTERIZATION`.

No measurable solver-work difference:
`QUALIFIED_NULL_NUMERICAL_EFFECT_IN_TESTED_CASE`.

Stable completion impossible without changing physical/numerical ownership:
`ROUTE_BLOCKED_FOR_THIS_CHARACTERIZATION`.
