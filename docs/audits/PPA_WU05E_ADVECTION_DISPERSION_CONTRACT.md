# PPA-WU05-E joint mobile advection and dispersion

Status: proposed bounded process/runtime extension, not canonical admission.
Parent: `6206124c3390319126a560d08ea6e87992a53c0c`.

## Physical source and numerical choice

The exact B1.11 solute member SHA-256 is
`2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`.
Its lines 323-326 and 370-371 specify molecular diffusivity
`DDIF*theta_face**2.33/theta_sat_left**2` and mechanical dispersion
`LDIS_left*abs(q_face)/theta_face`. Positive-downward conservative
face conductance is consequently
`G=(DDIF*theta_face**3.33/theta_sat_left**2+LDIS_left*abs(q_face))/distance`.

This extension retains the existing dissolved upwind advection discretization
and adds this physical dispersive face transfer. B1.11 uses centered
advection and a timestep-dependent numerical dispersion correction. We do
not add that correction on top of upwind numerical diffusion. The physical
coefficients and balance are source-based; numerical equivalence must be
established under mesh/time refinement, not by byte-exact legacy replay.

The B1.11 `swap_base.f90` lines 497-502 define the left face weight as
`0.5*dz_right/disnod_face` and right weight as `0.5*dz_left/disnod_face`.
Both weights are supplied explicitly; no complement or normalization is inferred.
Runtime checks saturation, distance and both weights
against the matching hydraulic/grid owner. Geometry supplies explicit face distances, interpolation weights and
left-layer saturation. Water storage interpolates linearly between the exact
accepted Richards start/end states within each physical substep. Face water
fluxes, root extraction, per-level signed drainage and qssdi stay fixed at
that accepted substep's interval-mean rates. Internal solute steps recalculate
concentration from matching mass/water. The accepted root-water sink is never
recomputed by the salt process.

## Ownership and stability

Root salt removal is TSCF times the same root-water sink times the local
solute-substep start concentration. Positive drainage uses that local
concentration; negative drainage requires the typed prescribed Cdrain.
Qssdi retains its zero-solute contract. Boundary inflow uses the typed soil
interface concentration; outgoing salt uses its local donor. Dispersive
external boundaries are closed. Surface pools, aquifer breakthrough, sorption,
decomposition and macropores remain excluded.

One candidate carries the final mass. One independent salt receipt accumulates
boundary terms, per-node root salt and signed per-level drainage over all
internal solute steps. Any failure discards every candidate and receipt.
Internal face transfers are equal and opposite; no extra water sink exists.

Physical coefficients are immutable column parameters. Substep maximum,
positive cap and Courant fraction in (0,1] belong to numerical execution
policy. Use endpoint-minimum liquid capacity and endpoint-maximum face
conductance. The outgoing donor bound includes advection, dispersion,
TSCF-scaled roots and all positive drainage levels. Choose equal substeps no
larger than this bound or the caller maximum. Reject cap exhaustion before
returning any candidate; do not override the bound with a minimum step or
clip negative mass.

## Evidence required before runtime claim

Direct source-coefficient/sign and combined-transfer oracles; two-node
analytical diffusion relaxation; translating/spreading Gaussian mesh
refinement; uniform concentration under changing water with TSCF=1;
signed drainage, zero-solute irrigation, boundary reversal; atomic cap and
late-failure rejection; nonnegative mass and independent closure. O0/O2
process results must be deterministic. Runtime opt-in must additionally
survive actual bootstrap/dispatch, mixed root stress, accepted-only ledger,
discard/retry/commit, changed-forcing restart and existing disabled-route
preservation. The existing upwind route stays unchanged when the new physical
parameters are absent.

## Additional process stability gate

A 20-node, 365-day manufactured schedule varies water storage sinusoidally,
uses compensating zero-solute irrigation or root water extraction, switches
signed drainage daily, and varies the prescribed top concentration. Require
nonnegative mass and cumulative salt closure below 1e-11 mg/cm2. Halving the
maximum solute timestep from 0.25 to 0.125 day must change final column mass
by less than one percent. This is a process stress test, not a real Richards
seasonal production benchmark or validation against field observations.

## Extreme-range and root-uptake checks

At TSCF=10, the one-node drying oracle has exact mass
`M=M0*(V/V0)**10`. Timestep refinement must reduce the relative error,
with the finer result below two percent. No-drainage has zero levels, not
a fabricated drainage level. A separately tested drying trajectory with
unrepresentable CML must reject after its earlier internal steps and return
no candidate or accumulated receipt under floating-point traps.

Actual runtime qualification additionally covers prescribed top inflow
and outflow in both the backend and production bootstrap, with signed salt
receipts and independent closure. These are resolved soil-interface fluxes,
not a new precipitation/irrigation surface-pool owner.

## Top evaporation versus liquid export

B1.11 solute lines 347-358 book no top salt flux when water leaves upward
through the evaporative boundary. Runtime soil-interface forcing therefore
defaults `matrix_top_outflow_carries_solute` to false. Water loss concentrates
retained dissolved salt. An explicitly declared liquid-export interface uses
true and carries the donor concentration. This declaration belongs to physical
forcing, not numerical policy. Both the original matrix route and the new
subcycled route forward it. The generic standalone process default remains
liquid transfer for compatibility with its original control-volume contract.
Actual application/backend tests distinguish top input, evaporative water
loss with zero salt export, and declared liquid export. No atmospheric or
surface-pool mixing capability is implied.
