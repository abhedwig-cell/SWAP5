# TOP03 nonlinear boundary/geometry diagnosis

Date: 2026-10-01
Status: RESEARCH_PREREGISTERED
Pinned branch: 65c82b41b08f64b62e8ea53246c9425ae112d6bb
Canonical inspected: 44c6df02a58edee79f88dde8ca8aadbec26337fc

The new canonical delta admits SWBOTB=4 q(gwl), not a new imposed-top temporal or nonlinear policy. No canonical reconciliation is attempted in this research slice. Production code stays unchanged.

Factorial diagnostic experiment: retain the same constitutive set and constant imposed 0.02 cm head; compare original four-node geometry, the same shallow geometry with distances consistent with cell centers, and a synthetic 40-node 100 cm column (uniform 2.5 cm cells). Bottom modes 7 free drainage, 2 prescribed flux equal to initial conductivity drainage, and 5 fixed bottom-face pressure equal to the initial uniform pressure. These are different physical problems, not equivalent simulations. Their completion/failure pattern is diagnostic only. Record actual accepted qbot, not the requested flux for mode 7/5.

Initial heads -123 cm, -10 cm and +0.02 cm. Pond begins at 0.02 cm throughout, to exclude the already-understood instantaneous local pond filling receipt. The +0.02 cm case is an exact saturated steady-flow control with qtop=qbot=-Ks for all three lower-boundary contracts. Its analytical control is separate from transient accuracy.

Same 0.25 day and 0.001953125 day horizons; 1..512 equal subdivisions, same initial state per grid, O0/O2. Fixed nonlinear limit 80 and backtracking 16; tolerances and hard mass oracles unchanged. No solver retries are silently accepted. Record nonlinear retry and positive qtop bounded-profile exit distinctly. For complete adjacent grids only, measure whole-column depth-weighted theta difference and pressure infinity difference; partial integrations do not enter the refinement oracle. Record terminal pressure updates, residual and capacities on retry.

Changing distances/depth/lower boundary is an explicit diagnostic perturbation. It must not be claimed as repairing the original problem. Diagnose fixture influence versus shared nonlinear behavior before proposing code changes. The deeper column remains synthetic; no field/live Ribasim admission or broad soil qualification is implied.
