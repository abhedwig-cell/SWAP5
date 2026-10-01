# F-PE-MIQUAL07 result — production-shaped serialized runtime benchmark

Date: 2026-10-01

Status:

`MIQUAL07_DYNAMIC_REFERENCE_BLOCKED`

Qualification execution:

- workflow run: `36826309775`;
- job: `110252665090`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

## Frozen preflight outcome

### W0 EQUILIBRIUM

LEGACY:

- 4,000/4,000 intervals committed;
- zero retries;
- 12,000 nonlinear iterations;
- 12,000 Jacobian builds;
- deterministic work index: 192,000;
- maximum mass residual: 0;
- final tail: 13.

MANAGER:

- 4,000/4,000 intervals committed;
- 4,000/4,000 reduced routes;
- zero fallback;
- zero bypass;
- zero retries;
- 12,000 nonlinear iterations;
- 12,000 Jacobian builds;
- deterministic work index: 156,000;
- maximum mass residual: 0;
- final tail: 13.

Full-state final equivalence:

- max pressure-head difference: 0;
- max water-content difference: 0;
- storage difference: 0;
- tail difference: 0.

Deterministic work ratio:

`156000 / 192000 = 0.8125`

Equivalent work reduction:

`18.75%`.

The single preflight wall observation was approximately:

- LEGACY: 0.07038 s;
- MANAGER: 0.06592 s;
- ratio about 0.9367.

This is not a qualified timing result because the preregistered paired timing phase was not entered after W1 reference failure.

### W1 MILD_DYNAMIC

The preregistered full-reference LEGACY workload fails before the first accepted interval.

Observed:

- last accepted interval: 0;
- attempts: 3;
- retries: 2;
- solver status: converged on the trial attempts;
- solver rejection: 0;
- mass rejection: 0;
- failure occurs through transaction candidate rejection after temporal refinement;
- manager run shows the same outer transaction failure pattern.

Therefore the frozen classification is:

`MIQUAL07_DYNAMIC_REFERENCE_BLOCKED`.

Per preregistration, dt, temporal tolerance and workload forcing are not changed after this exposure.

## Interpretation

MIQUAL07 does not falsify the moving-interface manager.

The equilibrium production-shaped serialized route is fully operational and physically identical, with deterministic work reduction of 18.75%.

The blocker is that the selected dynamic benchmark is not a valid serialized LEGACY reference workload under the frozen transaction settings. The full-reference solver itself converges, but the outer full-half temporal transaction does not accept the interval.

Because the reference workload is invalid, the paired performance phase is formally not entered and no production runtime speedup claim is made.

## Qualified claim boundary

Supported by MIQUAL07:

- production-shaped serialized equilibrium trajectory;
- 4,000 real checkpoint/trial/commit cycles;
- 100% reduced manager routing on the eligible state;
- zero fallback/bypass;
- exact final-state equivalence;
- 18.75% deterministic nonlinear-work reduction.

Not qualified by MIQUAL07:

- paired runtime speedup;
- dynamic production-shaped throughput;
- production admission;
- MultiSWAP performance;
- broader optional-process envelope.

## Consequence

Do not retune W1 in MIQUAL07.

Open a separate reference-workload acquisition workunit that searches existing repository-backed serialized-reference dynamic fixtures for a case that:

- already completes through the transaction layer;
- remains inside the MIQUAL06 manager eligibility envelope;
- has nontrivial physical evolution;
- can serve as an unbiased LEGACY/MANAGER benchmark.

Only after such a reference workload is identified should paired timing resume.

## Production boundary

No production-default change.

`LEGACY_NUMERICS` remains production default.
