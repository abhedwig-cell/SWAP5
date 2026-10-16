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


## First canonical rebaseline — run 36220439795

Measurement harness: PASS.

Setup / PLANVALID:
- N=1,000 init median ratio: `0.794129647` (about 20.6% lower initialization time);
- N=10,000 init median ratio: `0.331913495` (about 66.8% lower initialization time);
- repeated runtime median ratio N=1,000: `0.997181068`;
- repeated runtime median ratio N=10,000: `1.009564701`.

Interpretation: PLANVALID remains a setup optimization. At large N it removes about two thirds of initialization time in this paired measurement, while repeated runtime is effectively unchanged.

F-AHL50 setup overhead relative to analytical/default:
- N=1: `5.782847486`;
- N=100: `1.522545495`;
- N=1,000: `1.115894884`;
- N=10,000: `1.029505412`.

Interpretation: representation construction is expensive for a single column but amortizes strongly under shared immutable ownership. At N=10,000 the measured setup premium is about 2.95%.

Repeated Reference exact-P0 stack:
- mean ratio: `0.726864148`;
- median ratio: `0.726495766`;
- mean speedup: about 27.31%.

Repeated directional exact-P0 stack:
- mean ratio: `0.759275664`;
- median ratio: `0.761371085`;
- mean speedup: about 24.07%.

These repeated-runtime ratios compare the current exact-P0 postimage against the historical pre-ZERO-WASTE baseline used by the qualified paired harness. They are not yet a full MultiSWAP+MODFLOW end-to-end wall-clock ratio.

## Immediate finding

The admitted exact performance stack has preserved substantial repeated-runtime gains while large-N setup overhead has been sharply reduced.

The next PROFILE04 measurement must add a true aggregate application/coupling wall-clock comparison with F-AHL50 OFF versus ON on the same current canonical postimage. That is required before claiming a total end-to-end speedup percentage.
