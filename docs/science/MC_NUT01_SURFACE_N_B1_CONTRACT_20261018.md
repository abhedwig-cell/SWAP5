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

## Existing proposal execution policy

The measured first strict pond day accepted1096 substeps after10693 attempts
and9597 temporal rejections. The already admitted default-off
`canonical_numerical_config_t%retain_accepted_step_proposal` may be selected in
the fixture. It retains every full/half and hard mass criterion, remains
restricted to external full/half mode, and proposes rather than accepts steps.
No solver/estimator body,4096 substep cap,1e-6 temporal tolerance or1e-10cm water
contract is relaxed. Compare scientific results and O0/O2/fresh restart under
this explicit existing policy; do not claim byte equivalence between different
proposal schedules. Existing source policy is unchanged and its admitted scope
is inherited; new physical composition still requires actual qualification.

## Stable accepted root-water reduction

Long pond traces exposed an accumulation defect: naive addition of thousands of
accepted root-water substeps can place a mathematically satisfied demand beyond
the existing eight-rounding-unit crop view envelope. It then invents tiny water
stress leaf death or rejects a ratio just above one. Material owners correctly
reject positive residue fragments below their existing1e-8kg/ha lower bound.
Do not relax that bound or the crop equality/mass contracts. In the explicit
new surface-N mode, reduce accepted root-water amounts with compensated summation
before passing the same physical integral to crop and Soil-N. Every term remains
the actual accepted trace term; no clipping, inventory loss or invented uptake.
Disabled mode retains its exact original addition order. Independent constant
flux traces of1000/2048/4096 accepted substeps test the existing crop envelope,
original disabled bytes and unchanged full water closure. Actual physical and
transition qualification remains mandatory after this changed provider.

## Confirmed implicit-mixing cancellation successor

The exact accepted field-loam trace (initially dry surface, original hydraulic
material) rejects the reactive day inside the existing shared pond-solute leaf,
not crop preparation. A two-provider replay reproduces the fifth trace entry at
both O0/O2: computed remaining mass -4.1359030627651384e-25mg/cm2 although end
water storage is exactly zero. The checked first-five-entry fixture and full
trace provenance are versioned. This is a cancellation defect in the existing
SWAP5 mixing arithmetic; the original SWAP4.3.1 evidence remains immutable.

For zero macropore area, the same implicit equation is
A=C*(V-q*dt+R), hence remaining storage is V*C. Only when the previous subtraction
rounds negative, use that algebraically identical storage expression. Existing
successful outputs retain their exact operations and bytes. Nonzero macropore
area remains unchanged, including rejection semantics; no parallel physics,
N owner, clipping tolerance or balance relaxation is introduced. The cutoff and
implicit mixing convention stay fixed. This narrow numerical correction does
not qualify complete evaporative age dry-down or other MC-SOL extensions.

The selected direct matrix compares20000 cases against the exact canonical
predecessor module compiled as a test reference, checks all previous successful
and macropore outputs bitwise and independently checks corrected storage/budget.
The complete accepted4874-entry day trace is also replayed through the real
persistent owner O0/O2. Actual field composition follows using one exact ABI-
compatible provider replacement for local feedback; all other checked provider
inputs/artifacts stay bound. Fresh full-closure compilation and all owning
scientific/preservation gates remain required before admission.

## Explicit resource-boundary successor experiment

The field-loam six-day prefix passed, but the first weekly 5 mm rain pulse
exhausted the fixture's 4096 committed-substep budget at day 7, t=369.71308113883816,
with 14 temporal rejections and zero solver rejections. Its largest accepted
water residual was 5.1633095585548738e-15 cm. This trial remains FAILED.
The next exploratory trial uses the existing canonical default resource budget
of 10000 (`mod_canonical_contracts`), rather than the fixture-specific 4096.
This explicitly supersedes the 4096-only experiment above; it changes no solver,
acceptance tolerance, retry budget, temporal estimator or mass gate. The interval
loop merely has room for additional fully accepted steps. This is not evidence
that the original negative-bottom-flux stress test was repaired, nor does an
eight-day exploratory result qualify the multiyear model. Estimated native cost
is several minutes for eight days; full rotation is conditional on this feedback.
