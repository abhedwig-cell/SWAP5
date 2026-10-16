# F-PE-APPROX02 A2C preregistration — strict-practical Richards convergence envelope

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX02 — practical Richards solve-effort frontier`

Predecessors:
- `A2 (1e-4) — REJECTED_COUPLED_ROBUSTNESS`;
- `A2B (1e-6) — REJECTED_COUPLED_ROBUSTNESS`.

## Candidate A2C

A2C changes only:

- head absolute tolerance: `1e-8`;
- head relative tolerance: `1e-8`;
- compartment balance tolerance: `1e-8`;
- total balance tolerance: `1e-8`.

Unchanged:

- ponding tolerance;
- transaction mass tolerance;
- timestep/temporal policy;
- retry policy;
- iteration/backtracking caps;
- constitutive physics;
- A1 cache state.

Default production behavior remains exact.

## Why one more tolerance point is justified

A2B at `1e-6` produced very small hydrological errors and strong direct speedup but still showed one new live coupled trial failure in three independent jobs.

A2C moves two orders of magnitude back toward the exact reference while still potentially reducing nonlinear effort in the hard wet cases.

This is the final fixed-tolerance candidate in APPROX02.

## Required gates

A2C must independently pass:

1. the 20-step material/regime trajectory matrix;
2. the canonical production application sequence;
3. three independent live SWAP + MODFLOW6 end-to-end jobs.

## Coupled rejection rule

A2C is rejected if any independent MODFLOW replica shows:

- a new SWAP trial failure;
- a coupling convergence failure;
- materially increased coupled iteration count;
- unexplained endpoint/ledger drift.

## Decision rule

If A2C passes all three coupled replicas and remains materially speed-positive, it may advance as the conservative practical Richards mode.

If A2C still shows a new trial failure, fixed global convergence-tolerance relaxation is rejected as a production lever for this coupling path. APPROX02 should then test a different solve-effort mechanism rather than continue with ever smaller tolerance changes.
