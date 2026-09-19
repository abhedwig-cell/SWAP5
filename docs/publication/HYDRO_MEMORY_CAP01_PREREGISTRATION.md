# HYDRO-MEMORY-CAP01 preregistration

## Purpose

CAP01 is the prerequisite between the HYDRO-MEMORY capability gate and the scientific Stage 0 experiment. It tests whether existing SWAP5 root-active Richards physics can participate in the groundwater response contract without changing model physics or numerical tolerances.

## Authority finding before execution

The current analytic accepted-trajectory tangent is deliberately not authoritative with root uptake active:

- `mod_modflow6_swap_predictor_tangent_adapter` marks `root_uptake_covered = .false.`;
- `mod_reference_richards_accepted_step_directional_service` rejects an associated `root_sink`;
- `mod_modflow6_swap_predictor_response` separately admits `MODFLOW6_DERIVATIVE_CENTERED_FD`.

CAP01 therefore preserves the analytic fail-closed boundary. It does **not** patch the directional derivative machinery merely to make HYDRO-MEMORY runnable.

The bounded alternative under test is a centered finite difference of the complete real root-active SWAP trajectory.

## Frozen Phase-A profile

- Reference Richards;
- `SWKIMPL=0`;
- `SWSOPHY=0`;
- fixed-flux top boundary;
- predictor with prescribed qbot;
- corrector with prescribed groundwater head (`bottom_mode=5`);
- nonzero, nonnegative precomputed root sink;
- root sink immutable within a coupling window;
- drainage response, macropores, snow, hydraulic hysteresis, tabulated hydraulics, elasticity, frost and soil temperature off.

No Feddes equation, Richards equation, retry policy, tolerance or solver implementation is changed.

## Phase-A hypotheses and gates

1. A real root-active production candidate must complete with hard water-balance residual <= (10^{-12}) cm.
2. Requesting the analytic accepted-trajectory direction must remain fail-closed for the root-active route.
3. A centered finite difference using qbot perturbations of (10^{-4}) cm d-1 must produce a finite, non-ill-conditioned endpoint derivative.
4. A typed MODFLOW6 predictor response must accept that centered-FD derivative even though `root_uptake_active=true` and `root_uptake_covered=false`.
5. Materializing multiple prescribed groundwater heads must preserve the precomputed root sink exactly.
6. Repeated same-origin corrector trials must not mutate committed SWAP state before publication.
7. For prescribed-head perturbations of (10^{-6}) m around the response reference head, the centered corrector flux slope must agree with the centered-FD predictor slope to within 5%.

The 5% bound is deliberately frozen before executing the test. Failure is evidence that this response route is not yet adequate for HYDRO-MEMORY; it is not grounds for loosening the criterion.

## Phase-A result states

- `CAP01_A_PASS_CENTERED_FD_ROUTE`
- `CAP01_BLOCKED_ROOT_ACTIVE_GROUNDWATER_RESPONSE`

A pass does not authorize the scientific Stage 0. Phase B must still establish live transient-MODFLOW drawdown/recharge, multi-window advancement and the research diagnostic surface.
