# SWAP-020: bounded negative historical aggregate reference candidate

Status: locally qualified bounded correction; global B1 unchanged, SWAP5 admission pending.
Baseline canonical: `437d96ff51ac8a5825b605caf788661848c88be5`.
Owner: MC-NUT01, existing HIST-COMPLETE status record.

The programme owner's instruction to implement the proposed correction is
interpreted within the existing gross-aggregate convention selected on
20 October. The mathematical donor is the existing aggregated soil mineral
inventory: NH4 includes the original linear sorption capacity; NO3 is dissolved.
The correction does not interpret this donor as the concentration of ponded
runoff. It does not introduce a pond inventory or change hydraulic fluxes.

For each form, M = dz*(theta+rho*K)*C. The original pre-depletion equation is

`dM/dt = P - E - L*C`,

where P includes nonnegative volumetric production and positive bottom/lateral
loading, E is the magnitude of the negative prescribed top loading, and L is
the original outflow/root/first-order disappearance coefficient. Water content
varies linearly across the original interval, as in WaterN.

If the unconstrained trajectory reaches zero at tau before dt, C remains zero
after tau. Positive production/inflow continues; the realised extraction then
equals that continuing supply. The integrated extraction is

`E*tau + P*(dt-tau)`.

Unmet extraction is `(E-P)*(dt-tau)`. It is a diagnostic, never an extra input,
inventory, delayed liability or compensating nitrogen source. The concentration
average is the time integral to tau divided by the entire dt. The exhaustion
time is obtained from the analytical solution, independently of mass closure.

The first full-caller qualification is deliberately fallow, with nonnegative
mineral production and positive water capacity. Active-crop allocation among
competing sinks, immobilisation and near-degenerate coefficient thresholds are
not silently specified. Unsupported inputs fail explicitly. Positive top paths
and negative nondepleted cases keep the literal original equations/results.

This is a bounded correction of the existing aggregation convention, not a
claim of physical pond mixing. Actual runoff chemistry would require a separate
source-authorised control volume. B0 archives and published B1 snapshots remain
immutable. A qualified bounded patch does not itself create a new global B1 tag.

Affected invariants: 3, 7, 13, 21, 23, 25, 26, 30. Production, solver/runtime,
MC-SOL01 and PERF01 providers are read-only in this reference phase.

Selected feedback: independent constant-capacity analytical and variable-capacity
ODE comparisons, all five analytical classes, empty/depleted/ample donors,
NH4 sorption/NO3, ongoing supply and invalid inputs, GNU O0/O2. Then original
complete 63-provider main on the frozen control and ten-day fallow stress cases,
with unrounded form and total N books, original water preservation and O0/O2.
Expected original full-model cost under 120 seconds, per earlier measured work.
Full moving F-CI, RossFast and unrelated solute qualifications are not selected
because no production source changes in this phase.
