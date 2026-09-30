# F-PE-ELASTIC59 — accepted-but-unpaired oracle attribution preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent:
`F-PE-ELASTIC58 — QUALIFIED_EXTERNAL_HEAD_BUDGET_TRANSFER_WITH_UNPAIRED_COVERAGE_GAP`

Parent postimage:
`research/f-pe-elastic58-physical-budget-transfer@a9678e4780caaa303d10a8c7eb27930a4801b1b0`

## Question

Why do the six C-SAFE accepted profile-8016 cases lack a paired two-half oracle?

## Frozen cases

Profile:
- 8016, soilunit EZg21.

State:
- h0 = -20 cm.

Perturbations:
- +0.035 cm/day;
- +0.05 cm/day.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Accepted dt:
- 0.0009765625 day.

Total:
- 6 physical cases.

The principal full solve remains exactly the ELASTIC58 production-shaped solve
with max_iterations=16.

## Oracle-only sensitivity

Only the verification half1/half2 solve budget may vary:

- 16;
- 32;
- 64;
- 128 nonlinear iterations.

All other numerical settings remain unchanged, including:
- max_backtracking;
- tolerances;
- boundary mode;
- forcing;
- constitutive physics;
- grid;
- generated Ss.

No production acceptance decision is recomputed.

## Observations

For each case and oracle budget record:
- full solve status;
- half1 status;
- half2 status;
- nonlinear iterations;
- whether paired oracle becomes available;
- H_INF and DTHETA_INF if paired;
- frozen head limit 0.01 cm;
- frozen theta limit 1e-5;
- frozen global envelope alpha*Binf where available.

## Attribution

Classify each physical case:

ORACLE_BUDGET_LIMIT
- maxit=16 unpaired;
- at least one higher oracle budget yields paired convergence;
- full solve remains converged and unchanged.

PERSISTENT_HALF_SOLVE_FAILURE
- no tested oracle budget yields paired convergence.

MIXED
- paired convergence appears/disappears non-monotonically across oracle budgets.

## Gates

A1. Exactly the six ELASTIC58 unpaired accepted cases are tested.

A2. Full solve remains converged and semantically identical across oracle-budget arms.

A3. O0/O2 classifications agree.

A4. Any newly paired oracle must satisfy H_INF <= 0.01 cm and DTHETA_INF <= 1e-5 to support coverage recovery.

A5. No production source change.

## Decision

ELASTIC59 is verification attribution only.

A positive oracle-budget result does not authorize changing production solver
iteration limits. It may only justify a stronger independent verification
harness for budget qualification.
