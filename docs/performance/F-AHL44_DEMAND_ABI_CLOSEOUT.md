# F-AHL44 — post-zero-waste demand-ABI performance reconciliation

Date: 2026-09-25

Status: `CLOSED_NEGATIVE_PERFORMANCE_REQUALIFICATION`

Parent production authority: admitted F-PE-PLANVALID01 postimage `df664f56cf09ee8479701f15fe10ee02d31a9536`.

PR: #612.

## Why this workunit was required

The historical F-AHL policy-4 research and canonical candidate branches were developed against an older constitutive-provider ABI in which providers exposed only `evaluate()`.

The current post-zero-waste Reference solver has a demand-aware ABI:

- `evaluate_demand(WATER_CONTENT)`;
- `evaluate_demand(CAPACITY)`;
- point conductivity support;
- phase-specific constitutive diagnostics.

HeadCalc now uses theta-only candidate demand in the explicit-conductivity backtracking path.

Therefore historical F-AHL timing could not be transferred directly to the current production postimage. Without an override, an old adaptive provider inherits the generic `evaluate_demand()` fallback, which calls the full adaptive `evaluate()`.

F-AHL44 reconciled the existing policy-4 representation with the current demand-aware ABI before making any new speed claim.

## Representation boundary

F-AHL44 did not retune or redesign policy 4.

Retained:

- derivative-consistent theta/C representation;
- independent K representation;
- policy version 4;
- global K tolerance 1e-4;
- K relevance floor 1e-10 cm/d;
- raw-C dry relevance floor 1e-13;
- analytical fallback outside represented domain.

Added for measurement:

- demand-aware WATER_CONTENT evaluation;
- demand-aware CAPACITY evaluation.

Other demand masks retain safe full-evaluate fallback in this reconciliation candidate.

No production routing or boundary-mode envelope was broadened.

## Demand semantics

Workflow run `36150647135` PASS.

The direct provider gate establishes:

- theta-only adaptive demand is bit-identical to theta returned by the same policy-4 full adaptive evaluation for the same head vector;
- capacity-only adaptive demand is bit-identical to capacity returned by the same policy-4 full adaptive evaluation;
- analytical fallback behavior remains represented through the same provider policy.

Thus the demand specialization itself does not change the adaptive representation.

## Direct demand timing

Current-postimage O3 provider timing, N=60, 200,000 replays:

| route | ns/call |
| --- | ---: |
| analytical theta-only demand | 2,297 |
| adaptive theta-only, shared registry handle | 4,549 |
| adaptive theta-only, provider-local table | 4,949 |
| adaptive full evaluation | 6,028 |

Interpretation:

- demand specialization reduces adaptive cost relative to adaptive full evaluation by roughly 25%;
- nevertheless adaptive theta-only demand remains about 1.98x slower than current analytical theta-only demand;
- provider-local table ownership does not repair the performance gap; it was slightly slower on this workload.

An earlier same-workunit runner produced the same ordering, with analytical theta ~1.88 us, adaptive theta ~4.40 us and adaptive full ~5.35 us.

Absolute timings are shared-runner observations. The repeated ordering and ratios are the stronger result.

## Current-postimage prescribed-head Richards test

Workflow run `36151003611` PASS.

Fixture:

- B01 hydraulic authority;
- 4 active nodes from the qualified Reference HeadCalc stub;
- prescribed-head bottom mode 5;
- h0 = -75 cm;
- hbot = -50 cm;
- dt = 0.25 day;
- explicit conductivity;
- seven paired analytical/adaptive timing repetitions;
- 10,000 solves per timed member;
- build and provider binding outside timed solve loops.

Fidelity:

- max absolute pressure-head delta: ~1.04e-6 cm;
- max absolute theta delta: ~1.14e-9;
- nonlinear iterations: 4 versus 4;
- backtracking attempts: 4 versus 4;
- candidate-demand calls: 4 versus 4.

The current policy-4 representation therefore retains excellent physical fidelity and the exact nonlinear path on this fixture.

Paired runtime ratios adaptive/analytical:

- 1.4521
- 1.5408
- 1.5326
- 1.5393
- 1.5338
- 1.5405
- 1.4824

Median ratio: `1.533815`.

Thus the demand-aware policy-4 adaptive route is about 53% slower than the current analytical Reference route on this bounded prescribed-head workload.

## Reconciliation with historical F-AHL timing

Historical F-AHL timing was generated before the current demand-specialized constitutive path existed.

Those results remain valid evidence for their historical source postimages. They are not valid performance authority for the current post-zero-waste production architecture.

In particular, the earlier bounded serialized gains of approximately 2.9–4.5% must not be used as current admission evidence without current-postimage requalification.

F-AHL44 provides current-postimage evidence in the opposite direction for B01 prescribed-head execution.

## Relation to NEWTON-CANDIDATE01

NEWTON-CANDIDATE01 established that difficult Reference trajectories can execute O(100) theta-only candidate demands.

F-AHL44 shows that the current policy-4 adaptive implementation does not exploit that opportunity:

- current analytical theta-only demand is already cheaper;
- repeating the adaptive demand more often would amplify a cost penalty, not a speed benefit.

Therefore the NEWTON-CANDIDATE01 handoff does not validate the current F-AHL implementation as the performance solution.

It instead falsifies the assumption that the existing adaptive table architecture is automatically beneficial on the new demand-aware solver.

## Scientific versus performance status

Scientific representation:

`RETAINS_VALUE`

The derivative-consistent theta/C representation remains useful research and retains excellent bounded fidelity.

Current performance proposition:

`NOT_QUALIFIED / NEGATIVE_ON_MEASURED_CURRENT_POSTIMAGE`

This distinction is important. A scientifically sound representation need not be a faster implementation.

## Decision

1. Do not admit policy-4 adaptive hydraulics on the basis of historical speed evidence.
2. Do not enable it by default.
3. Do not broaden it to prescribed qbot; F-AHL41 analytical fallback remains authoritative.
4. Retain the representation and fidelity evidence as research authority.
5. Reopen performance only for a materially different implementation architecture that can beat demand-specialized analytical theta evaluation on the current postimage.

## What a future F-AHL performance design must beat

At minimum it must address the current lookup overhead:

- log10 transform per candidate head;
- interval location / shared-registry sample lookup;
- Hermite basis evaluation;
- logistic reconstruction;
- branch/fallback checks.

A future implementation must demonstrate direct theta-demand benefit first, before another full Richards speed claim is attempted.

Likely research directions include direct-index or otherwise O(1)-location representations, fewer transcendental operations, or purpose-specific generated approximants. These are new representation designs and require separate preregistration and fidelity qualification.

## Limitation

The full Richards requalification above uses the qualified 4-node Reference fixture. The direct provider result additionally covers N=60.

F-AHL44 does not claim that every large-node prescribed-head workload is 53% slower. It does establish that the historical broad positive-speed authority is no longer transferable and that current theta-only candidate demand is slower at N=60.

## Closeout verdict

`F-AHL44 = CLOSED_NEGATIVE_CURRENT_POSTIMAGE_PERFORMANCE_REQUALIFICATION`

`POLICY4_FIDELITY = RETAINED`

`POLICY4_CURRENT_SPEED_AUTHORITY = WITHDRAWN_PENDING_NEW_IMPLEMENTATION`
