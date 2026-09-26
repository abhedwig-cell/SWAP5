# F-PE-PROFILE04 — post-admission end-to-end performance rebaseline

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

Canonical authority at start:
`integration/f-ci-canonical@c52454b31d6f5d6ae6ed6af56460f158ddb45008`

## Question

After canonical admission of H03, ZERO-WASTE B1/B2, PLANVALID01 and default-OFF F-AHL50, where does production-shaped MultiSWAP runtime now go?

PROFILE04 measures the new baseline before any further optimization.

## Hard rule

PROFILE04 is observation-only.

No production source modification is allowed in this work unit. If a new hotspot is found, repair belongs to a separately preregistered follow-up.

## Measurement dimensions

Measure at minimum:
- N=1;
- N=1,000;
- N=10,000.

Separate:
1. application/bootstrap/setup;
2. repeated execution/runtime.

For repeated execution, recover as much attribution as current production diagnostics permit:
- Reference Richards / transaction interval;
- nonlinear iterations and candidate/backtracking work;
- constitutive/hydraulic evaluation;
- directional response/tangent;
- groundwater plan/context/coupling;
- orchestration and residual overhead.

## Modes

At minimum compare:
- canonical default behavior, with F-AHL50 OFF;
- qualified F-AHL50 opt-in within its exact envelope.

Do not introduce approximate tolerances, practical-mode physics, K lookup, layered AHL support or new solver policy.

## Primary outputs

PROFILE04 must answer:
- total end-to-end setup scaling after PLANVALID and B2;
- repeated per-column runtime scaling;
- measured total benefit of the currently admitted exact performance stack;
- residual dominant hotspot(s);
- whether further exact optimization remains worthwhile before opening practical/approximate mode.

## Interpretation rule

Do not add percentages from isolated historical microbenchmarks. End-to-end measurements on the canonical postimage are authority for total runtime claims.

## Initial harness reuse

Prefer existing canonical production-shaped fixtures and runners:
- PROFILE03 application-host timing fixture for Reference/directional repeated cost;
- PLANVALID application timing for setup scaling;
- F-AHL49/50 application-scale and application-opt-in fixtures for direct-retention setup/application behavior;
- FKT22/PPA-WU01 diagnostics as preservation oracles.

New code in PROFILE04 must remain under tests/research/docs/workflows only.

## Closure

PROFILE04 closes with a hotspot map and a recommendation for exactly one next performance work unit or for opening the approximate/practical phase.
