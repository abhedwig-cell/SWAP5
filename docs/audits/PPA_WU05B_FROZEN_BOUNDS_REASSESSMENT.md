# FrozenBounds source reassessment

Source: `reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90`.
This is reconstruction and a proposed bounded follow-up, not an admission.

## Actual legacy rules

`FrozenCond` computes hydraulic factors from TFROSTSTA/TFROSTEND, then searches
for the deepest node at or below TFROSTEND + 1e-6 C. The search decrements before
examining a node, so it excludes the last node. It interpolates a bottom depth
between the selected node and its successor and a top depth against the preceding
node or the prescribed surface temperature. This temperature geometry is distinct
from the root cutoff at 0 C.

`FrozenBounds` starts from the unmodified bottom flux. Available air is the sum
of max(theta_sat - theta, 0) * dz from the bottom upward; traversal stops when the
preceding node has a hydraulic frost factor <= 0.01. With no drainage, it sets the
bottom flux to zero only if deepest-frost-node > 1 and air volume < 0.01 cm.
Both inflow and outflow are suppressed by that empirical rule.

With drainage, the same low-air condition can zero drain levels above the frost
bottom, redistribute bottom discharge into remaining drain totals, and call the
legacy redistribution routine. Outside that condition, every node drain flux is
scaled by its hydraulic frost factor and level totals are recomputed.

## Hazards requiring explicit decisions

- A frozen final node alone is omitted from the legacy geometry search. Uniformly
  frozen adjacent nodes can give a zero interpolation denominator. The 1e-6 C
  geometry offset can select a node without a strict threshold bracket.
- The deepest drain level begins at index zero; absent or nonnegative drain-depth
  configurations can leave that invalid index unchanged.
- Low-air redistribution edits level totals separately from node fluxes. A direct
  transplant can make level totals disagree with the actual water sink owner.
- Moving a bottom flux into drain totals changes boundary ownership and can count
  one exchange twice unless one final flux composition owns both outputs.
- Saved frost depths and nodal factors are worker history. A typed replacement
  must recompute them from trial-start physical state and restore rejected trials.

These are specific migration hazards, not a blanket assertion that the original
empirical model is scientifically invalid. Reproducing source behavior and changing
its apparent defects are separate contracts and must use independent oracles.

## Proposed next bounded unit

Start with the no-drain available-air bottom-flux rule, as an explicitly selected
legacy compatibility policy on prescribed-qbot Reference columns. Inputs must be
immutable trial-start temperature, water content, saturation, thickness, hydraulic
frost factors and the unmodified boundary proposal. A pure selector produces one
final bottom proposal, consumed once by the existing bottom boundary and mass
ledger; it adds no committed frost state. Admission must cover positive/negative
qbot, air-volume equality at 0.01 cm, factor equality at 0.01, deepest-node cutoff,
fully frozen/mixed/thawed profiles, exact OFF preservation, retry/direct refinement,
restart and actual accepted bottom publication.

The geometry omission and denominator hazards must be resolved explicitly before
implementation. Drainage redistribution, changing drain ownership, latent heat
and ice inventory remain separate work. No solver or ledger is changed by this
audit, and FrozenBounds remains unadmitted.
