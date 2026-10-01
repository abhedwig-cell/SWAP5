# A27 signed IC contact research contract

Status: PROPOSED_RESEARCH_ONLY
Canonical reconciled: 029453104b98d835790f2e09eb9e804aa3eaff4a
Owning branch: work/ppa-wu05-a27-rfm-performance-equivalence.
Production A26 composition, source/sink ABI, persistence and MB ownership remain unchanged.

This experiment tests one finite hydrostatic IC receiver with multiple representative contacts.
W is areic storage in cm; capacity and donor/receiver budgets are also cm.
phi=-bottom_depth+W/area; local macropore head is max(0,phi+contact_depth).
One accepted origin supplies all contact rates. Candidate receiver state is published only
by the experiment owner after successful Richards solve.

Branch selection, without double counting:
1. Matrix head >=0: signed Darcy amount 8*K*contact_thickness*(h_mp-h_matrix)*dt/L^2.
2. Matrix head <0 and macropore water reaches the representative contact:
   release is max(Philip amount, positive Darcy amount), matching the A22A max structure.
3. Both dry at the represented point: no exchange.
Positive amount means matrix gain; negative means matrix loss.
Philip amount = chi*4/L*S*(sqrt(age+dt)-sqrt(age))*contact_thickness.
No additive Philip+Darcy transfer. Current-contact S must tend to zero at saturation
to support continuity; a frozen nonzero history S may produce a jump and must be
screened explicitly. The new saturated reverse branch is a proposed extension,
not a literature-validated constitutive law.

Limit matrix losses to explicit available-water budgets and matrix gains to explicit
receipt budgets. Then limit aggregate IC filling to capacity-W and aggregate IC
release to W, both evaluated at the accepted origin. Cross-contact transfers cannot
borrow same-interval incoming water. No arbitrary signed residual correction.
Gain/loss arrays are areic transfers; Richards areic provider rates are amount/dt.
A volumetric provider would instead use amount/(dz*dt), but those two interfaces
must not be confused.

Research limitations: representative-point wetting, no partial wetted-contact
integration, no pore-entry hysteresis, no full event-age/history lifecycle,
no surface intake or MB routing. Matrix receipt budgets are caller owned and
must account for drainage-through-flow rather than assuming saturated matrices
cannot receive water. This does not supply a production recipe for those budgets.

Required local evidence: analytic signed Darcy and equilibrium oracles;
full/empty IC and matrix budgets; unsaturated max law; invalid-input fail-closed;
accepted-origin immutability/replay; O0/O2 preservation; deterministic 20000-case
screen; evolving Reference Richards comparison and timestep refinement.
Integration invariants affected in a future production change: internal water
ownership, signed source/sink dimensions, reject/retry and persistence.
This research changes none of those production interfaces.
