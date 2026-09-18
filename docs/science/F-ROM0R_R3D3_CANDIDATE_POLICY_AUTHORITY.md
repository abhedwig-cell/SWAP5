# ROM-0R R3D3 candidate-policy authority

R3D3 does not modify the original R3 result. R3 remains a valid no-go under its frozen fixed total-balance rate criterion.

R3D1 showed that both B01 failures are total-balance-only: all local compartment-balance and head-convergence criteria are already satisfied. R3D2 then showed that the time-integrated residuals at those exact failures are only about 9.6% and 14.2% of the prospective floating-point representation bound established independently by PUB-P2E21.

R3D3 may therefore evaluate one new research-only Reference policy on the exact R3 matrix.

For each requested fixed step, before the solve:

`B_rep = 0.5 * sum((spacing(theta_s) + spacing(theta_base_i)) * dz_i)`

and only the total-column convergence criterion becomes:

`CritDevBalTot = max(1e-12, B_rep / dt)`.

Everything else remains R3-frozen, including the 1e-12 cm/day local compartment criterion, head criteria, 16 Newton iterations, 8 backtracking attempts, dt, forcing and the independent 1e-12 cm transaction mass gate.

This is intentionally narrower than importing the complete PUB-P2E21 policy. In particular, the compartment criterion is not changed.

The strongest guard is overlap neutrality. Wherever the original R3 control already produces an accepted step, the candidate policy must produce the exact same endpoint and solver-work record bit for bit. A candidate policy that changes an already valid endpoint is rejected even if it later completes B01.

Only states beyond a proven original total-only failure may lack a baseline counterpart.

A pass qualifies a ROM research Reference policy for this frozen domain. It is not a production Reference tolerance change and does not by itself authorize ROM-1A.
