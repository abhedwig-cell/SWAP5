# ROM-0R R3R1 — representation-bounded total policy qualification

This workunit does not revise the original R3 verdict. R3 remains a no-go under its frozen fixed total-balance rate tolerance.

R3R1 qualifies a separate research Reference-floor numerical policy on the exact R3 physical domain. The candidate total-balance convergence tolerance is prospective and state-derived:

`tol_total_rate = max(1e-12, 0.5 * sum((spacing(theta_s)+spacing(theta_base))*dz) / dt)`.

The failed residual is not an input. There is no fitted multiplier.

The strongest gate is endpoint neutrality. Original and candidate trajectories start from the same seed. For every perturbation interval accepted by the original control, the candidate must also accept and commit a bit-identical physical endpoint. Thus the candidate is not allowed to perturb already admitted R3 trajectory segments.

Only where the original policy genuinely fails may the candidate create additional accepted Reference-floor states. Those states still have to satisfy the independent hard transaction mass gate, one-advance/no-retry semantics, deterministic O0/O2 execution, and the original R3 directional reachability criteria.

A positive result authorizes this policy only for the ROM research Reference-floor prescribed-head R3 domain and permits the planned vertical-resolution diagnostic. It is not production application admission and it does not authorize ROM-1A by itself.
