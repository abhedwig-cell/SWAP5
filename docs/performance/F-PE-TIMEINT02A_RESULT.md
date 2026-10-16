# F-PE-TIMEINT02A result — SWKIMPL=1 failure attribution

Date: 2026-09-28

Status: `CONTRACT_REJECTION_CONFIRMED`

Attribution matrix:

- MAXIT 8: 0/8 complete;
- MAXIT 16: 0/8 complete;
- MAXIT 32: 0/8 complete.

All failures occur on step 1 with:

- solver status = FAILED;
- retry_advised = false;
- nonlinear iterations = 0;
- backtracks = 0;
- Jacobian builds = 0;
- linear solves = 0.

The failure therefore occurs before HeadCalc nonlinear work.

Source inspection confirms the explicit Reference adapter currently rejects any request with:

`conductivity_implicit_mode /= 0`

and labels that route:

`legacy-implicit-k-deferred`.

Classification:

`SWKIMPL1_EXPLICIT_PROVIDER_CONTRACT_BLOCKER`.

The preregistered fallback classification based solely on MAXIT completion is superseded by this direct source attribution. No gate is relaxed and no BDF2 result is rescued.
