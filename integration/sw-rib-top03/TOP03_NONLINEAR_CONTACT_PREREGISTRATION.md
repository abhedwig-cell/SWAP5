# TOP03 independent nonlinear stationary contact preregistration

Date: 2026-10-02. Test-only research, no production admission.
Workstream/work unit: SW-RIB / SW-RIB-TOP03; dedicated baseline
3c3171ec223d2b7f5b93b0a75b62d2b7c40ab4b7; inspected canonical
f7c261a7f059c91d4a0aac16e378351f293aa080. Only the oxygen closeout document
changed since inspected canonical 0c18a9ff; compiled semantic dependencies
remain fixed on the dedicated branch, not reconciled/admitted to canonical.

## Local closure and ownership

Implement the previously proposed finite-volume stationary layer directly.
All layer and matrix-side K values are evaluated at the same candidate heads.
Each residual is qi-q(i+1)=0; solve this local problem independently of
HeadCalc's origin-frozen interior K. Keep the actual B1.10 constitutive cutoff.
Do not smooth it, choose a fitted resistance or alter the production solver.
Use L=0.20 cm, R=0.50/1.00 day, Nlayer=2m and the same top arithmetic and
interior/interface harmonic series conductances as the explicit comparator.

Newton uses the local tridiagonal flux Jacobian, bounded total heads, 100
iterations and 40 Armijo halvings. K derivatives use branch-preserving finite
differences of the public constitutive evaluator; never differentiate across
the conductivity discontinuity. The local flux residual target is 1e-11
cm/day. Solve from three separately labeled starting guesses: saturated-series
profile, dry -123 cm and wet zero, each clipped to admissible total-head bounds.
A result is available only when all three converge and agree within 1e-7 cm
in heads and 1e-9 cm/day in flux. This tests those starts; it is not a theorem
of global root uniqueness. A local numerical failure or disagreement returns
unavailable, not an invented massless flux. Preserve every failure.

Reconstruct interface pressure independently from layer and matrix sides.
Condense the local Jacobian for dq/dhs and dHinterface/dhs. The dynamic provider
returns that physical interface head, matrix K and its actual interface-head
derivative. The unchanged SWKIMPL=0 outer Jacobian treats its face K as fixed;
this remains a quasi-Newton approximation, not an exact total flux derivative.
Do not insert a fictitious surface-head derivative to circumvent the ABI.
Candidate residuals still use the actual nonlinear flux. The provider has
immutable parameters/forcing and disposable local scratch, no layer time or
storage state. Its external and matrix transfer are equal only because the
stationary diagnostic has no changing storage. This cannot qualify a stateful
physical layer or an external receipt that omits real layer storage.

## Fixed control and trajectory matrix

- 18 saturated real-kernel analytical controls: R=0.5/1, m=8/16/32, explicit,
  previous constant R and the new nonlinear closure. Exact Darcy head/flux
  limits remain <=1e-9 cm and <=1e-10 cm/day.
- 468 standalone boundary points: both R, all three m, all six original H,
  and hs=-123,-20,-5,-3,-1,-0.1,-0.02,-0.0125,-0.012385,-0.005,0,0.3,10 cm.
  Record each starting-guess root, consensus, independent face residual and
  top/matrix flux identity. Flux residual/identity <=1e-10 cm/day; two-sided
  interface-head difference <=1e-9 cm. Available condensed derivatives are
  checked against independent pressure perturbations using absolute 1e-6 plus
  relative 1e-4 budgets. Branch-crossing/unavailable perturbations are labeled,
  never passed as smooth derivatives. The layer parameters must be unchanged.
- 72 dry-matrix six-event trajectories: both R, m=8/16/32, ns=128/256/512,
  full layer dry/prewet, previous constant R and new stateless closure. The
  unchanged 54 inherited trajectories must reproduce exactly. Each accepted
  new candidate must pass independent local closure, interface-head and flux
  checks. Whole-soil mass <=1e-10 cm and exact request-origin immutability are
  hard gates. Event times/forcing, soil, bottom mode7 and solver policy stay
  fixed. Analytical mode5 controls remain separately labeled.

This totals 558 cases/build at O0 and O2, compiled with GNU Fortran 13.3.0,
bounds checks and floating-point traps. No Actions run is needed. Compare all
physical numerical stdout and return codes exactly. Successful raw records
must agree; optimizer-dependent fatal backtrace addresses are retained raw
but cannot count as physical output differences. Fatal provider unavailability
is classified only with an explicit CONTACT_UNAVAILABLE marker and the exact
HeadCalc unavailable diagnostic; every other runtime error is a hard failure.

## Physical decision and recovery

Apply independent space/time readiness to each compared trajectory with the
previous fixed budgets and contraction requirements: m=8/16/32 at ns512,
ns=128/256/512 at m32. Finest-pair top/bottom errors <=0.001 cm + 0.5%, water
L1 <=0.001 cm and head infinity <=0.1 cm; top/bottom/water must contract unless
<=1e-10 cm. Physical equivalence budgets stay 0.005 cm + 2% for external,
matrix-interface and bottom transfer, water L1 0.005 cm and head infinity
0.5 cm. A failed local prerequisite or incomplete/unready series means null,
not physical equivalence/falsification. Report all six events for both layer
origins, not only final heads. No parameter tuning after seeing the result.

Persist this preregistration and source before compilation. Continue through
failure analysis, responsible test-only numerical repair when justified,
replay and evidence persistence. Any changed numerical strategy or expanded
matrix needs a versioned follow-up with the original failure retained.
Physical storage/state ownership and production/shared interfaces remain
outside this implementation. Invariants 3/5/7/11/13/14/22/23/28 govern this
boundary; BASE acceptance, receipts, restart and canonical admission remain
unqualified. PR #956 stays draft, no branch creation or merge.
