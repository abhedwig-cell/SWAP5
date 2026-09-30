# F-PE-ELASTIC58 — independent mode-7 Reference head-budget calibration preregistration

Date: 2026-09-30

Status: PREREGISTERED_REFERENCE_ONLY_RESEARCH

Parent authority:
- F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN;
- F-CI14 — no independently qualified numeric temporal limits;
- PUB-P2E08/P2E09 — independent Reference-only temporal calibration method for a different prescribed-bottom-flux domain.

Parent ELASTIC57 head:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`.

Canonical authority at start:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`.

## Purpose

Construct an independent Reference-only empirical head-error budget for the
specific bottom-mode-7, swkimpl=0 free-drainage domain.

ELASTIC58 deliberately does not evaluate:
- the mode-7 defect indicator;
- the ELASTIC54 alpha scaling;
- C-SAFE;
- any production acceptance policy.

Those remain firewalled until the Reference-only budget is frozen.

## Why P2E09 is not reused directly

PUB-P2E09 froze Reference self-disagreement envelopes for an E0 experiment with
prescribed bottom flux.

ELASTIC53-57 concerns bottom mode 7 free drainage.

The P2E09 values are therefore methodological precedent, not transferable
mode-7 tolerances.

## Physical calibration domain

Reuse the pre-existing independent E0 material/state axes:

Materials:
- B01;
- B12;
- O01;
- O05;
- O14;
- O18.

Effective saturation:
- Se = 0.65;
- Se = 0.85;
- Se = 0.98.

Forcing labels and perturbation factors inherited from P2E08:
- DRYING: factor = -0.005;
- NOMINAL: factor = +0.010;
- WETTING: factor = +0.025.

For each material/state:
- derive h0 from exact van Genuchten effective-saturation inversion;
- evaluate initial K0;
- free-drainage equilibrium top flux is `qeq = -K0`;
- apply `qtop = qeq + factor*K0`;
- bottom mode is 7 and bottom flux remains solver-owned free drainage.

No prescribed qbot is supplied as physical authority.

Grid:
- 16 homogeneous cells;
- 10 cm each.

Sources/sinks:
- zero.

ELAS:
- OFF only.

Rationale:
the temporal budget must be calibrated independently of the ELAS candidate whose
controller will later consume it.

## Numerical envelope

Reference solver only.

Frozen settings:
- max_iterations = 16;
- max_backtracking = 8;
- swkimpl = 0;
- conductivity mean method = 1;
- compartment and total balance tolerance = 1e-12;
- head abs/rel tolerance = 1e-12;
- ponding tolerance = 1e-12.

Candidate coarse dt values, inherited from P2E08:
- 0.0016 day;
- 0.0032 day;
- 0.0064 day;
- 0.0128 day;
- 0.0256 day.

At every candidate dt, execute every one of the 54 physical combinations as:
- one full Reference solve over dt;
- two sequential Reference solves over dt/2 + dt/2.

Do not stop after the first feasible dt.

## Trajectory validity

A physical pair is valid only when:
- full, half1 and half2 all return SW_SOLVE_CONVERGED;
- all states are finite;
- integrated mass residual is available and <= 1e-12 cm in absolute value for
  every solve;
- endpoint shapes match;
- full and two-half endpoints represent the same final physical time.

No tolerance widening or case removal is permitted.

## Common-dt selection

After all 270 physical-pair/dt combinations are executed:

Select the **smallest candidate coarse dt** for which all 54 physical
combinations are valid.

If none exists:
`BLOCKED_MODE7_REFERENCE_COMMON_DOMAIN`.

This selection rule is prospective and does not inspect any defect indicator.

## Reference self-disagreement dataset

At the selected common dt, retain all 54 physical cases and compute:

Primary:
- `U_h_inf_cm = max |h_full - h_twohalf|`.

Secondary:
- head RMS;
- theta infinity norm;
- theta RMS;
- absolute storage difference.

Mass remains a separate hard gate.

## Head-budget freeze

For each exact Se stratum, define:

`H_budget(Se) = max U_h_inf_cm`

over all 18 material x forcing cases in that stratum.

No multiplier.
No application floor.
No interpolation between Se strata.
No material- or forcing-specific threshold.

This is an empirical Reference self-disagreement envelope for this exact mode-7
calibration domain, not a universal SWAP accuracy requirement.

## Hypotheses

H1. A common mode-7 Reference dt exists for all 54 physical cases.

H2. Head self-disagreement varies materially by Se, justifying the already
predeclared Se stratification.

H3. The resulting exact-stratum head budgets can be frozen without using any
ELASTIC53-57 indicator result.

## Gates

A1. Execute exactly 54 cases at all five candidate dt levels.

A2. O0/O2 semantic identity.

A3. Common-dt selection follows the frozen smallest-valid-dt rule exactly.

A4. No case removal.

A5. Frozen head budgets equal the exact empirical maxima in each Se stratum.

A6. Indicator/alpha/controller code is not executed for calibration.

A7. Zero `src/**` production changes.

## Decision

A green ELASTIC58 qualifies only:

`REFERENCE_ONLY_MODE7_HEAD_BUDGET_RESEARCH_AUTHORITY`.

It does not qualify:
- full F-CI14 eight-metric production limits;
- a mode-7 production temporal policy;
- defect-indicator admission;
- controller integration;
- ELAS defaults.

A later workunit must independently test the defect-indicator/controller against
the frozen ELASTIC58 head budgets.
