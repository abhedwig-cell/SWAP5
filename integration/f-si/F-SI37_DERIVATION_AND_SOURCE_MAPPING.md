# F-SI37 — Accepted-step directional derivative derivation and source mapping

## Final owner-qualified decision

`QUALIFIED_ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE_PRIMITIVE_READY_FOR_TRANSACTION_TRAJECTORY_COMPOSITION`

The executable qualification authority is `992d524e3a4f5f7e21ddd9b6992c0e043f66c9fd` (tree `9eed7d750a6570d66c4a37171390ee6ca8407ecc`), GitHub Actions run `34794491732`, job `103824854786`, run number 24, conclusion `success`. Later commits on this branch only reconcile metadata/evidence and must not be relabelled as the executable-tested source head.

This is owner qualification only. It is not independent F-VQ qualification or F-CI canonical admission.

## Scope

This workunit derives and implements only one scalar directional derivative through one accepted Full Richards discrete step on one fixed smooth route. It does not compose accepted steps, does not define a whole-window derivative, and does not alter physical acceptance or mass accounting.

The governing recurrence is

`J_k s_{k+1} = -(B_k s_k + r_{p,k})`

where `J_k` is the accepted-step Jacobian already factorized by the Reference Full Richards solve, `s_k` is the incoming accepted-state direction and `r_{p,k}` is the direct derivative of the selected bottom control.

## Frozen physical/reference source mapping

The physical/reference implementation remains unchanged at the following audited blobs:

- `src/legacy/b1_10_port/headcalc.f90` = `3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55`;
- `src/solver/mod_reference_linear_solver.f90` = `5b6ecd2341b315967bcfac6b879c3afe227fb245`;
- `src/solver/mod_reference_richards_workspace.f90` = `74f99556005ae39614f9df678467b1e19097bae2`;
- `src/adapter/mod_reference_richards_legacy_binding.f90` = `03a64b6d09fd804242bcf76f7cb5277f59a6230a`;
- `src/solver/mod_b110_default_mvg_provider.f90` = `fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6`;
- `src/solver/mod_b110_source_sink_provider.f90` = `d6c57add72387e5c0022a44319fff08046194aac`;
- `src/solver/mod_fixed_flux_top_boundary_provider.f90` = `fb226f133bd48d8ab945f111c76897aeff49facf`;
- `src/solver/mod_b110_dynamic_top_boundary_provider.f90` = `3eadae0f32aba49534cd58464e28c0af5bc9bf7d`;
- `src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90` = `7a3cc3d01d994ea21bb0b48798cd2fb4aba9495e`;
- `src/process/mod_restricted_surface_evaporation.f90` = `a213af4deec2fe854d79120899827852a57237d1`.

F-SI37 owns the following directional seam sources at the executed qualification head:

- `src/solver/mod_soil_water_accepted_step_direction_contract.f90` = `52698b1ad2350bf787862a053a49c7c73c3358f0`;
- `src/solver/mod_b110_default_mvg_directional_provider.f90` = `b1e794d2f0e661a2abb14280a59175e1cf1d5724`;
- `src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90` = `0a957376b9a9fdea00ab6009f129803fb5341e4a`;
- `src/adapter/mod_reference_richards_accepted_step_directional_service.f90` = `ef395ac3fb0cf6f347031bf2081a74b74b5167ae`.

## Previous-state storage term

For node `i`, the HeadCalc residual contains

`(theta_{k+1,i} - theta_{k,i}) dz_i / dt`.

At fixed accepted `h_{k+1}` the derivative with respect to the incoming state contributes

`-dtheta_{k,i} dz_i / dt`.

F-SI37 therefore requires the incoming water-content direction explicitly. It does not reconstruct it from pressure head unless the caller chooses to do so upstream.

## Frozen `swkimpl=0` conductivity term

On the admitted explicit-conductivity route, node conductivities used during the step are rebuilt from the base state and frozen during Newton. They therefore contribute to `B_k s_k`.

F-SI37 differentiates the exact B1.10 Mualem/van-Genuchten value branches through the sibling `mod_b110_default_mvg_directional_provider`. Branch boundaries and nonsmooth constitutive switches return sensitivity unavailable.

The existing value-provider derivative field remains untouched; the directional sibling owns these semantics so no historical `dconductivity_dhead` meaning is silently changed.

## Hydraulic mean derivatives

For every currently admitted `swkmean=1..6`, F-SI37 differentiates the exact face-mean algebra used by the qualification oracle:

1. arithmetic mean;
2. thickness-weighted arithmetic mean;
3. geometric mean;
4. thickness-weighted geometric mean;
5. harmonic mean;
6. thickness-weighted harmonic mean.

Non-positive conductivity where a logarithmic/geometric/harmonic derivative is undefined fails sensitivity closed.

## Interior directional residual

For an interior node, the previous-state contribution is assembled as

`B_i s_k = -dtheta_i dz_i/dt - dKmean_i * grad_i + dKmean_{i+1} * grad_{i+1}`

using the accepted-state hydraulic gradients but the base-state conductivity directions. The tangent RHS is `-(B_k s_k + r_p)`.

## Top boundary

### Explicit fixed flux

`FSI_TOP_MODE_EXPLICIT_FLUX` with `fixed_flux_top_boundary_provider_t` has zero top-flux directional contribution. Accepted ponding is carried through unchanged on that route.

### Dynamic B1.10 top boundary

The production-relevant typed route uses `FSI_TOP_MODE_DYNAMIC_PROVIDER`. F-SI37 reuses the qualified value provider as the physical route authority and differentiates only the strict `surface-flux` branch when evaporation is locally head-independent.

On that admitted branch:

`q_top = q1 = -q0 - pond_previous/dt`

so

`d q_top = - d pond_previous / dt`.

The accepted surface ponding is identically zero, hence `d pond_out = 0`.

Sensitivity fails closed for:

- capacity-limited dry evaporation where `dq_top/dh_top` would alter the accepted top Jacobian;
- the dry/ponded classification boundary;
- evaporation zero/demand/capacity switch boundaries;
- atmospheric-head selection;
- ponded-head selection;
- active runoff;
- surface-head regime boundaries.

A sensitivity-unavailable result never invalidates an otherwise valid physical solve.

### Switch-specific numerical guards

Qualification exposed that one shared floating-point guard scale across ponding depth, evaporation rates, fluxes and heads can couple unrelated units: a large demand or head can enlarge an unrelated ponding guard. F-SI37 therefore uses separate guards in the directional adapter:

- ponding classification guard: centimetre quantities only;
- evaporation switch guard: cm/day quantities only;
- atmospheric switch guard: cm/day quantities only;
- surface-head switch guard: centimetre quantities only.

These guards govern only whether the derivative is publishable. The unchanged B1.10 dynamic-top value provider remains the physical route authority. No physical route, physical acceptance criterion or mass criterion was changed by this remediation.

## Bottom mode 2 — prescribed native qbot

For `SWBOTB=2`, the selected control is the prescribed step-average native bottom flux. The direct residual contribution is the derivative of the `-qbot` term. The accepted bottom-flux output derivative is therefore exactly the caller's direct control derivative.

No inversion of the historical local terminal `dh_bottom/dq_bottom` is performed.

## Bottom mode 5 — prescribed bottom pressure head

For `SWBOTB=5`, the direct control is bottom-face pressure head. The lower boundary residual differentiates both the base-state lower-face conductivity and the direct boundary-head gradient term.

The accepted qbot publication is not taken from a local terminal tangent. It is differentiated from the exact mass-consistent publication algebra. For the fixed-flux top route:

`d qbot = d(storage)/dt`.

For the admitted dynamic surface-flux route:

`d qbot = d qtop + d(storage)/dt`.

This preserves the same discrete water-balance identity used by the accepted physical publication.

## Source/sink terms

The admitted `mod_b110_source_sink_provider` reads pressure head and water content only for shape validation. Its returned irrigation source and drainage sink are the bound arrays themselves. Within this frozen route their state derivative is therefore exactly zero. Active root extraction is excluded by that provider's admitted profile.

## Same-factorization construction and cost

The accepted physical solve captures the final Reference TRIDAG factorization in worker-owned scratch. F-SI37 assembles one directional RHS and calls `reference_tridag_backsolve` exactly once per available scalar direction.

The qualified production construction has:

- zero additional full nonlinear Richards trajectories;
- zero additional Jacobian builds;
- one additional O(N) tridiagonal backsolve per available scalar direction;
- no persistent per-column tangent state;
- no finite-difference production algorithm.

The executable `FSI37_BOUNDED_COST_GUARD=PASS` checks this construction.

## Executable qualification oracle

The runner is `tests/fsi/run_fsi37_qualification.sh` blob `d780795b628e56fd4ec419bedced23bc53ba9b87`.

Under both `-O0` and `-O2` it executes:

- `test_fsi37_accepted_step_directional_derivative.f90` blob `81c277c0ba1e3ca683a2d331461ac24fc34767bf`: 30 centered-FD cases across all six conductivity means, mode-2 positive/zero/negative control directions and two mode-5 bottom-head fixtures on a nonuniform evolving profile;
- `test_fsi37_dynamic_surface_flux_direction.f90` blob `005e40491abda4f694a27ef22ae73f1e064cd0a6`: 12 centered-FD dynamic surface-flux cases across mode 2 and mode 5 and all six conductivity means, plus capacity-limited sensitivity fail-closed qualification;
- `test_fsi37_dynamic_head_fail_closed.f90` blob `5925622b3293edf9e803bd7266b5094ebd18a212`: a physically valid atmospheric-head Full Richards solve with sensitivity unavailable, zero derivative publication and physical sensitivity-ON/OFF identity.

Run 24 proves all of the following final markers:

- `FSI37_FD_CASES=30` under O0 and O2;
- `FSI37_DYNAMIC_FD_CASES=12` under O0 and O2;
- `FSI37_DYNAMIC_CAPACITY_LIMITED_FAIL_CLOSED=PASS`;
- `FSI37_DYNAMIC_HEAD_PHYSICAL_VALID=PASS`;
- `FSI37_DYNAMIC_HEAD_SENSITIVITY_FAIL_CLOSED=PASS`;
- `FSI37_DYNAMIC_HEAD_ON_OFF_IDENTITY=PASS`;
- `FSI37_O0_O2_FULL_GATE=PASS`;
- `FSI37_BOUNDED_COST_GUARD=PASS`;
- `FSI37_QUALIFICATION PASS`.

## Transaction boundary and handoff

F-SI37 publishes no persistent trajectory sensitivity state. Rejected/retried steps have no accepted outgoing direction. F-KT21 must bind incoming sensitivity to the committed checkpoint origin, advance it only on the exact accepted candidate, roll it back on reject/retry, reject stale/cross-candidate derivative provenance, and separately qualify composition over generic `[t0,t1]` intervals.

Only after F-KT21 qualifies that accepted-trajectory composition may F-GC23 own and qualify a true groundwater whole-window response tangent. F-SI37 does not claim that semantic.
