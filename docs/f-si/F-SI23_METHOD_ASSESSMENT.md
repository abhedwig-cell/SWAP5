# F-SI23 Method Assessment

## Purpose

F-SI23 starts after F-VQ29 failed closed because the frozen calibration could not obtain the deeper finite backward-Euler reference required to test a geometric tail bound. The first calibration case was not floor-resolved under the predeclared rule and the mandatory N=1024 trajectory did not converge under the frozen 8/4 nonlinear solver controls. F-SI23 therefore does not extend the same reference ladder and does not retune that solver to manufacture a reference.

The owner question is narrower: is there a Richards-specific temporal error estimator or independent reference construction that preserves SWAP mass conservation, transactionality and generic time while avoiding dependence on an unavailable over-refined backward-Euler endpoint?

## Existing SWAP evidence that constrains the choice

F-SI20 already classified the fine-step cliff as a nonlinear solver ceiling rather than DTMIN or mass rejection. The first failed direct solve occurred at 3.0517578125e-5 d, hit max_iterations=8 and returned RETRY_ADVISED. It also showed that tightening nonlinear head and ponding tolerances from 1e-12 to 1e-14 changed the fixed-horizon refinement curve only marginally. This makes a simple tighter-tolerance reference neither an independent temporal reference nor a justified cure for the cliff.

F-SI22 qualified same-horizon endpoint differences as Richards-owned observables but did not qualify a defect-to-error multiplier, Richardson factor, normalization or scientific tolerance. F-VQ28 then rejected translation of that observable into the existing endpoint-shortening transaction retry topology. F-VQ29 subsequently showed that a deeper same-discretization finite reference is not generally available under the frozen numerical profile.

## Route A: embedded mass-conservative temporal error control

Kavetski, Binning and Sloan, "Adaptive time stepping and error control in a mass conservative numerical solution of the mixed form of Richards equation", Advances in Water Resources 24, 595-605, DOI 10.1016/S0309-1708(00)00076-2, is the closest methodological match found so far.

The published abstract states that the method applies embedded error control to the mixed form of Richards equation. Local truncation error is approximated in pressure head while the principal time approximation is formulated in moisture content to enforce mass conservation. The reported scheme is closely related to an implicit Thomas-Gladwell approximation and is second-order accurate in time.

This is attractive for SWAP because it separates two concerns that F-SI20 through F-VQ29 have repeatedly shown must not be conflated: conservation of stored water and estimation of temporal discretization error. It also suggests that a temporal estimator need not be defined as the distance to an ever-finer backward-Euler trajectory.

However, this paper is not yet a drop-in algorithm for SWAP5. Before any implementation, F-SI23 must reconstruct the actual discrete formula, required history variables, treatment of constitutive nonlinearity, start-up step, variable-step semantics and acceptance/error controller. The finite-element setting and exact mixed-form discretization in the paper cannot be assumed equivalent to SWAP's HeadCalc discretization.

Current assessment: PRIMARY FEASIBILITY CANDIDATE, not qualified.

## Route B: residual-based a-posteriori estimators

Baron, Coudiere and Sochala, "Adaptive multistep time discretization and linearization based on a posteriori error estimates for the Richards equation", Applied Numerical Mathematics 112, 104-125, DOI 10.1016/j.apnum.2016.10.005, derives computable residual-based error estimates for Richards flow and separates space discretization, time discretization and linearization contributions. Their concrete construction uses BDF2 and a discrete-duality finite-volume spatial scheme.

Mitra and Vohralik, "A posteriori error estimates for the Richards equation", arXiv:2108.12507 and subsequent publication lineage, develops reliable and locally efficient a-posteriori bounds for degenerate Richards flow and explicitly separates contributors including time discretization, linearization, flux nonconformity, quadrature and data oscillation.

These works are valuable because they show that temporal and nonlinear-solver error can in principle be distinguished mathematically, which is directly relevant to the F-SI20 fine-step cliff. They are not directly transferable constants or formulas for SWAP. Their norms, reconstructions and spatial discretizations differ from the current 1D HeadCalc route. Any production claim would require a SWAP-specific derivation or a tightly qualified restricted mapping.

Current assessment: THEORY REFERENCE and possible fallback if Route A cannot be mapped cleanly.

## Route C: method of manufactured solutions

Roache, "Code Verification by the Method of Manufactured Solutions", Journal of Fluids Engineering 124(1), 4-10, DOI 10.1115/1.1436090, describes MMS as a code-verification method based on a deliberately chosen exact solution with corresponding manufactured source terms.

MMS solves a different problem from the F-VQ29 finite-reference problem. It can provide an exact transient truth for a test-only Richards case and is therefore useful to verify implementation order, temporal estimator response and source-aware mass accounting without any N=1024/N=2048 reference. But an MMS pass alone says little about estimator reliability for the actual B110 hydraulic envelope, difficult dry states or prescribed-head coupling cases.

Current assessment: REQUIRED INDEPENDENT VERIFICATION AXIS if an estimator prototype is later implemented, but not a production-physics qualification by itself.

## Current owner decision

Do not open F-VQ30 yet. Independent qualification needs a concrete owner-side estimator contract first.

F-SI23 Gate A should reconstruct Route A at equation and state-transition level and compare it with the actual SWAP semi-discrete mixed Richards formulation. The output must state exactly:

1. which accepted and trial states are required;
2. which history is persistent state and which quantities are worker scratch;
3. how the mass-conservative advance is formed;
4. how the local temporal error estimate is formed and in what units;
5. whether the estimator changes the accepted physical state or is decision-only;
6. how startup and variable step ratios work;
7. the maximum number of nonlinear solves required per attempted interval;
8. what is recomputed after rollback;
9. what diagnostic values are first-class outputs;
10. which statements require later independent F-VQ qualification.

Only after that reconstruction may F-SI23 freeze a test-only prototype. No scientific/application tolerance belongs in this workunit.

## Invariant assessment at workunit start

- Transactionality: no committed state may be changed by an unaccepted embedded trial.
- Generic time: formulas must apply over arbitrary [t0,t1], not calendar days.
- Mass conservation: temporal error estimation may not relax or replace the hard water ledger.
- Cost: a candidate requiring an unbounded refinement ladder is rejected even if accurate.
- Solver policy: estimator design may request explicitly defined numerical operations but may not silently change physical options or reinterpret nonlinear convergence tolerances as temporal accuracy.
- Reference mode: the full Richards reference mode remains available and independent of any later balanced/throughput policy.
- Alternative solvers: the eventual temporal-control interface must remain solver-owned and must not hardwire the kernel/runtime to one HeadCalc implementation.
