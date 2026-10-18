# Kalmthout analytic top-boundary derivative probe 2026-10-18

Independent local Python probe: /mnt/data/kalm431/top_boundary_derivative_check.py. Not a production solver or qualified cross-model test.

Read experimental SWAP5 research branch src/solver/mod_b110_dynamic_top_boundary_provider.f90 and src/legacy/b1_10_port/headcalc.f90. The source's no-runoff ponded-head formula is h0max = (p1/(1+p1))*h0, where p1=(k1max/distance)*dt. Fixed-conductivity derivative dh0max/dh1=p1/(1+p1). The resulting top flux derivative is k1max/distance*(1-dh0max/dh1). Flux branch uses q1 independent of h1 at fixed previous ponding and forcing, so branch-local derivative of top flux is zero. The full Richards residual has additional storage/conductivity terms.

A Python source-equation reproduction (k1max=4.75 cm/d, top distance=0.5 cm, h1=1.000847627 cm, pondm1=0.000847627 cm, q0=-0.166700951 cm/d, fixed K) evaluated analytic and centered FD derivatives for dt 1/24, 1e-5, 1e-9 and 2.842e-14 d. All four probes stayed on the head branch and agreed to ~1e-10. This does NOT test production's full Jacobian or actual failing branch.

A second branch-threshold probe at h0=1e-6 showed that one-sided derivatives differ across the regime switch. Finite differences straddling the branch are not valid tests of either branch-local derivative. Actual near-zero switching must be tested with fixed branch and separate one-sided derivatives, plus the production residual and accepted full state. Strong Newton rejection correlation in the historical trace does not by itself prove wrong analytic Jacobian.

No modifications to solver or canonical. No new GitHub Actions.
