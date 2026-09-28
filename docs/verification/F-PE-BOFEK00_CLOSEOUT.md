# F-PE-BOFEK00 — wet-regime numerical authority closeout

Date: 2026-09-28

## Authority

Canonical preimage: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`.

Historical authority recovered from:

- PR #161;
- `docs/verification/F-AR01_LEGACY_ZIP_RECONCILIATION.md`;
- package `SWAP_4.3.1_ponding_jacobian_patch_for_Marius.zip`, SHA-256 `e0403c4387742cc9a6819729d80b09ba3175579cedf3ae8ed47030cedc930d07`;
- historical core-patch SHA-256 `101cd0edd9e22f494582b5536cd82ccd849d2f881c20cda3cf224f2a63e4e1ee`.

The package payload itself is not materialized in current repository authority, so no byte-for-byte replay of that historical patch is claimed.

## Hard classification

**B. DEFECT_CONFIRMED_CURRENT_REFERENCE**

Both historical mechanisms are present on the current Reference/canonical route.

### BUG/CORRECTNESS 1 — incomplete top-boundary Jacobian

Current `src/legacy/b1_10_port/headcalc.f90` used the first-row head-boundary term

`Kf / d`

without the contribution from the pressure-head dependence of the analytically solved surface head.

For the bounded explicit-conductivity dynamic-top route the correct term is

`Kf / d * (1 - dHs/dh1)`.

The preregistered central finite-difference gate reproduced the mismatch independently on:

- ponded/no-runoff;
- active linear runoff.

The correction candidate carries `dHs/dh1` through the typed dynamic-top result and subtracts the missing term only when that derivative is explicitly available.

### BUG/CORRECTNESS 2 — candidate/dt-dependent branch selection

Current `src/solver/mod_b110_dynamic_top_boundary_provider.f90` first solved the no-runoff surface reservoir to obtain `h0max`, but after `h0max > ponding_max` it used runoff computed from incoming Newton-candidate ponding plus an absolute `1e-6 cm` runoff gate to decide whether to enter the already available analytical linear-runoff solution.

That makes branch selection depend on Newton scratch and on dt before solving the linear-runoff relation.

The correction candidate selects the bounded `RSROEXP=1`, finite-resistance analytical runoff branch from the physical `h0max > ponding_max` condition instead. Nonlinear/instantaneous runoff profiles remain outside this bounded correction.

## Correction candidate

Production delta is deliberately small:

- `src/solver/mod_soil_water_solver_contract.f90`: typed optional surface-head derivative;
- `src/solver/mod_b110_dynamic_top_boundary_provider.f90`: analytic derivative plus candidate-independent bounded linear-runoff selection;
- `src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90`: derivative forwarding;
- `src/legacy/b1_10_port/headcalc.f90`: complete first-row derivative when available.

No DTMIN, DTMAX, convergence tolerance, retry factor, temporal tolerance or timestep-growth/decrease policy is changed.

Direct corrected wet-boundary qualification passed at O0/O2. For the D21-shaped wet case:

- ponded/no-runoff FD derivative: `3.1213735312007884`;
- analytic derivative: `3.1213735335818513`;
- active-runoff FD derivative: `3.1214905149568040`;
- analytic derivative: `3.1214905150282615`;
- zero and large Newton ponding seeds select the same analytical linear-runoff solution.

## BOFEK00E — frozen timestep

Old and corrected were run through the real Reference solver for 24 identical 10 s steps.

Result:

- old cumulative runoff: `0.16438021581036055 cm`;
- corrected cumulative runoff: `0.16438021581036075 cm`;
- old Newton iterations: 96;
- corrected Newton iterations: 96;
- old backtracks: 96;
- corrected backtracks: 96;
- internal retries: 0 in both;
- maximum pressure-head difference: `4.68292071786891e-13 cm`;
- maximum ponding difference: `2.914335439641036e-16 cm`;
- maximum per-step runoff difference: `4.85722573273506e-17 cm`;
- independent water-ledger residual: about `3e-14 cm` in both.

Therefore the bounded correction is physically identical to the current solver within roundoff when the timestep sequence is frozen.

The direct-solver compatibility field `unrounded_mass_balance_residual` is not populated on this route. The independent water ledger is therefore the qualification authority for this test.

## BOFEK00F — existing adaptive policy

Adaptive interaction was preregistered separately after BOFEK00E.

Frozen policy:

- `TX_TEMPORAL_EXTERNAL_FULL_HALF`;
- temporal tolerance `1e-6`;
- mass tolerance `1e-10`;
- retry scale `0.5`;
- max retries 8;
- max committed substeps 256.

Frozen qualification ladder:

- 10 s;
- 20 s;
- 40 s;
- 80 s;
- 160 s;
- 320 s.

All twelve old/corrected runs failed before accepting a substep. Every ladder point therefore classified `BOTH_FAIL`.

This is not evidence against the wet-boundary correction.

Current authority in `fmr_serialized_temporal_identity` returns temporal error 0 only when the full-step and two-half-step physical states are exactly equal, and `huge()` otherwise. On this route the nominal `1e-6` temporal tolerance is therefore not a graded state-error criterion. Nontrivial Richards evolution can be rejected independently of the wet-boundary correctness patch.

That is a separate **NUMERICAL_POLICY** blocker.

Because no adaptive step was accepted:

- no accepted dt distribution exists to report;
- adaptive accepted runoff and accepted water balance are unavailable;
- runtime numbers from failed attempts are diagnostic only and are not a performance claim.

The ladder still shows that changing the Jacobian alone does not make this current policy usable. Correctness and timestep policy remain separate decision surfaces.

## Governance result

### Correctness

Status: **QUALIFIED_CORRECTION_CANDIDATE**

The current Reference contains both historical defects, and the bounded correction candidate passes independent derivative, branch-independence and frozen-timestep qualification.

### Adaptive policy

Status: **BLOCKED_BY_INDEPENDENT_NUMERICAL_POLICY**

The current full/half temporal acceptance surface cannot provide the requested adaptive comparison for this wet dynamic-top route.

Do not repair that policy inside the Jacobian/top-boundary patch.

### Admission

Status: **NOT_YET_ADMISSION_READY**

Reason is not unresolved correctness. The blocker is the required BOFEK00F adaptive interaction gate under an admitted usable timestep-policy surface.

A later admission work unit may use an already admitted compatible temporal policy if that policy is explicitly composed with this dynamic-top state, or may first qualify a separate policy correction. It must not bundle policy changes into the wet-boundary correctness patch.

## Consequence for BOFEK performance work

`F-PE-BOFEK01/02` timestep/convergence optimization remains gated.

In particular, small wet-regime timesteps must not yet be classified as intrinsic BOFEK soil difficulty because:

1. the historical top-boundary/Jacobian defects are confirmed in current Reference;
2. a bounded correctness correction is qualified;
3. the currently exercised full/half application policy is independently unusable for this nontrivial wet route.

Work independent of timestep/convergence policy may proceed separately. Soil-dependent DTMIN/DTMAX, convergence-criterion and timestep-growth/decrease tuning should wait until the adaptive policy blocker has its own authority.

## Durable evidence

- `docs/verification/F-PE-BOFEK00_PREREGISTRATION.md`
- `docs/verification/evidence/F-PE-BOFEK00_CURRENT_AUTHORITY_REPRODUCTION.json`
- `docs/verification/evidence/F-PE-BOFEK00_FROZEN_TIMESTEP_RESULT.json`
- `docs/verification/F-PE-BOFEK00F_ADAPTIVE_PREREGISTRATION.md`
- `docs/verification/evidence/F-PE-BOFEK00_ADAPTIVE_RESULT.json`
- workflow run `36402438433`: current-authority defect reproduction PASS;
- workflow run `36403426179`: corrected wet-boundary qualification PASS;
- workflow run `36404281013`: frozen-timestep qualification PASS;
- workflow run `36405729839`: preregistered adaptive ladder execution PASS, scientific outcome `BOTH_FAIL` at all six durations.
