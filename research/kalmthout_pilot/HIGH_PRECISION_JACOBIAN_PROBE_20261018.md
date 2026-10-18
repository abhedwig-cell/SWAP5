# Kalmthout branch-local high-precision Jacobian probe, 2026-10-18

Read `src/legacy/b1_10_port/headcalc.f90` (research state-export branch), particularly `vector_F(2)`, `jacobian_F()`, and backtracking.

Local numerical test in `/mnt/data/kalm431/branch_local_high_precision.py` independently reconstructed the documented fixed-K, no-runoff surface-flux and ponded-head equations with 65 decimal digits. Tested dt=1/24, 1e-5, 1e-9, and 2.842170943e-14 days, with one point safely in each regime per dt. All eight separate branch-local finite-difference gradients agree with analytic branch gradients at very high precision.

An initial double-precision finite-difference test lost accuracy at dt=1e-9 because a finite increment was subtracted from huge, nearly equal fluxes. This is numerical cancellation in the **diagnostic**; it is not evidence of an incorrect production Jacobian.

Source observation: `headcalc` constructs the Jacobian before backtracking, solves for `delta_head`, re-evaluates `vector_F(2)` at candidate head, and may reselect the top regime. Thus an exact source-integrated full-residual directional derivative gate still needs a captured committed full state and a branch-stable perturbation. None of these stand-alone equation tests are a proof of product Jacobian equivalence, nonlinear convergence, or SWAP4-SWAP5 comparison.

No modifications to production solver, no new CI run, canonical untouched.
