# SW-RIB-TOP01-B — external top-transfer mass decomposition

Date: 2026-10-01

Status: QUALIFIED_DESIGN_RESULT

Baseline:
`integration/f-ci-canonical@8bfff34e5bf06817f63a571282f70436cd90ede2`

Parent:
`SW-RIB-TOP01-A`.

## Current dynamic-top sign convention

The current dynamic-top provider computes

`q0 = P + I + M + R - E_soil - E_pond`

and uses the soil-water solver convention in which the returned
`actual_top_flux` is the soil-facing boundary flux.

The current provider separately returns:

- candidate local ponding depth;
- runoff depth over the interval;
- evaporation terms;
- net potential surface forcing.

These are sufficient to formulate a surface control-volume residual without
introducing a second physical store.

## Control volume

For one interval of duration `dt`, define positive amounts into the local
field-surface control volume:

- `A = dt*(P + I + M + R)`;
- `X = V_external_top`, positive Ribasim -> field surface;
- `S0`, `S1` = previous and candidate local ponding storage depths.

Define positive amounts out:

- `E = dt*(E_soil + E_pond)`;
- `D = V_soil_entry`, positive field surface -> soil;
- `O = V_runoff_external`, positive field surface -> external surface water.

Then exact surface closure is:

`S1 - S0 = A + X - E - D - O`.

Therefore:

`X = (S1-S0) - A + E + D + O`.

This is the candidate Ribasim -> SWAP top transfer.

The legacy secondary-water sign is:

`RUNOTS = O - X`.

When only one net external top transfer is exposed:

`V_external_net = X - O = (S1-S0) - A + E + D`

and:

`RUNOTS = -V_external_net`.

## Critical consequence

The external transfer cannot in general be inferred from the Darcy soil flux
alone.

For example, during active flooding with rainfall:

- rainfall contributes to soil entry and/or ponding;
- only the residual water needed to maintain the externally imposed surface
  head belongs to Ribasim.

Charging the full soil-entry flux to Ribasim would double-count rainfall.

Likewise, during evaporation from an externally maintained flooded surface,
Ribasim may need to supply water that never enters the soil.

## Soil-entry sign binding

Before production implementation, the adapter/runtime must bind the solver's
`actual_top_flux` sign to `D` explicitly from the admitted soil-water mass
contract. TOP01 does not guess this sign from variable names.

The design equation above is invariant once `D` is expressed as a positive
surface-to-soil amount.

## Active flooding state

When:

`h_ext > h_sill AND h_ext > h_local`

the candidate local surface head/storage is externally constrained:

`S1 = h_ext`

for the bounded zero-resistance datum/profile, after the required datum mapping.

The top-boundary solver computes the soil-facing flux at that head.

The external transfer is then diagnosed from the surface control-volume
equation. It is not supplied as a forcing to the soil solver.

## Inactive state

When flooding is inactive, existing dynamic-top behavior remains authoritative.

For ordinary runoff, `X=0` and `O` is the existing runoff amount.

For an external-Ribasim profile the accepted runoff amount can later be
published as the opposite direction of the same top-surface interface family,
but this does not require changing current runoff physics in TOP01-B.

## Direction switch

The interface can be represented by one signed net amount:

- positive: Ribasim -> SWAP surface;
- zero: no net cross-model top transfer;
- negative: SWAP surface -> Ribasim.

However qualification diagnostics must retain enough decomposition to
distinguish rainfall, evaporation, soil entry and local ponding change. A net
number alone is insufficient evidence for mass attribution.

## Equality seams

Physical flooding activation remains strict:

- `h_ext == h_sill`: inactive;
- `h_ext == h_local`: inactive.

No tolerance changes the physical inequality.

A solver may use a separately named numerical comparison guard only to avoid
unstable route switching at machine precision. Such a guard may return
unavailable/retry but may not silently turn equality into flooding.

## Simultaneous subsurface exchange

TOP01 and F-APP09 transfers remain distinct:

`V_total_Ribasim_to_SWAP = V_external_top + V_subsurface`

only at the coupler ledger/composition layer.

They must not be collapsed before process-level diagnostics because they have
different constitutive origins and may have opposite signs in the same
interval.

## Decision on implementation seam

A direct modification of only
`mod_b110_dynamic_top_boundary_provider.f90` is **not sufficient** for a
production candidate.

Reason: the provider can impose/evaluate the hydraulic head, but the
cross-model transfer requires accepted interval information spanning:

- previous local ponding;
- candidate local ponding;
- atmospheric/source amounts;
- evaporation;
- accepted soil-entry amount;
- runoff amount.

Therefore TOP01 requires two bounded components:

1. **hydraulic-view extension** at the dynamic top boundary;
2. **surface control-volume transfer materializer** outside the solver that
   derives the candidate signed external transfer from the completed trial.

This preserves solver/process separation and avoids making the top-boundary
provider a second mass ledger.

## Research qualification cases

Algebraic expected outcomes:

1. no external flooding, no runoff: external net transfer = 0;
2. no external flooding with runoff O: external net transfer = -O;
3. flooding, no atmosphere/evaporation, fixed S1: external transfer supplies
   ponding increase plus soil entry;
4. flooding + rainfall: rainfall offsets Ribasim supply one-for-one until the
   required external transfer reaches zero;
5. flooding + evaporation: evaporation increases required Ribasim supply;
6. flooding over already equal/higher local ponding: activation false under
   the strict branch, preventing artificial reverse transfer;
7. direction reversal is continuous in the mass equation even though the
   physical route classifier has a branch seam.

## Decision

Classification:

`QUALIFIED_TWO_COMPONENT_TOP_INUNDATION_DESIGN`.

A production candidate is not yet authorized. The next safe work unit is
TOP01-C: implement and independently test a pure surface-control-volume
materializer plus a research-only external-head dynamic-top view. Only after
their mass/sign/equality tests pass should the production solver contract be
changed.
