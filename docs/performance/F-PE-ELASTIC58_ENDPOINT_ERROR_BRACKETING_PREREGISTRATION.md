# F-PE-ELASTIC58 — mode-7 multi-metric endpoint-error bracketing preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent postimage:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Purpose

Build the independent physical endpoint-error evidence needed before any
numeric mode-7 temporal budget is selected.

F-CI14 requires explicit unit-aware endpoint limits and deliberately contains
no numeric defaults. ELASTIC58 therefore does not choose a tolerance.

## Frozen bank

Replay exactly the ELASTIC55/56/57 four-profile bank:
- profiles 11060, 10260, 8016, 3030;
- same Staringreeks retention materialization;
- same generated Ss;
- bottom mode 7, swkimpl=0;
- fixed-flux top boundary;
- states -75, -20, +2, +10 cm;
- perturbations -0.05, -0.035, +0.035, +0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder.

## Reference comparison

For every case where full, half1 and half2 all converge, compare the one-full
endpoint F with the two-half endpoint H at the same physical t1.

Record:
- H_INF = max_i |h_F-h_H| [cm];
- THETA_INF = max_i |theta_F-theta_H| [-];
- STORAGE_SIGNED = |sum_i dz_i*(theta_F-theta_H)| [cm water];
- STORAGE_L1 = sum_i dz_i*|theta_F-theta_H| [cm water];
- ponding difference [cm];
- groundwater-level difference [cm];
- absolute bottom-flux difference |qbot_F-qbot_H| [cm/day];
- relative bottom-flux difference against max(|qbot_F|,|qbot_H|,1e-30);
- research Binf [cm] and frozen alpha-scaled envelope.

No optional crop, solute, thermal, snow, macropore or evaporation-memory state
is active in this bounded workunit.

## Questions

1. Which endpoint quantities actually differ materially when H_INF is nonzero?
2. Does local head error map predictably to theta/storage/qbot error across
   profiles and ELAS regimes?
3. Does the frozen alpha*Binf envelope remain conservative for head error?
4. Which metrics are effectively exact/roundoff-level and therefore poor
   candidates for calibrating a practical numeric limit?

## Gates

A1. Exact parent profile selection replay.
A2. All 1728 requested cases execute.
A3. O0/O2 semantic identity.
A4. Metrics are reported only for paired-converged endpoints.
A5. Every reported metric is finite and nonnegative.
A6. STORAGE_SIGNED <= STORAGE_L1 within roundoff.
A7. Frozen alpha is unchanged; no numeric endpoint limit is selected.
A8. Zero src/** production changes.

## Decision

ELASTIC58 may qualify a multi-metric physical error characterization only.

It does not authorize a numeric temporal budget, production mode-7 indicator,
controller integration, or any relaxation of hard mass acceptance.
