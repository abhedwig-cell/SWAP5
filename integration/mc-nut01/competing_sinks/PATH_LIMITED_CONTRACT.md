# Path-limited single-FOM proposal

Proposed research model, baseline9efc6d3ae532efcc7f6b0f6f8ebc29cdeabe3a14.
This is an executable successor to the PR1429 counterexample, within MC-NUT01
competing sinks. Production sources, interfaces and admissions do not change.
Invariants7 and13 apply to candidate rollback and whole C/N budgets.

Select a concrete physical assumption for investigation: while NH4 is positive,
use the original FOM and biomass kinetics. At zero NH4, slow only the consuming
FOM pathway; biomass mineralisation continues. Allocate that release to FOM
immobilisation. There are no crop, top, transport, nitrate or humus pathways.
This is not an adopted priority between competing sinks or a recovered legacy
identity. N fractions0.001/0.08 and assimilation0.5 fix the investigated model.
All C fractions are0.45, depth1m; no carbon-to-denitrification feedback is enabled.
The bounded interface accepts finite nonnegative pools/rates up to100 and
finite intervals in(0,100] days; it does not claim arbitrary-range arithmetic.

Let c=0.5*0.08-0.001=0.039. The boundary activity is
min(1,0.08*kB*B/(c*kF*F)). Thus the NH4 boundary is invariant, biomass may
continue turning over and the FOM pathway resumes fully when release catches
up with demand. At zero B or kB there is no release and the boundary stalls.
All pools remain nonnegative; organic plus NH4 N and organic plus respired C
are conserved. On rejection return the input pools and zero carbon flux.

Use the actual production analytic turnover and dissimilation for every free
segment. Locate the first depletion over the whole trajectory, including the
interior N-demand maximum when a full-day endpoint is mineralising. For this
two-pool topology demand has at most one positive maximum: B/F crosses the
demand/release ratio only in the direction of declining net demand. Bracket
the maximum and the first depletion separately. Integrate the constrained
boundary exactly, then resume production kinetics when the boundary releases.
Use the actual production pool owner to validate the final candidate.

Selection: native O0/O2,96 configurations with zero/positive NH4 and biomass,
zero/positive/equal-rate turnover and1/10-day windows. Compare each trajectory
to an independent event-driven DOP853 ODE, including depletion/exit times,
all endpoints, C/N budgets, and half-window state continuation. Include the
PR1429 hidden-depletion counterexample and invalid input rollback. Do not call
state continuation a disk-restart or Richards qualification. Expect under60s.
No new production callers exist, so broader HIST/FCI is not selected. Replay
the prior capsule and current owning source gate, docs and strict build.
Preserve the exact source-bound raw evidence, commands, failed runs and costs.
