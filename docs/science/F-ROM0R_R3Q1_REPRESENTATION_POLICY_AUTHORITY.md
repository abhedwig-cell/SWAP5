# ROM-0R R3Q1 prescribed-head representation policy authority

R3Q1 is a new prospective qualification, not a repair or reclassification of R3.

The candidate changes only the **total-column convergence criterion** used by the research Reference solve. Its bound is computed before each solve from the already accepted base state using the independently established PUB-P2E21 representation formula:

`max(1.6e-15, 0.5 * sum((spacing(theta_s) + spacing(theta_base)) * dz)) / dt`.

The local compartment-balance criterion, head criteria, ponding criterion, nonlinear iteration cap, backtracking cap, timestep, boundary amplitudes and physics remain exactly those of R3.

Every candidate step is paired with the original R3 control from the same base state. Where the control converges, the candidate endpoint must remain inside all frozen Se=0.85 P2E21/P2E18 numerical-reference budgets. Where the control retries, the only admissible rescue is a total-balance-only retry whose integrated residual is already below the pre-solve representation bound. Any local-balance, head, mixed or other retry blocks qualification.

The candidate trajectory must independently satisfy the hard typed integrated-mass limit of 1e-12 cm and the original directional reachability criteria for both B01 and B14.

A PASS qualifies a research numerical policy for a later Reference-floor trajectory workunit. It does not mutate production Reference behavior, does not revise the original R3 result, and does not authorize ROM-1A by itself.
