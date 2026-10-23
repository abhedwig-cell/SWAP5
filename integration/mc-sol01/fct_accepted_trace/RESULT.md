# Actual accepted-water replay and bounded accuracy

The research correction now consumes actual committed Reference water traces,
not prescribed storage changes. Fresh checked O0/O2,163-provider water closure:
12 complete two-day runs,2486 accepted substeps,40/80/160cells, both0.8/1.2
initial-conductivity inflows. Existing production continuity reconstruction and
hard water balances pass. Water traces are bitwise identical across optimization.

The small8-provider replay gives72 complete histories,360 late whole-batch
atomic rejections and72 exact split continuations. Final mobile, sorbed and
concentration arrays are exact O0/O2. Maximum cumulative/step chemical residual
5.371e-14mg/cm2, equilibrium residual2.832e-15mg/cm2 and constant-solution
error1.788e-14. Every failed late prefix leaves original mass, water and clock
exact; split continuation reproduces the successful endpoint.

Independent adaptive DOP853 finite-volume upwind references subdivide the same
piecewise accepted carrier. Initial mass is exactly shared, water interpolation
is conservative, Freundlich inversion uses independent stable algebraic roots.
The8/16 round was insufficient to resolve corrected error. All18cases received
32/64subcells; two160cell cases failed the predeclared25% spread criterion.
Only those two were extended to128. The unchanged criterion now passes all18,
along with decreasing corrected L1 over40/80/160cells for all six combinations.
Corrected/reference L1 is0.119 to0.586 times low-order/reference L1, a41.4% to
88.1% reduction for THESE carriers. Remaining reference spread is retained,
at most24.861% of corrected error; twice that spread stays below the improvement.
This empirical refinement is not a rigorous full coupled PDE error bound.

One initial export failed because its research driver omitted public standalone
context initialization. Two diagnostic replay rounds exposed the unchanged
default surface subtraction roundoff at exact zero pond depth. This experiment
explicitly selects the EXISTING exact-empty-pond physical option for BOTH
comparators, through an exact two-keyword generated successor of the frozen
research module. No physical formula, default or mass guard changes. All failed
source/raw rounds, including the failed32/64 review, remain in the proof.

Current qualified water cost87.606s, replay plus first reference96.857s, extra32/64
reference13.935s and final selective extension6.569s. Initial failed export and
replay costs remain separate in `EVIDENCE_INDEX.json`. These are local execution
costs, not a portable speedup claim.

Current original owner plus36controls and both frozen prototype capsules plus
8/6controls pass. The869-member capsule has12 additional evidence controls.
Production, default, native dispatch and admitted physical/restart owners are
unchanged. No joint native water/chemical acceptance, native-year accuracy,
active crop/root/drainage/dispersion/decay/age or full MC-SOL01 claim is made.

Canonical reconciliation at3461a520 includes the changed Boesten shared backend;
hydraulic-view binding is outside this closure. Fresh163-provider O0/O2 builds and all12 water
runs,72 replays and independent references were repeated. Every water trace,
replay profile and complete accuracy result exactly reproduces the earlier
published2570ba6f proof. Current owner36 and all12 new evidence controls pass.
The earlier17/40-control receipts stay historical. Compiler-link and startup
failures are separately retained; both were environment failures before any
current native water case. `CURRENT_RECONCILIATION.json` binds both capsules.
