# F-PE-REPRO02 R2 — solver-effort cap sensitivity

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R1 localized difficult-origin nonzero corrector rejection to the nonlinear Richards solve.

The failing participant route uses:

- max nonlinear iterations = 16;
- max backtracking = 8.

The successful offline P0 direct-solver characterization used:

- max nonlinear iterations = 48;
- max backtracking = 16.

## Question

Does increasing only the available nonlinear/backtracking effort restore exact participant admissibility for +/-0.001 cm difficult-origin correctors?

## Test-only variants

Use the same exact participant and same state/forcing authority.

Compare:

- 16 / 8  — current participant policy;
- 32 / 8;
- 16 / 16;
- 32 / 16;
- 48 / 16.

No tolerance, timestep, constitutive, temporal or mass policy changes.

## Cases

All six frozen difficult PROFILE06 origins.

Offsets:

- -0.001 cm;
- +0.001 cm.

Fresh process per point.

Three repetitions per point/variant are sufficient if signatures are deterministic.

## Measurements

Report:

- participant PASS/FAIL;
- solver status;
- nonlinear iterations;
- backtracking attempts;
- internal retries;
- temporal certificate availability when reached.

## Interpretation

If larger effort limits restore convergence, the collapsed transaction frontier is an iteration/backtracking-cap phenomenon.

If 48/16 still fails, the cause is deeper than the current effort caps and R3 must inspect Newton path/state construction.

No production cap change is admitted by R2.
