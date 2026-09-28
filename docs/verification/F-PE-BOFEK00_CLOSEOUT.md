# F-PE-BOFEK00 — wet-regime numerical authority closeout

Date: 2026-09-28

Status: **DEFECT_CONFIRMED_CURRENT_REFERENCE / QUALIFIED_ADMISSION_CANDIDATE**

## Authority

Canonical authority remained unchanged throughout qualification:

`integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`

Qualified correction lineage:

- reproduction/evidence authority: `work/f-pe-bofek00-wet-regime-authority`;
- qualified correction/frozen-step parent: `02b8e68bd80ad19b679923ce7015c0ab020c073c`;
- adaptive interaction branch at closeout: `4f3a0edf1989415365cf4269fba74856d6ad83f8`.

Historical repository authority:

- PR #161, **F-AR01: reconcile recovered legacy ZIP packages**;
- `docs/verification/F-AR01_LEGACY_ZIP_RECONCILIATION.md`;
- package `SWAP_4.3.1_ponding_jacobian_patch_for_Marius.zip`;
- package SHA-256 `e0403c4387742cc9a6819729d80b09ba3175579cedf3ae8ed47030cedc930d07`;
- historical core-patch SHA-256 `101cd0edd9e22f494582b5536cd82ccd849d2f881c20cda3cf224f2a63e4e1ee`.

The ZIP payload itself is not materialized in current repository authority. Therefore BOFEK00 does **not** claim byte-for-byte replay of the historical patch. It independently reproduces both historical mechanisms on current source and rederives the bounded correction.

## Hard classification

**B. DEFECT_CONFIRMED_CURRENT_REFERENCE**

Both historical mechanisms were present in the current SWAP5 Reference route at the preregistered canonical head.

### 1. Incomplete wet top-boundary Jacobian

For a dynamic head boundary, the top-face residual contribution contains

`-K_f * ((H_s-H_1)/d + 1)`.

With fixed time-level-t conductivity, the required pressure-head derivative is

`K_f/d * (1 - dH_s/dH_1)`.

Before the correction, `headcalc.f90` used only `K_f/d`, which assumes `dH_s/dH_1 = 0`. That is incomplete on the ponded analytical surface-store relations.

Preregistered independent central finite differences on the current preimage showed:

- ponded, no runoff: FD `9.0909090921798`, correct analytical `9.09090909090909`, current term `10.0`;
- active linear runoff: FD `9.16666667016841`, correct analytical `9.166666666666666`, current term `10.0`.

No timestep controller participated in this defect classification.

The corrected actual-Fortran gate, run 36403411980 / later equivalent correction runs, verified the provider derivative against central finite differences on both wet routes and compiled the provider, adapter and `headcalc` together.

### 2. Candidate/dt-dependent branch selection before analytical linear runoff

The preimage first computed runoff from the current Newton candidate ponding depth and compared its **depth** against an absolute `1e-6 cm` gate. Only after that gate did it enter the existing analytical `RSROEXP=1` linear-runoff solution.

Therefore branch selection depended on Newton scratch and, because runoff depth scales with `dt`, on timestep size.

The preregistered micro-reproduction held the physical branch condition fixed and changed only `dt`:

- `dt = 1e-6 d`: candidate runoff depth `1e-7 cm`, below gate;
- `dt = 1e-4 d`: candidate runoff depth `1e-5 cm`, above gate.

Both states admit the same bounded analytical linear-runoff formulation. The correction now selects that analytical route directly once the no-runoff analytical solution exceeds `PONDMAX`, for the bounded finite-resistance `RSROEXP=1` profile.

## Current code paths

Correction is deliberately small and limited to:

- `src/solver/mod_soil_water_solver_contract.f90`;
- `src/solver/mod_b110_dynamic_top_boundary_provider.f90`;
- `src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90`;
- `src/legacy/b1_10_port/headcalc.f90`.

The dynamic provider carries the analytical `dH_s/dH_1` explicitly. `headcalc` consumes it for the dynamic head regime. The qualified production-shaped path freezes top-node conductivity during the Newton solve, matching the current `SWKIMPL=0` Reference semantics.

No broad refactor was introduced.

## BOFEK00C/D direct correction qualification

Qualified correction run:

- run `36403411980`: success;
- later correction-candidate run `36403426179`: success.

Representative corrected actual-Fortran results:

- ponded-head FD derivative `3.1213735312007884`, analytical `3.1213735335818513`;
- ponded-head-linear-runoff FD derivative `3.1214905149568040`, analytical `3.1214905150282615`;
- active linear-runoff solution is independent of tested Newton candidate ponding seed.

This is classified **BUG/CORRECTNESS**.

## BOFEK00E frozen-timestep qualification

Run `36403774985`: success.

Both baseline and corrected Reference used the exact same sequence:

- 24 accepted steps;
- `dt = 0.005 d` for every step;
- same physics, forcing, tolerances and bottom flux;
- no adaptive controller.

Result over the full 0.12-day wet trajectory:

| Observable | Baseline | Corrected |
| --- | ---: | ---: |
| nonlinear iterations | 117 | 98 |
| backtracking attempts | 117 | 98 |
| cumulative runoff (cm) | 0.4493205111812004 | 0.4493205111812251 |
| final top pressure head (cm) | 0.5263806508783677 | 0.5263806508786227 |
| final ponding (cm) | 0.36553179889283893 | 0.36553179889284604 |
| max abs combined water-ledger residual (cm) | 3.33e-14 | 2.61e-14 |
| bottom flux / drainage fixture | 0 | 0 |

Differences at frozen timesteps are at roundoff scale:

- runoff delta `2.46e-14 cm`;
- final top-head delta `2.55e-13 cm`.

Therefore the correction improves nonlinear convergence without materially changing the frozen-step physical solution in this qualified wet case.

The fixture deliberately has no active drainage. Drainage/bottom transfer is identically zero; BOFEK00 does not claim a drainage-active wet-regime qualification.

## BOFEK00F unchanged adaptive-policy interaction

Preregistered before execution in:

`docs/verification/evidence/F-PE-BOFEK00_ADAPTIVE_PREREGISTRATION.json`

Qualified run:

- run `36404440496`: success;
- duplicate trigger run `36404507803`: success.

The test applies the existing TimeControl rules, with one explicit research-fixture policy held identical between baseline and corrected:

- initial `dt = 0.005 d`;
- `DTMIN = 0.000625 d`;
- `DTMAX = 0.02 d`;
- `NUMBIT_CRIT = 4`;
- `MAXIT = 20`;
- `FACT_DT_INCREASE = 1.5`;
- `FACT_DT_DECREASE = 0.5`;
- nonconvergence reduction factor `2.0`.

These values are **not** a BOFEK recommendation and are not admitted as defaults.

Results:

| Observable | Baseline | Corrected |
| --- | ---: | ---: |
| accepted steps | 17 | 9 |
| rejected attempts | 0 | 0 |
| growth events | 1 | 3 |
| reductions | 0 | 0 |
| nonlinear iterations | 84 | 42 |
| backtracking attempts | 84 | 42 |
| cumulative runoff (cm) | 0.45703288642947293 | 0.4791258341796943 |
| final top pressure head (cm) | 0.42436977808414333 | 0.6130563943604358 |
| final ponding (cm) | 0.36563834533628425 | 0.36597611552174547 |
| max abs combined water-ledger residual (cm) | 2.61e-14 | 2.61e-14 |

Accepted dt sequences:

- baseline: `[0.005, 0.0075, 0.0075, ..., 0.0075, 0.0025]` (17 steps);
- corrected: `[0.005, 0.0075, 0.01125, 0.016875, 0.016875, 0.016875, 0.016875, 0.016875, 0.011875]` (9 steps).

The corrected solver satisfies the unchanged growth criterion more often, so the controller legitimately selects larger timesteps. This changes the integrated numerical trajectory and cumulative runoff by `+0.02209294775022136 cm` over 0.12 day.

That runoff difference is classified **NUMERICAL_POLICY_INTERACTION**, not a frozen-step correctness difference.

The CI process-wall observation was approximately 1.327 ms median baseline versus 1.096 ms corrected over nine samples. It is explicitly **NON_BENCHMARK** and is not used for performance admission.

## Correctness versus policy

### BUG/CORRECTNESS, admission candidate

- complete analytical dynamic top-boundary Jacobian for the qualified fixed-conductivity wet route;
- remove Newton-candidate/absolute-runoff-depth gating before the bounded analytical linear-runoff solution.

### NUMERICAL_POLICY, unchanged

BOFEK00 changes none of:

- `DTMIN`;
- `DTMAX`;
- `NUMBIT_CRIT`;
- `FACT_DT_INCREASE`;
- `FACT_DT_DECREASE`;
- retry factor;
- convergence tolerances;
- temporal acceptance thresholds.

The adaptive experiment only demonstrates how unchanged policy reacts to the corrected solver.

### PERFORMANCE, not admitted here

Reduced nonlinear iterations and the small CI wall-time observation are useful consequences, but BOFEK00 is not a performance admission.

### MODEL/PROCESS_CHOICE, unchanged

No hydrological process formulation, runoff exponent choice, drainage formulation, retention model or boundary ownership choice is changed.

## Historical correction status

The historical mathematical findings remain valid on current authority.

What is **not** claimed:

- byte-identical recovery of the historical ZIP patch;
- admission of its research-only timestep experiments;
- equivalence for unqualified nonlinear runoff exponents or instantaneous-runoff profiles;
- active-drainage wet-regime qualification.

## Admission status

`QUALIFIED_ADMISSION_CANDIDATE`

Recommended admission surface is the bounded current SWAP5 Reference correction plus its preregistration and qualification gates. The correction should be admitted separately from any future timestep-policy work.

## Consequence for F-PE-BOFEK01/02

The wet-regime prerequisite is satisfied for starting BOFEK timestep/convergence research **after this correctness candidate is admitted or used explicitly as the research base**.

BOFEK01/02 must not use pre-correction small wet timesteps as evidence of intrinsic soil-profile difficulty.

Permitted next BOFEK work after admission/base freeze:

- soil-dependent `DTMIN/DTMAX` characterization;
- `NUMBIT_CRIT` and growth/decrease-factor research;
- convergence-criterion sensitivity;
- wet-regime runtime-eater classification.

Those remain separate numerical-policy/performance decision surfaces.
