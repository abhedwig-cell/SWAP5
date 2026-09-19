# TRACE-ELEM-SWAP-B01-002 reconciliation

Date closed: 2026-09-19
Prospective result: `NO_CONFIRMED_DISCREPANCY`
Candidate IDs: none

## Element

Hydrological boundary-condition semantics, selected before detailed inspection as the boundary-relation stratum of Exposure Batch 01.

## Scope authority

The selected reviewer page is intentionally Status-A scoped. F-DOC21 freezes its scientific denominator to:

- Status-A authority `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`;
- scientific production tree `3b085d7dea3d3f3fce42ad9d8f259a8350205846`.

Later post-Status-A groundwater or solver development therefore cannot be used to manufacture a discrepancy against this page unless the page itself claims moving-current semantics.

The live-canonical delta after the preceding TRACE closeout touched only publication-governance/release files and did not overlap the selected boundary or groundwater authority surface.

## Upper-boundary reconciliation

At the frozen production baseline:

- `src/solver/mod_soil_water_solver_contract.f90` blob `276941d76ba951a89c43899e61fd0532418d8230` exposes explicit top/bottom flux and head fields.
- `src/solver/mod_b110_dynamic_top_boundary_provider.f90` blob `3eadae0f32aba49534cd58464e28c0af5bc9bf7d` implements the documented net surface supply expression and the four documented successful route labels:
  - `atmospheric-head`;
  - `surface-flux`;
  - `ponded-head`;
  - `ponded-head-linear-runoff`.

The documentation correctly treats forcing/surface bookkeeping signs as local semantics rather than inventing one universal raw-code sign convention.

## Lower-boundary and groundwater reconciliation

F-DOC24 pins the admitted Groundwater Coupling v1 implementation to the same frozen production baseline and gives immutable source identities.

Direct frozen-source inspection confirms:

- `src/runtime/mod_groundwater_coupling_contract.f90` blob `fc598d14eabafcb025bb55621f7b00d6d1816f10`:
  - `H = z_bottom + psi_cm*0.01`;
  - inverse pressure-head conversion;
  - `q_swap = -qbot*0.01/86400`;
  - `q_groundwater = -q_swap`;
  - head residual `h_swap-h_groundwater`;
  - flux residual `q_swap+q_groundwater`.
- `src/runtime/mod_groundwater_predictor_corrector_window.f90` blob `fa2a5a45d558fbaaea242438915cdb7420b6503c`:
  - one predictor and one corrector from the accepted origin;
  - predictor discard before corrector authority;
  - whole-window exchange converted through `qbot_mean=-exchange/duration`;
  - prepublication checks before accepted publication;
  - hard zero committed interface-ledger residual;
  - final successful route `restricted-pc1-committed`.
- `src/runtime/mod_groundwater_coupling_policy.f90` blob `5e6fa9db6ddf60d3fc70ed4cec9a33858b0f9976`:
  - head-convergence tolerance must be available, finite, positive and provenance-qualified;
  - it explicitly does not own application accuracy, Richards temporal budget, nonlinear tolerances or mass tolerance.
- `src/runtime/mod_groundwater_interface_mass_ledger.f90` blob `a867e04b088f61f686f693d07e470c3e9c33bdec`:
  - distinct trial, prepared and committed states;
  - abort leaves committed exchange unchanged;
  - restart contains committed continuation only.

F-GC28/F-VQ98/F-CI88 close the bounded Groundwater Coupling v1 denominator and explicitly exclude broad MODFLOW admission, new groundwater physics and new numerical tolerances.

## TRACE disposition

No current scientific, documentation, implementation or qualification conflict was identified inside the selected frozen scope.

No candidate was registered.

This is a denominator null observation. It does not claim that every historical SWAP upper/lower boundary mode is covered, and it does not convert Groundwater Coupling v1 into a broad backend admission.
