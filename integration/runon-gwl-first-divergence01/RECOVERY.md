# Groundwater first divergence, short causal investigation

Baseline canonical0f12c639da5c4dadf488282dc8e110d2a8ad1874; previous admitted
pond history fec7b4415 and supplementary audit68e74d5ac retain original evidence.
Owning experiment: water-surface-history, original Hupsel derived SWMACRO0,
SWRUNON1, SWPONDMX1, SWHYST2. First daily GWL difference day1 is0.000456289042cm;
the entire maximum2.706810392011cm appears day5,2002-01-05 fixed surface
irrigation24mm/12mm/h. SWAP5 runoff0.190725404235cm; original431 runoff0.
That difference predates day200 runon/restart. Day5 water stock delta
-0.122125309420cm and drainage delta-0.068532590508cm account for the runoff.

First hypothesis: temporal discretization or pond-boundary nonlinear policy,
not missing forcing or restart. Reuse existing literal-input full trajectories.
Use short five-day original DTMAX refinement before diagnostic instrumentation
or production edits. Distinguish first tiny numerical divergence from first
material/event divergence. Each original run capped20s, generated SWAP5 trial30s;
no full/performance campaign. Keep all water/solute guards1e-10 and all
scientific criteria unchanged. DTMAX refinements are explicit diagnostic input
changes, never relabelled original-input equivalence. Compare nominal shortened
reference prefix to immutable full first5 before interpreting refinements.

Canonical frost additions must be reconciled for this frost0/snow0 case before
fresh current builds or reuse claims; no old native capsule rebinding. Read
current admitted source and prior O/M scientific dispositions. Preserve rejected
trials, source/build/input identity, exact commands and numerical results.
Deliver a source-bound causal explanation or justified repair plus affected
O0/O2/regression verification, published on the own branch/PR as appropriate.

COMPLETED: initial same0.0002day step differs1.06533e-9cm GWL, then adaptive
grids diverge. Material maximumday5 explained by exact pond Newton derivative
allowing coarse0.04day pulse steps which original rejects3times. Derivative-only
original counterfactual retains identical days0..4 and shiftsday5 GWL2.54325cm.
Matched five-day refinement0.004/0.0004/0.00004 in both models reduces gap to
0.001182635609cm; O0/O2 endpoints identical. Guards unchanged. No production
repair/admission or scientific PASS is claimed. Preserve raw, publish this
explanation and link from PR1694; next optional implementation is event-local
temporal-accuracy selection, not a globally reduced timestep or weaker tangent.
