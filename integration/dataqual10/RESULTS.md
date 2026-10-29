# DATAQUAL10 bounded conservative-stock Jacobian

The old derivative freezes the common stock limiter fraction. An actual imported
production-rate example has a capped flux constant at -0.5, but an analytic
derivative -0.5 rather than finite difference approximately -3.47e-11. This is a
numerical derivative defect, independent of the already corrected stock update.

For fixed accepted stock and geometry the complete local exchange derivative is
`diag(d) - u*d^T` per active domain. A sibling provider returns the diagonal and
shared-stock factors in one evaluation. HeadCalc restores the frozen diagonal
and solves the tridiagonal matrix plus this low-rank update using Woodbury with
pivoting. Rank-zero and the production path retain the original solve. Singular
updates request retry. Active coupling with frozen-tridiagonal factor capture
also rejects the trial because that carrier cannot represent the full matrix.
No fallback silently discards the coupling.

## Final-source evidence

- Cold checked O0/O2 builds use194 actual providers and203 hashed source inputs.
- Per optimization:48 conservative rate cases,72 complete finite-difference
  Jacobian columns,48 exact legacy controls. The predecessor has24 derivative
  failures among the same48 conservative fixtures. Maximum feedback error is
  1.6598207253082364e-9. Geometry and other constitutive approximations are held
  fixed; this is not a full geometry/topology/partial-top Jacobian claim.
- Per optimization:216 low-rank matrices, maximum residual2.2204460492503131e-15;
  a singular full matrix is explicitly rejected.
- Actual immutable FSI35 task2/surface/dispatch oracles pass O0/O2. Three of27
  source dependencies changed and are requalified;24 remain unchanged. The stub
  receives the pre-existing explicit SWSOPHY=0 interface shim only.
- The selected wet O0/O2 endpoints and physical restart payload are exact;
  complete versus split/resumed outputs and restart are exact at each optimization.
- Both existing two-day routes preserve six streams and physical restart payload
  exactly against DATAQUAL09. The rounded SWAP4.3.1 comparison remains descriptive.
- Capsule-native zero-step restart replay reproduces state, temperature and the
  restart exactly, without repeating physical intervals.

## Model coverage and limits

Final30 scenario rows execute34 native processes including four split/resume
processes:12 qualified rows,17 budget censors,1 numerical stall. Measured native
wall times sum1395.8322401699952seconds, including split/resume processes. Parallel
work was concurrent; these sums are process wall time, not elapsed session time
or a controlled speed benchmark. Exploratory diagonal-only and initial duplicate
evaluation runs are retained separately and are not final-source qualification.

Different executed configurations remain151; different water-qualified
configurations remain83, six above DATAQUAL06's77. These are variants of one
original Andelst project. Qualified configuration-days are94.7479999997231 with
maximal prefix per physical/numerical configuration signature, excluding logging
and conservative-policy flags from the historical denominator. This is11.698days
above DATAQUAL06's83.05 and0.3885 above DATAQUAL09. The additional prefix is expanded
bounded execution; code-only attribution and native speedup are not established.

The original fresh integral maximum remains2.7479999999995925. The changed
candidate's bounded fresh run publishes day2 before censoring; its own day2
continuation also censors. No new original-stall diagnosis or larger budget was
used. The previously reproduced day2.848675 blockage and exact rollback remain
the closure evidence. The lighter selected case reduces Newton work from14885
to14782 iterations, but wall time does not establish an acceleration.

Physical rates, tolerances, mass checks, rollback, restart layout and production
admission are unchanged. No new physical process, other original project, full
numerical F-CI, seasonal/year-boundary completion, energy/solute/N or full431
equivalence is claimed. Remaining closure work: original long-route stiffness;
other original projects; missing historical process combinations; energy and
chemistry/N qualification; historical CI recipes and identity guards.

Authority: STATUS.json, RESULT.json, BUILD_O0.json, BUILD_O2.json, CAPSULE.json,
the source-bound current verifier and a later actual canonical merge receipt.
