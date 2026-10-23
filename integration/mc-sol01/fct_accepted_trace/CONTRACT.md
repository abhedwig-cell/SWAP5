# Accepted-water trace research

Baseline67a213094,23October2026. Isolated successor to the admitted changing-
storage prototype. No production/default/interface changes. Actual Reference
water trials commit before their accepted substep traces are exported. The
existing production continuity reconstruction supplies mean downward face fluxes.
No rejected trial, interpolated endpoint-only trajectory or manufactured water
trace substitutes for that interface. No RossFast execution.

Water case: uniform40cm material,40/80/160 cells, initial head-75cm, top flux
0.8/1.2 times initial gravity conductivity, bottom fixed initial conductivity,
two days, twenty0.1day windows, existing temporal budget1e-3. Root/drain/source/
pond/snow/heat/age remain off. Exact checked O0/O2 providers and hard1e-10 water
mass gate. Fresh closure cost expected150s total; native/reference UNKNOWN,
bounded120s per process. No annual/full-FCI/highest-low-air/RossFast selection:
unchanged production source, bounded research seam only.

The first replay fails at the unchanged production empty-pond subtraction:
roundoff makes the residual negative despite exact physical zero storage.
This successor explicitly selects the EXISTING `exact_empty_pond_limit` physical
option for BOTH low-order and corrected solves. A generated research provider
differs from the frozen storage module only by those two keyword arguments;
its exact source/delta/hash are retained. No formula, guard or production
default changes. This is not evidence for the unselected default surface route.

The separate small replay calls the frozen real production process plus research
correction for each actual accepted substep. Gaussian cell-average concentration
with positive0.05 background and constant-solution controls, Freundlich0.5/1/2,
Kf0.2. Input trace, beginning water and clock must agree exactly. A whole-batch
candidate is private until every substep succeeds. Duplicate or broken later
carrier rejects without publishing a successful prefix. No new native restart
or joint water/chemical production acceptance is implied.

Accuracy reference: independent method-of-lines first-order upwind finite-volume
ODE, stable algebraic Freundlich inversion, adaptive DOP853. Each accepted coarse
water cell is subdivided8/16 times; theta varies linearly in time, q linearly in
space, so each fine cell conserves the recorded carrier water. Initial coarse
total density is replicated in subcells, hence exactly the same initial mass.
Fine mass is averaged to coarse cells. Refinement uncertainty is retained and
must be materially smaller than the measured coarse correction error before an
accuracy improvement is claimed. This is a reference for the recorded piecewise
carrier, not a known solution of full coupled Richards/transport or native-year
accuracy. No existing physical acceptance threshold is weakened.

Additional accuracy selection before its execution: retain the8/16 reference
round, then compute32/64 subcells on all18 nonconstant O2 carriers. The8/16
spread is as large as52% of corrected error, so it is insufficient to certify
all corrected error values. Require the32/64 spread to decrease, stay<=25% of
corrected L1, and corrected L1 plus twice the spread to remain below low-order
L1. Corrected error must decrease over40/80/160cells for each of six parameter/
water combinations. Expected additional cost<30s, no native/water/Fortran rerun.
These are empirical reference-resolution criteria, not a rigorous PDE bound.

The32/64 gate failed only160cell dry/exponent1 and wet/exponent2, with25.70%
and28.06% spread relative to corrected error. Retain that failed review and add
128subcells only to those two unresolved references. Apply the SAME25% and
separation criteria to64/128; expected additional cost<10s. No new Fortran/water
execution, cases removed or acceptance criterion relaxed.

Affected invariants:3,5,7,13,21,22,23,25,29. No persistent solver scratch or
dependency on water solver internals. Existing source/raw and both predecessor
capsules remain required for research admission. Record failed/censored results.
