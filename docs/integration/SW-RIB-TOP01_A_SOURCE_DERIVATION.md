# SW-RIB-TOP01-A — legacy flooding source reconstruction

Date: 2026-10-01

Status: QUALIFIED_SOURCE_DERIVATION

Baseline:
`integration/f-ci-canonical@8bfff34e5bf06817f63a571282f70436cd90ede2`

Frozen SWAP 4.3.1 authority:

- archive SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`;
- `SWAP/boundtop.f90` SHA-256:
  `69d0d4703af64212d7200898f12568853d015cea29cb45f81915bece15b63c04`;
- `SWAP/surfacewater.f90` SHA-256:
  `d38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e`.

Prior exact-source authority:
F-PM08D and F-PM08D4.

## Reconstructed execution/mass contract

F-PM08D binds the legacy ordering as:

1. SurfaceWater task 2 resolves drainage/exchange before SoilWater;
2. SoilWater executes the top/soil-water trial and may alter runoff and rapid
   drainage;
3. SurfaceWater task 3 resolves/advances secondary surface-water state after
   SoilWater.

The secondary surface-water balance contains:

`S1-S0 = dt*(q_drain_secondary + q_rapid + q_supply - q_discharge) + RUNOTS`.

F-PM08D binds `RUNOTS` as a signed *amount*:

- positive = soil surface/runoff -> secondary surface water;
- negative = secondary surface water -> soil surface.

Thus top-surface exchange is not the EXTENDED_SIGNED drainage term and must
retain a separate transfer identity.

## Flooding physical interpretation

The legacy/theory authority attached to issue #589 states that flooding is
active only when the external surface-water level is above both:

- the ponding/runoff sill applicable to the field surface; and
- the current local ponding/groundwater surface level.

Under the legacy flooding concept there is no separate field-surface hydraulic
resistance. Active flooding imposes immediate hydraulic equilibrium between
the field ponding level and the external surface-water level.

Therefore the bounded modern physical representation is:

`h_surface = h_external_surface_water`

while flooding is active.

The soil-facing flux is then obtained from the normal top-boundary hydraulic
law evaluated with that imposed surface head. Flooding is **not** represented
as an independently prescribed additive infiltration flux.

## Branch classification

Let:

- `h_ext` = accepted external surface-water level in the SWAP surface-head
  datum;
- `h_sill` = field ponding/runoff sill;
- `h_local` = local candidate ponding/surface head before external flooding
  override.

Bounded flooding activation:

`h_ext > h_sill AND h_ext > h_local`.

Frozen equality policy for the first candidate:

- `h_ext == h_sill`: no flooding;
- `h_ext == h_local`: no flooding;
- strict exceedance of both is required.

This follows the documented "exceeds both" semantics. Any later source text
showing inclusive comparison would supersede this bounded reconstruction.

## Interaction with rainfall

Rainfall, irrigation, snowmelt and runon remain atmospheric/source terms.

When external flooding is inactive, current dynamic-top atmospheric/ponding/
runoff behavior remains authoritative.

When flooding is active, external head owns the surface hydraulic head for the
candidate. Atmospheric inputs still enter the interval water balance, but they
must not create a second independently imposed top flux.

## Transfer amount

The cross-model top transfer must be derived from the accepted interval surface
balance, not guessed from the soil-face Darcy flux alone, because simultaneous
atmospheric input and changes in local ponding can contribute to the same
surface control volume.

For the modern coupled contract define:

- `V_top_external > 0`: Ribasim -> SWAP top-surface transfer;
- `RUNOTS = -V_top_external`.

The exact candidate decomposition must close:

`delta(local surface storage) + soil-entry amount + evaporation amount
 = atmospheric/source amount + V_top_external - runoff-to-external amount`

under the active terms of the bounded dynamic-top profile.

A single net external top transfer may be published, but its sign and
components must remain diagnosable during qualification.

## Architectural consequence

The correct implementation seam is an external hydraulic view on the dynamic
top boundary, not a negative runoff forcing and not an extension of the
subsurface drainage-response law.

Required typed input is conceptually:

- external level available flag;
- external surface head in SWAP datum;
- flooding sill/connection elevation where not already represented by the
  existing ponding threshold;
- accepted-origin identity supplied by the runtime/coupler, not the solver.

No Ribasim type belongs in the solver request.

## Hypothesis decision

`DIRECT_EXTERNAL_HEAD_REPRESENTATION = SUPPORTED_FOR_BOUNDED_RESEARCH`.

The zero-field-resistance flooding hypothesis is not falsified by the recovered
source/theory authority.

What is *not* yet qualified is the exact modern candidate-transfer
decomposition under simultaneous rainfall/evaporation/ponding. That is the
next gate and must be solved before production admission.

## TOP01-B next gate

Extend the dynamic-top contract in research/test scope with a typed external
hydraulic view and derive/test the candidate top-transfer decomposition for:

1. below/equal/above activation seams;
2. dry and already-ponded local surface;
3. rainfall plus flooding;
4. runoff-to-flooding direction reversal;
5. exact interval surface mass closure.

Production source remains untouched until this decomposition is qualified.
