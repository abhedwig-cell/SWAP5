# Daily WOFOST81 senescence, delayed incorporation and complete restart

Proposed MC-NUT01-SENESCENCE-CYCLE on canonical
`e22a677146ef49d14bd6dd6e72b78f60e340bcab` (PR1238).

Source authority is the existing B1.11 archive. Exact swap.f90 SHA256
39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a
lines480..494 orders SoilManagement2, yesterday's residues5, current amendments3,
then growth and nutrient reactions. management_soil.f90 SHA256
0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b
lines583..624 maps root/leaf/stem/storage dry matter and N to the original
residue routine. Current WOFOST81 exposes daily root, leaf and stem death and
N loss; it has no daily storage-organ senescence. Preserve WOFOST81 equations,
fixation and existing crop supply, rather than importing the old crop owner.

The new explicit profile consumes yesterday's root/leaf/stem material first,
then current external materials, executes the existing actual day, and stores
that day's actual crop death as pending physical material for the next day.
The existing private crop/soil owner holds only necessary unincorporated dry
matter, N and application ages plus its matching accepted clock. There is no
second mineral/organic inventory, cumulative residue history or event cursor.
Crop growth/N already debit death once. Its cumulative N-loss ledger remains a
crop-boundary diagnostic; global soil+live-crop+pending N counts these transfers
as internal, never as new external input or crop loss out of the whole system.
No same-day decomposition of today's newly dead crop material is introduced.

Application ages are explicit organ properties; retain them with each pending
batch so a later policy change cannot reinterpret yesterday's material. Use
original kg/ha to kg/m2 conversion, OM fraction1, N fraction death-N/death-DM,
zero mineral fractions and original residue chemistry. Reject unsupported
nonzero subthreshold material instead of silently discarding N. The literal
management threshold is strict >1e-8kg/ha; the residue routine threshold is
>=1e-12kg/m2. Zero dry matter requires exactly zero N. No guessed material-age,
N-rich/N-poor clamp or correction to the historical routines is admitted.

All accepted water, soil/crop and pending material publish together. Original
non-residue day routes reject a nonempty pending state instead of losing it.
The ordinary material staging operation preserves pending metadata. A failed
batch, water/carrier/crop/reaction/return, stale forcing, retry or replay cannot
consume pending mass or publish any other owner. Existing daily clock/revision
provides exactly-once consumption. The external material and optional daily
prescribed-temperature profiles remain composable.

Opaque restart already owns the complete private crop/soil value. Native restart
uses original S5NC0001 bytes when no pending material exists, with unchanged old
endpoints and decoder assertions. A tagged S5NC0002 profile adds exactly ten
real64 values (clock,3 dry matter,3 N,3 ages) before the existing whole-file CRC.
Read both versions. Require finite/bounded pending values, matching accepted
clock, no orphan N, bounded cumulative crop N-loss and valid actual incorporation
on decoded copies before atomic publication. No initialized target is overwritten.
Do not silently accept a legacy continuation that cannot retain pending material.

Affected invariants3/4/7/9/13/21/23/29/30: required compact persistent dead material,
source-order daily orchestration, one inventory and atomic complete restart.
No solver, tolerance, rate formula or WOFOST81 parameter/configuration change.
The actual harvest/reset/fallow/new-season phase contract in
MC_CROP01_HARVEST_ROTATION_PHASE_DECISION.md remains unresolved; no physical
harvest, storage-organ harvest return or crop lifecycle is claimed here.
Pond/source stays open; aquifer stays rejected.

Qualification selects a tiny real producer/conversion contract with literal
management mapping and original residue routine; a small real crop/soil driver;
then actual Richards at fresh O0/O2 with checked bounds/FP traps. Compare delayed
whole-N and all8 organic pools, humus/biomass, NH4/NO3 and crop supply to original
material/rate/water/uptake routines. Exercise leaf ageing and root/stem death,
zero/invalid/tiny pending material, changed next-day policy, forcing nonmutation,
late rollback and retry/replay, old-route refusal, original profile endpoint
identity, pending opaque/native fresh-process continuation and corrupt pending
payload rejection. Rerun all original material/temperature native assertions
because private owner layout and native codec change. Independent process closure
about3 providers, direct44, full263; expected small20s, physical build150s plus
130s native. Measure costs and retain failed attempts; physics-only UNKNOWN.

Persist before expensive execution. At the stable admission boundary select one
complete local moving OFF, expected1780s, under AGENTS and the protocol four-level
rule for changed state/restart and daily application. All scientific assertions
and baseline source authority remain intact. Highest low-air NOT_SELECTED_POLICY;
no duplicate Actions or full run. No full capability/master disposition promotion.
