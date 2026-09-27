# F-PE-DIR01 repair target 06 — reuse accepted candidate capacity for outgoing water-content direction

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Current DIR01 postimage:
Repair01 + Repair03 + Repair05.

## Evidence

Post-Repair05 bottom-head rebaseline:

- Reference median: approximately `8.738 us/interval`;
- directional median: approximately `15.106 us/interval`;
- directional increment: approximately `+72.9%`.

The post-Repair05 gprof workload shows:

- `evaluate_b110_default_mvg_water_content_direction` is called approximately three times per application interval;
- it accounts for about 4.8% of profiled directional self-time;
- the raw tangent backsolve itself is much smaller.

This final constitutive pass evaluates the water-content derivative at the accepted candidate pressure head after the physical Richards solve has already completed.

## Exact hypothesis

For an accepted Reference Richards step, the solver workspace may already contain the exact final constitutive capacity

`C(h_candidate) = dtheta/dh`

for the accepted candidate state.

If, and only if, that workspace capacity is exactly the capacity corresponding to `solve_result%candidate_state%pressure_head`, then the outgoing water-content direction can be obtained as:

`dtheta_out = C(h_candidate) * dh_out`

without repeating the MvG water-content directional evaluation.

## Experiment boundary

No production change is allowed initially.

Build a test-local service variant that replaces only the final default-MvG call

`evaluate_b110_default_mvg_water_content_direction(...)`

with multiplication by the accepted workspace capacity.

The direct-retention path remains unchanged.

## Required evidence before admission

1. Prove that the reused workspace capacity corresponds to the accepted candidate state, not a stale Newton/Jacobian state.
2. Require bit-identical outgoing water-content direction against the existing route on the qualified production cases.
3. Require identical:
   - physical checksum;
   - accepted bottom-exchange derivative;
   - outgoing pressure-head direction;
   - accepted-step count;
   - backsolve count;
   - nonlinear/Jacobian/linear diagnostics;
   - transaction and mass behavior.
4. Paired timing must show a stable gain beyond timing noise.
5. FKT22 accepted-trajectory compile/runtime preservation must remain green.

## Rejection rule

Reject Repair06 immediately if workspace capacity is not demonstrably the accepted candidate capacity for every qualified solve route.

Do not add a fresh constitutive evaluation merely to validate the reuse inside production; that would defeat the optimization.

Do not broaden Repair06 into solver-workspace semantic changes.

## Strategic rule

If Repair06 is rejected or its gain is only marginal, DIR01 should close unless the post-Repair05 evidence reveals another clearly larger exact hotspot. Small publication/copy optimizations alone are not sufficient reason to prolong the exact phase.
