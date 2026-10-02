# MIGMAC01 source-origin replay: substantive blockers
Date: 2026-10-02
Status: BLOCKED_SOURCE_ORIGIN_COMPOSITION_NOT_QUALIFIED
Reference evidence: 9eaf64ac572e080f77e8ea03a17b43ce220e19df.
Replay preregistration: 76cdc7a9746651befda46093df65117138d80f7f.
Latest canonical rechecked: 6cc03d6e122bdcd2007c1a709476ce63a68d6e36.

## Established source event
The preregistered single-change modified-Andelst B1.11 run has an active covered
top (node 3), accepted h(2)=+0.09997836037968703 cm and covered transfer
6.0543248402701375e-5 cm. Its covering-cell matrix sink is exactly opposite,
and macro balance including other matrix exchange and rapid drainage is
2.0973891026732083e-16 cm. Complete CSV and source identities are persisted.
G2 (no active reconstructable source event) is resolved for the explicitly
modified case, not for unmodified official Andelst (which has surface top).

## Fixed SWAP5 experiment
112 nodes, five domains; source origin h/theta, cofgen, geometry, continuation,
root/irrigation/drainage, ponding and groundwater. Boundaries replay frozen
source accepted qtop/qbot with explicit top flux and SWBOTB=2, dt=0.002.
External macropore top forcing remains absent. Original synthetic fixture
was not tuned or replaced. Numerical tolerances remain 1e-12 for the solve;
production internal/macro tolerances remain 1e-9. Source CRITUNDSATVOL=0.1
(swap.swp line 348) is explicitly bound. A preliminary omitted/default zero
was corrected from source, and the final experiment remained blocked.
This is configuration recovery, not a parameter sweep.

Geometry matches source within 6.94e-18 cm and bottom nodes match exactly.
Source storage canonicalization differences are below the existing strict
tolerance. Root extraction binds through the separate admitted root provider;
the F-SI10 generic source/sink provider correctly rejects active root forcing.

## Positive operator, failed composition
At the frozen positive reference head the current provider produces covering
sink=-0.030265002199281903 cm/day; B1.11 final-head formula independently gives
6.0530004398563807e-5 cm over dt. Their cancellation is exact. This confirms
that the covering operator is active when supplied the positive source head.
Legacy booked receipt differs slightly because it lags the last nonlinear head.

The independent source h-to-theta reconstruction is bitwise identical to the
captured source theta (max difference=0). The comparison probe uses exact
captured source h and theta, eliminating constitutive reconstruction as the
cause of this probe discrepancy.

At that same source state, current other exchange is -4.8670615087679892
cm/day; reference booked other exchange is -0.40973640650434007 cm/day.
Maximum per-node difference=0.62692347867975562 at node 26.
Nodes 15–26 show negative matrix-to-macro exchange in the SWAP5 probe while
the reference booked exchange there is zero. This is a substantive background
exchange/carrier discrepancy, much larger than the tiny covered receipt lag.
It must be attributed through current-state saturated/perched classification,
source bookkeeping timing and limiter ownership. The probe uses accepted
origin macro storage against final matrix heads, matching the trial-local
runtime convention. It does not establish a blanket PERCH21 falsification.

The ordinary no-macro replay converges to h(2)=-0.24296022963416691 cm with
matrix mass residual=-3.716679741749829e-16 cm. The fully coupled runtime requests
retry after 64 iterations. The last tentative head is
h(2)=-4.9798361798199382 cm; it is NOT an accepted state.
Read-only Newton diagnostics showed final compartment residuals of order
2e-13–7e-13 cm/day, but the complete strict convergence gate did not pass.
No tolerance was changed. On retry, the solver restores the accepted origin;
that restored head must not be reported as a converged head.

The runtime result currently does not retain the failing matrix result:
its matrix status remains NOT_RUN and closure fields remain huge sentinels.
A temporary diagnostic-only assignment exposed actual matrix RETRY status=2;
it was reverted. Read-only HeadCalc prints were also reverted. The persisted
diagnostic instead reports worker iteration count and the last tentative head
from workspace, while retaining production code unchanged.
Accepted macropore state remains bitwise unchanged after the rejected attempt.

## Two independent integration gaps
1. Serialized backend calls macropore runtime without either optional
covering_minimum_polygon_diameter_cm or covering_ksat_cm_per_day.
For top_node>1 the inner provider requires both. Physical configuration has no
fields carrying them. This is a concrete transaction path defect, independently
of the failed direct replay. Repair needs explicit source-backed immutable
physical configuration and backend propagation, then transaction tests.
2. Explicit/provider HeadCalc deliberately sets local swmacro=0; its
matrix_fraction function therefore returns 1 and conductivity is not multiplied
by source FrArMtrx. The typed request has no matrix-area carrier. Setting the
legacy module array in the diagnostic has no effect on this explicit path.
Source fractions in nodes 15–26 are approximately 0.963–0.965.
This is an independently demonstrated representation gap; it is not proven
to be the sole cause of the other-exchange discrepancy or retry.

Both gaps were rechecked against canonical 6cc03d6e122bdcd2007c1a709476ce63a68d6e36.
No shared-interface repair was silently made. Source-origin qualification
cannot honestly proceed by changing h, dt, forcing, disabling perched physics,
loosening convergence criteria, or treating rain as covered macropore inflow.

## Lifecycle and preservation
The local O0/O2 diagnostic records the same negative outcome. It is a
reproducible negative-evidence gate, not active E2E qualification.
Original f88c1fc prerequisite / run 36925950836 remains historical authority.
No fresh PERCH20/PERCH21/A9/A10 preservation run or admission evidence is claimed.
No production file changed in this evidence block. No Actions were dispatched.
The frozen Status-A denominator is unchanged. Covering-layer migration remains
an open production gap; M2 dynamic geometry remains a separate line.

Next safe work: preregister and reconcile the explicit matrix-area and immutable
covering-parameter contracts on the current canonical dependency surface;
attribute the saturated/perched rate discrepancy using the persisted source
state and source operator receipts before any physics change. Then rerun the
same frozen origin and complete positive transfer, closure, reject/replay/restart
and preservation gates. Candidate/admission/closeout are blocked until then.
