# F-PE-MIQUAL09 result — paired equilibrium serialized-runtime benchmark

Date: 2026-10-01

Status:

`MIQUAL09_EQUILIBRIUM_PERFORMANCE_NOT_READY`

Qualification execution:

- workflow run: `36827119602`;
- job: `110255173177`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

## Preflight

Both 40,000-interval trajectories complete.

LEGACY:

- 40,000/40,000 commits;
- zero retries;
- deterministic work: 1,920,000;
- maximum mass residual: 0;
- final tail: 13.

MANAGER:

- 40,000/40,000 commits;
- 40,000 reduced routes;
- zero fallback;
- zero bypass;
- deterministic work: 1,560,000;
- maximum mass residual: 0;
- final tail: 13.

Full final state is identical:

- max pressure-head difference: 0;
- max water-content difference: 0;
- storage difference: 0;
- tail difference: 0.

Deterministic work ratio:

`0.8125`

Equivalent deterministic work reduction:

`18.75%`.

## Paired timing result

Exactly 11 frozen paired measurements completed. No pair was removed.

Paired MANAGER/LEGACY wall ratios:

1. 1.04768
2. 1.05040
3. 1.04282
4. 1.05392
5. 1.05947
6. 1.06656
7. 1.05555
8. 1.05538
9. 1.05195
10. 1.07299
11. 1.05896

Median paired wall ratio:

`1.05538`

Geometric-mean paired wall ratio:

`1.05594`

Median CPU ratio:

`1.05532`

Thus the serialized manager route is approximately 5.5% slower on this equilibrium benchmark despite 18.75% lower deterministic nonlinear work.

The wall and CPU results agree closely, so the observed penalty is not explained by external scheduler noise alone.

## Interpretation

This is a genuine performance-negative result for the current production-shaped runtime adapter on the equilibrium workload.

The manager itself still performs less nonlinear row work and remains physically exact, but the runtime composition overhead exceeds the saving produced by reducing the solve from n=16 to n=13.

Likely overhead classes to investigate next include:

- repeated saturated-tail/view derivation;
- reduced-request state copying;
- reduced source/sink scratch handling;
- repeated provider binding;
- full-candidate rematerialization;
- adapter diagnostics/finalization;
- repeated manager composition across the full/half/half transaction pattern.

No one mechanism is yet qualified as dominant.

## Qualified claim boundary

Qualified:

- exact serialized runtime semantics;
- 100% reduced routing;
- zero fallback/bypass;
- 18.75% deterministic work reduction;
- robust paired evidence that current adapter is about 5.5% slower on this equilibrium case.

Not qualified:

- dynamic runtime performance;
- attribution of the overhead to a specific component;
- whole-SWAP or MultiSWAP performance;
- production admission for speed.

## Consequence

Open:

`F-PE-MIQUAL10 — serialized manager overhead attribution and zero-waste adapter audit`.

MIQUAL10 must preserve all manager physics and eligibility. It may optimize only runtime composition/scratch/copy/binding overhead and must re-run MIQUAL09 unchanged after any candidate optimization.

## Production boundary

No default change.

`LEGACY_NUMERICS` remains production default.
