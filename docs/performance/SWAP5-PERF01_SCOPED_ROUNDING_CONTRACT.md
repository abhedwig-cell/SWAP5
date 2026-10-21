# PERF01 representable-head experiment after trace reclamation

Baseline `d7b891759a8c378ba0367e1a1a112c684712199f`, including admitted
transaction-scoped trace cleanup and the concurrent original SWP input adapter.
This is an experimental numerical work unit; no production solver change is
selected or admitted yet.

The earlier independently replayed dry32 failure has Newton updates smaller
than half a binary64 head spacing. The generated one-ULP trial can satisfy the
unchanged local criteria for some such iterates, but its sixth-window execution
was previously resource-censored. This experiment repeats that same algorithm
with the admitted memory correction, rather than inferring scientific success
from the memory result.

Generate only the earlier closed-input-domain HeadCalc block: all32 heads
stagnate, all are unsaturated, compartment balances pass, total balance fails,
explicit conductivity, fixed bottom flux, no macropores. Select one interior
adjacent head by the capacity-based predicted total residual, then recompute
native constitutive storage, gradients and residuals. Every original local,
surface, mass, temporal and transaction acceptance check stays in the path.
The original generator and algorithm are imported unchanged and source-bound.

The new driver supports the latest observing application and original TTUTIL
archive linkage. Generated observations add progress/counters only. It records
an unmodified-numerics control on the same fresh build as well as the correction.
It records
every compile/link command and source/object/archive identity. Each native
process has a512MiB address-space cap and90s wall limit; wait4 supplies its own
RSS. Nonzero, timeout and signal outcomes remain failed or censored observations.

A completed sixth window permits selecting O0/O2, fresh-process continuation,
temporal-refinement and independent-error checks. It does not establish a full
day, global accuracy, portable speedup or a production correction. Failure or
continued excessive accepted-step counts require diagnosis before selecting a
new algorithm. Never relax tolerance floors or rewrite committed state to force
completion. Invariants3,5,7,22,23,25,26 apply. RossFast and long low-air stress
remain outside this work unit.

## Late temporal-indicator capture

The matched control reproduces the original failure exactly. The generated
correction is still incomplete after90s: the last sample reaches internal
cursor0.087114026 after45312 accepted substeps,197266 solver rejections and
658234 temporal rejections. Peak RSS324000KiB remains below the address-space
limit. This is a censored numerical/cost counterfactual, not model completion.

Select one short diagnostic continuation from the same fresh build: after
internal cursor0.0865day, capture the first64 rejected temporal comparisons.
Observe the exact current trial duration, all32 full/half heads and water
contents, pond depths and groundwater levels. The existing indicator remains
unchanged. Stop deliberately after the64th captured comparison with a named
diagnostic marker; this is never an accepted reporting window. The question is
which physical component drives the small-step rejection and whether it is
consistent with the claimed local rounding mechanism. This extra observing
closure recompiles only the generated transaction and tiny temporal-indicator
providers in addition to the earlier trial providers. Native execution remains
bounded by90s/512MiB; expected work is seconds to the capture cursor.

## Empty-pond evaporation counterfactual

The64 captured comparisons isolate the uppermost head. For18 small-step
comparisons, the reconstructed full-minus-half water amount divided by trial
duration is almost exactly+/-0.025cm/day: half the prescribed pond evaporation
of0.05cm/day. The existing provider selects that evaporation from the previous
pond depth using a1e-10cm classification. Endpoint ponds alternate between zero
and tiny positive depths. This is a separate surface switching question, not a
justification for changing temporal tolerances or admitting the one-ULP method.

Select a generated-only implicit endpoint constraint in the closed pond-only
demand experiment (zero bare-soil demand, no macro donor/partition, fixed explicit
top conductivity and positive infiltration capacity). Let I denote surface
input, P0 previous pond depth, dt duration, Epot pond evaporation demand and Qc
the zero-surface-head infiltration capacity. Resolve a dry endpoint with zero
evaporation when I+P0/dt<=Qc; resolve a zero-pond/head endpoint with limited
evaporation I+P0/dt-Qc when this lies between zero and Epot; otherwise use full
Epot and the existing analytical positive-pond/runoff equation. This is an
experimental physical coupling change, explicitly outside production admission.

The middle branch has P=0, surface head=0, infiltration=Qc, evaporation within
the demand bound and exact surface water balance. It represents simultaneous
water supply/infiltration/evaporation at the active empty-pond constraint. No
classification threshold, acceptance criterion or budget floor is relaxed.
The old algorithm remains the production reference. Test its scalar boundary
closure against this proposed constraint, including conservation, demand bounds,
continuity and a whole-step/two-half-step frozen-head test. Then run six windows
with **unchanged HeadCalc**, without any one-ULP correction, on the same fresh
O2 provider build. Native limits remain90s/512MiB. A completed counterfactual
still requires profile/restart/refinement and reference-policy qualification
before a production proposal.

## Exact empty-pond solute limit

The six-provider scalar surface replay passes45 conservation/bounds/split/continuity
observations in both O0 and O2. The full water trial reaches window6's endpoint,
but chemistry rejects at substep5219 in `advance_persistent_pond`, with POND_MASS
status. The observed pond depths are both zero; incoming solute should all enter
the soil. The existing expression divides by infiltrated water, then multiplies
back and subtracts from available mass. This can leave a negative rounding residue
at an analytically zero pool. Select a capture of the actual prior pond mass and
an independent two-source replay of that exact exchange.

A separate generated numerical counterfactual uses the analytical limit only
when the existing infiltration branch applies, endpoint pond depth is exactly
zero, macropore area is exactly zero and runoff is exactly zero: transfer all
available solute to soil and store zero pond mass. Preserve concentration and
the original general mixing law. This is not a negative-mass clamp or tolerance
change. Both persistent-pond and reactive-matrix callers continue to use the same
production mixing interface. Validate original failure, exact mass conservation,
nonnegative zero-pool state and O0/O2 before selecting production changes.

The actual rejected mass-before is2.1175823681357508e-22mg/cm2; the original
mixing formula yields a negative one-ULP residue at substep5219. The combined
generated surface constraint and exact mass limit completes the coupled sixth
window at0.09375day, with unchanged HeadCalc and no one-ULP head correction.
Select the three-source original/candidate mass replay, fresh current O0 build
and six-window comparison, and an O2 fresh-process restart from window6 through
the prescribed full day. A90s/512MiB full-day continuation is an essential bounded
completion question for this previously failing input, not a routine migration
or stress gate. If it completes, select independent full-run restart and temporal
refinement before any production proposal.

## Independent continuous water reference

The generated candidate completes all64 windows through1day, continuing from a
fresh sixth-window restart, in81.4s/137400KiB. Water and solute residual maxima
are9.54e-14cm and2.70e-13mg/cm2. The O0 six-window trial also completes. These are
counterfactual results, not production admission or a matched-physics speed claim.

Select an independent Python/SciPy finite-volume water reference using the
closed-form MvG retention/inverse/conductivity, arithmetic internal-face means,
the same32 cell widths, fixed root/drain sinks and zero bottom flux. Resolve a
zero-pond stage algebraically and terminate it at the capacity=I-Epot event;
then integrate positive pond depth and linear runoff. This reference imports no
Fortran provider or native objects. Solve twice with BDF rtol1e-9/atol1e-12 and
rtol1e-11/atol1e-14. Require independent reference spread below1e-4cm head,
1e-8 water content and1e-8cm pond, and reference whole-water residual below1e-10cm.
Measure candidate errors at all64 reporting times; do not reinterpret local
step tolerance as a global-error bound. Chemical correctness remains covered by
its native independent process tests and conservation, not this water reference.

The first independent1e-9/1e-11 reference pair misses its declared head-spread
budget (1.32e-4cm versus1e-4cm), although water-content and pond spreads pass.
Retain that failed reference assessment and tighten the independent solves to
rtol1e-11/atol1e-14 and rtol1e-13/atol1e-16, without relaxing the spread budget.
Separately select an uninterrupted O2 full-day run (120s/512MiB) to compare
exact endpoints, restart, trajectory, budgets and deterministic work against
the existing sixth-window fresh-process split. Once it completes, select a
tighter native1e-7 temporal run over the full day, capped360s/512MiB. Its expected
cost is roughly three times the measured baseline; this expensive experiment is
selected specifically to compare global errors against the independent reference
at the late wetting front, not for routine feedback or inherited gate status.
Require decreasing measured head/water-content errors before any accuracy claim.
