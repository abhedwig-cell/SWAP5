# F-SI36 — Accepted Trajectory Bottom-Interface Sensitivity Capability

## Decision

`NEGATIVE_ACCEPTED_TRAJECTORY_SENSITIVITY_PRIMITIVE_BLOCKED_BY_MISSING_ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE_SEAM`

F-SI36 does **not** implement a new production sensitivity. The current canonical Full Richards solver exposes enough information to prove that the existing scalar `dh_bottom_dq_bottom` is insufficient for accepted-trajectory propagation, but it does not expose a mathematically complete accepted-step directional derivative operator from which a later F-KT workunit can safely compose a whole interval/window derivative.

This is a fail-closed scientific/software qualification. No Full Richards physics, solver trajectory, state, mass result, groundwater orchestration, transaction semantics, persistent state or denominator is changed.

## Exact start authority

- repository: `abhedwig-cell/SWAP5`
- branch: `work/f-si36-accepted-trajectory-interface-sensitivity`
- current canonical at start: `integration/f-ci-canonical@379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`
- canonical tree: `556221f62b4fde616981499eba68ef5460f5d83c`

Governing authorities reconstructed:

- F-SI28: `work/f-si28-interface-sensitivity-production-solve@5b514e678d0d794e5837f161033b0bac58385707`
- F-SI32: `work/f-si32-scoped-interface-sensitivity-reconciliation@dfe1a285ae485e1e8348ee10492bb7808f85dd39`
- F-SI33: `work/f-si33-full-richards-reference-solver-v1-completion-audit@8a162a7b4aa7a67778ed9be454cfcd67d01276ce`
- F-SI34: `work/f-si34-solver-interface-headcalc-isolation-v1-completion-audit@b522fe150610f900f253eeea9bf78329107de362`
- F-SI35: `work/f-si35-mandatory-production-soil-water-solver-seam-closure@15ccbf4b6bcf6895b824a68c221762bef0bc08b9`
- F-GC23 negative dependency authority: `work/f-gc23-whole-window-groundwater-response-tangent-composition@cf83a9a2c9399882b42bf5f5206b509e4167858a`

## Exact canonical source evidence

| Source | Blob | Relevant fact |
|---|---|---|
| `src/solver/mod_soil_water_solver_contract.f90` | `276941d76ba951a89c43899e61fd0532418d8230` | request/result has only optional scalar local interface sensitivity; provider ABIs expose values, not directional derivatives |
| `src/solver/mod_reference_richards_workspace.f90` | `74f99556005ae39614f9df678467b1e19097bae2` | worker-owned Jacobian/factorization scratch exists; expanded TRIDAG capture is temporary |
| `src/solver/mod_reference_richards_state_binding.f90` | `a2488ce3a6a6eff665a59d3dd68907d26f8304ec` | base pressure head/water content become both current initial state and `hm1/thetm1`; previous accepted state is explicit in the discrete step |
| `src/adapter/mod_reference_richards_legacy_binding.f90` | `03a64b6d09fd804242bcf76f7cb5277f59a6230a` | same-factorization backsolve is implemented only for prescribed-qbot local terminal sensitivity; mode-5 qbot is materialized from the accepted water balance |
| `src/adapter/mod_b110_production_soil_water_task2.f90` | `3090e1d3d5701a87b3624412ad88590e17369d63` | production request asks for current sensitivity only on admitted SWBOTB=2 smooth surface-flux route; mode 5 is a distinct prescribed-head path |
| `src/legacy/b1_10_port/headcalc.f90` | `3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55` | actual discrete residual/Jacobian; `swkimpl=0` freezes conductivity from the step base state; storage uses `thetm1`; bottom modes 2 and 5 have different algebra |
| `src/legacy/b1_10_port/soilwater.f90` | `c1850ea7fa82a1ed8974af57e1da95aa11a771be` | accepted-step/retry path materializes prior state and dispatches every Full Richards Task2 call through the solver service |
| `src/solver/mod_b110_dynamic_top_boundary_provider.f90` | `3eadae0f32aba49534cd58464e28c0af5bc9bf7d` | even `surface-flux` selection is coupled to evaporation capacity/current top head and previous ponding; provider has branches but no derivative contract |
| `src/solver/mod_reference_linear_solver.f90` | `5b6ecd2341b315967bcfac6b879c3afe227fb245` | bounded tridiagonal backsolve capability exists and is suitable once a justified tangent RHS exists |

## Scientific definition audited

Let one accepted discrete soil-water step be

`R_k(x_{k+1}, x_k, p_k) = 0`.

A later trajectory composition requires an incoming accepted-state directional sensitivity `s_k = dx_k/dp_window` and must produce `s_{k+1}` without advancing it on rejected trials. For a smooth fixed discrete route,

`J_k s_{k+1} = -(B_k s_k + r_{p,k})`,

where

- `J_k = dR_k/dx_{k+1}`;
- `B_k = dR_k/dx_k`;
- `r_{p,k} = dR_k/dp_k * dp_k/dp_window`.

This recurrence is mathematically valid for a fixed smooth accepted discrete route. **The current implementation does not expose a complete, qualified construction of `B_k s_k + r_{p,k}`.** Therefore the recurrence passes as mathematics but fails as a current production capability.

### Why the previous-state term is not just storage

For the canonical admitted explicit route `swkimpl=0`, `HeadCalc` rebuilds conductivities from the step base state before Newton iteration and then keeps those conductivities fixed during the solve. The residual therefore depends on the previous accepted state through at least:

1. `thetm1` in the storage term;
2. the time-level-`t_k` nodal and face conductivities used in the flux terms;
3. previous ponding entering the dynamic surface boundary;
4. any other provider result that depends on the base state in a qualified route.

Consequently, using only `-C_k dz/dt * s_k` for `B_k s_k` would be incomplete for the actual canonical discretization.

### Surface route blocker

The dynamic top provider ABI only returns the physical boundary result. It does not return a directional derivative. The canonical B1.10 provider computes evaporation capacity from current top pressure head/conductivity and then uses that result in branch-dependent surface physics. Even a result labelled `surface-flux` cannot be assumed universally independent of the hydraulic state. Route changes are nonsmooth by definition.

F-SI36 therefore may not invent a zero top derivative, differentiate through branch switches, or reach into provider internals from transaction/runtime code.

## Boundary-coordinate audit

### Existing mode 2 primitive

For prescribed `qbot` (`SWBOTB=2`) the implemented residual contains `-qbot`. The existing same-factorization primitive solves the accepted terminal linear system with `+e_N` and publishes `dh_bottom_dq_bottom`. F-SI28/F-SI32 qualify this only as `LOCAL_TERMINAL`.

It is **not** an accepted-trajectory derivative because it omits propagation through `x_k` and therefore omits `B_k s_k`.

### Direct-groundwater mode 5

The restricted direct-groundwater path uses prescribed bottom head (`SWBOTB=5`). There the bottom head enters the Darcy bottom-face gradient, while accepted `qbot` is subsequently materialized with the exact B1.10 water-balance arithmetic. A useful mode-5 trajectory derivative must therefore differentiate the accepted mode-5 state transition and the accepted bottom-exchange publication consistently.

A mode-2 `q -> h` scalar cannot simply be inverted or relabelled as the mode-5 `h -> Q` whole-window response. Doing so would silently change boundary physics and violate F-GC16/F-GC23.

## Same-factorization / bounded-cost assessment

**Partial feasibility only.** The canonical workspace and linear solver prove that one extra O(N) backsolve per accepted smooth step is architecturally feasible. The missing item is not linear-solver cost; it is the scientifically complete tangent RHS and output functional.

Target after the missing seam is qualified:

- extra full nonlinear trajectories: `0`;
- extra Jacobian builds: preferably `0` on the same accepted route;
- extra factorization work: `0` where accepted TRIDAG capture is valid;
- extra backsolves: approximately `1 per accepted step` per scalar control direction;
- scratch: O(N) per active worker/job;
- persistent per-column sensitivity state: `0`.

F-SI36 does not claim these targets are achieved yet.

## Retry / rollback semantics

The required semantics are clear and remain fail-closed:

- sensitivity scratch starts from the same committed physical origin;
- a rejected/retried step does not advance incoming accepted trajectory sensitivity;
- only an accepted physical step may replace `s_k` with `s_{k+1}`;
- retry must restore or recompute worker-owned sensitivity scratch consistently with the physical checkpoint;
- unavailable sensitivity never invalidates a physically valid Full Richards solve;
- no sensitivity datum enters the physical mass ledger or acceptance test.

No implementation was added in F-SI36, so existing retry/rollback behavior is unchanged.

## Stop-condition evaluation

The F-SI36 stop condition is met:

> the existing Richards discretization does not expose enough mathematically justified derivative information for bounded forward propagation.

Specifically, the accepted Jacobian/factorization is available, but the complete accepted-step directional derivative seam for previous-state/provider dependence and the mode-specific output functional is not.

Implementing trajectory propagation now would require one or more unqualified assumptions about `B_k`, dynamic-top derivatives, or mode-2/mode-5 equivalence. Those assumptions are prohibited.

## Qualification outcome

- exact derivative definition: **DEFINED, but mode-specific production primitive not available**
- mathematical recurrence: **PASS mathematically / FAIL as currently constructible operator**
- same-factorization bounded-cost feasibility: **PARTIAL — linear solve feasible; RHS/output derivative missing**
- production implementation performed: **NO**
- physical result unchanged: **PASS by no production-source change**
- mass result unchanged: **PASS by no production-source change**
- retry/rollback sensitivity semantics: **PASS as required contract; NOT IMPLEMENTED**
- alternative-solver fail-closed behavior: **PASS unchanged**
- whole-window FD oracle qualification: **NOT RUN because no candidate primitive exists**
- persistent state added: **NO**
- production nonlinear reruns required by F-SI36: **0**
- whole-window/groundwater sensitivity claimed: **NO**

## Minimal next dependency

Use the separately persisted F-SI37 prompt. F-SI37 must first qualify an optional accepted-step directional-derivative seam — including previous-state dependence and smooth provider derivatives — behind the solver boundary. Only after that succeeds should an F-KT owner compose accepted sensitivities over `[t0,t1]`; only after F-KT succeeds should F-GC23 be retried.

## Nonclaims

F-SI36 does not claim:

- a whole-window derivative;
- a groundwater coupling tangent;
- mode-2/mode-5 equivalence;
- a derivative through adaptive timestep decision boundaries;
- a derivative through top-boundary regime switches;
- production admission of any new sensitivity;
- any change to the F-RG03 denominator or groundwater completion percentage.
