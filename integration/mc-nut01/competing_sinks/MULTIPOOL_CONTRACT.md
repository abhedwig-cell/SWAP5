# Proposed mineral-limited multi-pool organic kinetics

MC-NUT01 research successor to PR1430, baseline9be9a09b9c890a8240490d1f72a99c14c0cf72f8.
Implement multiple FOM pools, biomass and humus with the original constant
assimilation fractions and donor rates. Only NH4 supplies immobilisation.
Nitrate is retained unchanged. Uniform carbon fraction0.45; inventory depth
in[1e-6,100]m. No transport, crop/top sharing or reaction-rate feedback.

Proposed physical rule: mineralising donor pathways run at full activity.
All N-consuming donor pathways share one activity factor when NH4 is exhausted,
equal to the available release divided by their aggregate potential demand.
Classify biomass and humus pathways by their own stoichiometry, rather than
assuming biomass always mineralises. This generalises the one-FOM proposal;
it is not an accepted historical reference correction or production option.

Use positivity-preserving SSPRK2 with step doubling. Each Euler stage limits
consuming pathways by (NH4/h + positive release)/potential demand, capped at1.
The timestep caps donor loss to one quarter of its pool before receiving flows.
Convex RK combinations preserve positivity and linear N/C invariants. Accept
the two-half-step state; do not Richardson-extrapolate to negative pools.
Control all organic, NH4 and respired-C components with explicit atol/rtol.
Commit only after the real production pool owner and C budget both accept.
Invalid input or exhausted step budget returns the complete input candidate.
Finite stocks/rates up to100, intervals in[1e-6,100]days, N fractions up to1,
atol in[1e-14,1e-3] and rtol in[1e-12,1e-2] are the bounded arithmetic domain.
Reject a substep below1e-16*max(1,dt). Maximum500000 trial steps.

Selection before execution: fresh O0/O2 native production inventory/analytic
providers plus research module/driver. Compare one-pool cases with PR1430's
exact constrained solution, and multiple-pool cases with an independently
assembled event-driven DOP853 ODE. Include consuming humus, consuming biomass,
mineralising FOM, zero stock/release, unequal/equal/zero rates,1/10-day windows,
whole C/N balance and split-state continuation. Demonstrate tolerance refinement;
do not call continuation persisted restart. Preserve invalid rollback and
numerical corruption controls. Expected under60s initially; measure actual
native and oracle costs. No production or owning guard changes, so no new
Richards/HIST/FCI selection. Replay prior research, current canonical source
entry point and documentation/strict-build checks. All scope claims stay here.
