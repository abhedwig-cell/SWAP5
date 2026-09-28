# F-PE-BOFEK00 — canonical admission closeout

Date: 2026-09-28

## Final status

F-PE-BOFEK00 is **CANONICAL_ADMITTED**.

Current canonical head:

`integration/f-ci-canonical@4e93b1ee82db3521e4e967b8b08a493efad9140a`

Correctness admission:

- PR #701;
- merge commit `f670e012ab028cc1e74bb9b7aa1b8655b545619c`;
- admitted scope: fixed top-node conductivity, dynamic top boundary, `SWKIMPL=0`.

Post-admission preservation reconciliation:

- PR #702;
- merge commit `4e93b1ee82db3521e4e967b8b08a493efad9140a`;
- governance/test-only reconciliation;
- no production source changes.

## Defect classification

Final classification:

`B. DEFECT_CONFIRMED_CURRENT_REFERENCE`

The admitted correction covers two independently reproduced defects:

1. the incomplete dynamic wet top-boundary Jacobian;
2. Newton-candidate/dt-dependent branch selection before the supported analytical linear-runoff solution.

## Correctness versus timestep policy

The correction itself changes no timestep-policy constant, tolerance, DTMIN, DTMAX, growth/decrease factor or mass gate.

Frozen-timestep qualification used 24 identical `0.005 day` steps.

Baseline versus corrected:

- nonlinear iterations: 117 -> 98;
- backtracks: 117 -> 98;
- cumulative runoff: `0.4493205111812004 -> 0.4493205111812251 cm`;
- physical trajectory differences: round-off scale;
- water ledger: O(`1e-14 cm`).

Therefore the solver/top-boundary correction does not materially change the physical solution under an identical timestep sequence.

The separately preregistered historical SWAP TimeControl comparison used identical policy inputs on both solvers.

Baseline versus corrected:

- accepted steps: 14 -> 8;
- nonlinear iterations/backtracks: 71 -> 38;
- growth events: 1 -> 2;
- rejected attempts: 0 -> 0;
- cumulative runoff: `0.4614801661367161 -> 0.4843261930227983 cm`;
- water ledger: about `4.52e-14 cm` in both.

Because frozen-dt runoff is unchanged at round-off scale, the adaptive runoff difference is attributed to the unchanged timestep controller reacting to changed solver iteration counts. It is not a direct physical change caused by the Jacobian correction.

## Scope boundary

Admitted:

- fixed top-node conductivity;
- dynamic top boundary;
- `SWKIMPL=0`;
- supported analytical `RSROEXP=1` linear-runoff route.

Not admitted by BOFEK00:

- `SWKIMPL=1` dynamic-head Jacobian behavior;
- a new timestep policy;
- BOFEK-specific DTMIN/DTMAX values;
- convergence-tolerance broadening;
- runtime speed claims from wall-clock microbenchmarks.

## BOFEK consequence

The prerequisite gate for timestep/convergence optimization is now open for the admitted fixed-K, `SWKIMPL=0` Reference surface.

Therefore F-PE-BOFEK01/02 may start on that scope.

Wet-regime small timesteps should no longer be interpreted using the pre-BOFEK00 Reference authority. New BOFEK performance conclusions must use canonical at or after `4e93b1ee82db3521e4e967b8b08a493efad9140a`.

Any study using `SWKIMPL=1` remains separately gated pending an independent Jacobian qualification.

## Durable authority

Primary evidence remains:

- `docs/verification/F-PE-BOFEK00_PREREGISTRATION.md`;
- `docs/verification/F-PE-BOFEK00_ADAPTIVE_PREREGISTRATION.md`;
- `docs/verification/F-PE-BOFEK00_QUALIFICATION.md`;
- `docs/verification/evidence/F-PE-BOFEK00_CURRENT_AUTHORITY_REPRODUCTION.json`;
- `docs/verification/evidence/F-PE-BOFEK00_FROZEN_RESULT.json`;
- `docs/verification/evidence/F-PE-BOFEK00_ADAPTIVE_RESULT.json`;
- PR #701;
- PR #702;
- `integration/audits/F-PE-BOFEK00_STATUS.json`.

No further production work belongs to F-PE-BOFEK00.
