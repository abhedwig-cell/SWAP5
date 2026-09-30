# F-PE-ELASTIC67 negative-forcing N4 postmortem

Date: 2026-09-30
Status: PREREGISTERED_OBSERVATION_ONLY

Parent: F-PE-ELASTIC66.

Scope: exactly six profile-8016 cases at h0=-20 cm, delta -0.05/-0.035 cm/day, all three ELAS regimes, accepted interval dt 0.0009765625 day. Diagnose the first failed N=4 Reference substep at dt 0.000244140625 day. Preserve N=2 success as control.

Record solver status, nonlinear/backtracking/Jacobian/linear work, internal retries, max compartment residual and node, total residual sum, L2 residual, head range and saturated-node count.

No change to physics, solver tolerances, temporal budget, alpha, controller or mass acceptance. Zero src changes.

Hypothesis: if max compartment residual is within 1e-12 while total residual remains above 1e-12, the same solver-local total-balance gate seen in the positive-forcing profile-8016 cases is the leading limiter. Causal tolerance changes require a separate preregistered sensitivity.
