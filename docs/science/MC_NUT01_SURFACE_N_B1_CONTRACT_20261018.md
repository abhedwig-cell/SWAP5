# Corrected B1 surface nitrogen control volume

Status: accepted implementation direction from user18October2026; unqualified
candidate until all named gates complete. Baseline canonical101ff877d850311d7552fd852014b0ec65fde508.

The user authorized continuation with the recommended corrected physical route
after the original-source gross/net counterexample and alternative reference
choices were presented. B0 gross loading remains immutable historical evidence.
This B1 contract intentionally corrects delivery under ponding; it is not a
claim of full B0 hydrological equivalence.

## Ownership and process

Existing Soil-N inventory owns optional surface NH4-N and NO3-N amounts in
kg/m2. No second persistent owner or duplicated pond-water inventory. Richards
owns pond depth and accepted water fluxes. Disabled mode allocates no additional
inventory; its parameter identity, equations and native bytes remain exact.
A new default-false immutable mineral parameter enables corrected surface N.
Its identity marker distinguishes native reconstruction even when surface N=0.

Reuse existing initialize/advance_persistent_pond and its already admitted
pond-solute exchange kernel, as call-local scratch once per N species and
accepted hydraulic substep. Convert kg/m2 to mg/cm2 by100 and kg/m3 to mg/cm3
by1. Feed actual accepted gross rain, irrigation, runon, pond evaporation,
runoff depth, infiltration and initial/final pond depth. Concentrations for
these incoming water sources use the existing historical top NH4/NO3 values.
Distinct source chemistry is outside this initial contract. Snowmelt,
macropores, upward soil exfiltration and surface chemical reactions are excluded.
Evaporation exports no N. Complete evaporative emptying retains dry N and
rewetting remobilizes it. The incumbent1e-6cm/day infiltration cutoff and
implicit mixing order are inherited explicitly, not silently changed.

Surface mixing transfers only actual infiltrated N to the existing daily soil
transport/reaction kernel. Daily effective top concentrations preserve the
sum of accepted substep N transfers. This is an explicit daily coupling
approximation; it does not claim subdaily reactive timing equivalence.
Rainfall N enters the whole inventory once, surface-to-soil transfer is
internal, runoff N exits once. Existing crop uptake, emissions, leaching,
organic stocks, harvest, residues and fallow remain with their current owners.

## Atomicity, identity and persistence

A failed water, surface, soil chemistry or crop trial publishes neither water
nor any N inventory. General material transfers preserve surface N. Whole-N
inventory accounting includes surface N; no sidecar or balance-derived water.
Native mineral/reactive/crop codecs extend their existing parameter-identified
payload only in enabled mode. Default bytes remain exact. Opaque and native
restores must reject mismatched mode, missing/negative/nonfinite surface stocks,
truncation, replay and source identity drift before publication. Harvest and
successor reconstruction retain the entire Soil-N pool state.

## Selected gates

1. Small real owner O0/O2: dry retention/rewetting, simultaneous gross input
   and evaporation, mixing/runoff/infiltration, no-input preservation,
   original common pond mixing comparison, analytical N budget and rejected
   final substep rollback. Expected direct cost under1minute.
2. Corrected reactive owner with actual original chemistry; full N inventory
   and disabled/default preservation.
3. Actual Reference Richards/WOFOST81/Soil-N positive-pond days, accepted
   gross-source provenance, rejected chemical trial after successful water,
   opaque/native fresh-process restart with wet and dry surface N.
4. Physically continuous rotation with atmospheric sources, harvest/fallow/
   successor, year boundaries, O0/O2, transition restarts and rollback.
5. Requalify changed owner/codec surfaces: current retained, thermal, TCS6 and
   original zero-surface endpoints. Preserve parallel age/CI authority without
   broad source exemptions. No RossFast work or mastercoverage promotion.

Expected full owning qualification is tens of minutes; select dependency-first
local builds, retain failed attempts and reuse only byte-verified providers.
No full moving F-CI is selected merely by advancing a branch. Existing physical
and numerical tolerances stay hard.
