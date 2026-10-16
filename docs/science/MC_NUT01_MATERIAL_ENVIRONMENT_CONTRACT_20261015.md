# Simultaneous daily material and prescribed soil temperature

Proposed MC-NUT01-MATERIAL-ENVIRONMENT on canonical
`fb311dabd16266409deb394c381fe26086a64d03` (material PR1237).

The existing material day and real Richards material application accept an
optional `soil_n_day_environment_t` as their final argument. Forward it without
reinterpretation to the admitted soil/crop day and joint application. The same
interval temperature therefore drives both organic and mineral reaction rates
after the original ordered material batch has entered the existing inventory.
The argument is call-local forcing, with the exact admitted interval/temperature
validation. No changes to rate formulas, material chemistry, parameter identity,
WOFOST81 fixation, accepted moisture, soil/crop/water storage, clocks or codecs.
An absent optional argument continues to mean the original absent profile.

Materials are staged on copies; an invalid/stale/disabled temperature forcing,
material, water or crop day cannot publish any of the three owners. A successful
retry starts at the original committed authority. The complete pre-material to
post-day whole-N budget and all existing water/soil/crop gates remain hard.
After complete restart, the caller supplies the next material batch and explicit
temperature just as it supplies the next weather interval. No forcing is persisted
and no old temperature is reused implicitly. Empty batches with explicit forcing
must equal the existing explicitly forced non-material route byte-for-byte.

This is a composition of admitted prescribed temperature and external material
forcing. Automatic crop residue debit/return, calendar/file policy, accepted heat
coupling, default activation, pond/source and aquifer remain outside this unit.
Aquifer remains rejected. The historical calendar discrepancy and original
MC-NUT01-R1 correction retain their existing authorities.

Affected invariants3/4/7/9/13/21/23/29/30: two additive optional API arguments,
call-local forcing, sole existing inventory and atomic accepted publication.
No generic kernel restriction is added; the existing daily crop process owns
this one-day interval requirement.

Qualification: small real42-provider crop/soil drivers first at O0/O2, then real
260-provider Richards composition. Original material drivers rerun fresh and
retain every prior persistent endpoint byte. Explicit5C then30C days compare
all eight FOM pools, biomass/humus, NH4/NO3 and crop supply with the unchanged
full historical material, organic, rate, water and uptake routines. Include
invalid/stale forcing, nonmutation, A/B/A, late material/crop/water failure,
retry/replay, empty forced-route identity and opaque/fresh-process continuation.
Existing19 native decoder rejection controls execute for both profiles at both
optimizations. Bounds and invalid/zero/overflow traps remain enabled.
Expected direct build15s; joint build130s plus80s native, based on1236/1237.
Measure compile/driver/link/native and retain failed attempts; physics-only time
is UNKNOWN. Original peer qualifications remain pinned to their actual inputs.

Select one full local moving OFF at stable admission under the existing AGENTS
four-level boundary, because the accepted material API and its composition change.
Expected1650s; full compile/link/native split UNKNOWN. Persist before execution,
inspect existing runs, do not dispatch duplicate Actions. Highest low-air remains
NOT_SELECTED_POLICY. No full-capability or master-disposition promotion.
