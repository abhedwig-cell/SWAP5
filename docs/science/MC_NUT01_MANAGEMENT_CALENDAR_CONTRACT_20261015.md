# Calendar-driven amendments in the existing senescence/water day

Work unit MC-NUT01-MANAGEMENT-CALENDAR. Baseline canonical
`3b661766dc59298a7f541c970c2d3a55602d926c`. One PR, owner MC-NUT01.

An immutable typed amendment schedule supplies dates, original kg/ha doses and
material definitions, including per-record ammonium volatilization. Dates lie on
the explicit origin's one-day grid. Preserve source order; do not sort. Use exact
kg/ha to kg/m2 conversion and the existing material chemistry. R2 qualifies the
historical same-date grouping defect separately; see its reference decision.
Calendar/date-string and .snm file parsing are not claimed by this typed route.

Select today's amendments with the historical `date+1` end-clock trigger and
pass the ordered batch into the existing daily senescence route: yesterday's
actual root/leaf/stem return, current scheduled amendments, actual water/crop/
reaction day, today's pending death. The existing accepted daily soil/water
clock provides exactly-once publication and rejects replay. The schedule is
external forcing, like next-day weather, not a mutable second event owner or
stored cursor. Restart callers provide it explicitly again. No hidden default,
queue, last forcing, duplicate N/water inventory or restart schema is introduced.

New thin day and actual Richards entrypoints call existing production owners.
Late invalid chemistry/crop/environment/water rejects the complete day and cannot
consume pending crop N or publish scheduled material. Failed schedule creation
does not publish a valid plan. Bounds cover before subtraction/products/allocation.
Empty dates preserve the underlying empty-batch route. Manual ordered identical
batches and scheduled days must have identical crop/soil/pending/water endpoints
and native restart bytes, including fresh-process continuation and retry/replay.

Affected invariants3/4/7/9/13/21/23/29/30: one physical owner, explicit immutable
forcing, atomic publication and complete restart. No existing process, state,
solver/tolerance, WOFOST81 equation/fixation or codec is changed. Harvest/reset/
rotation remains under the separate phase decision. Accepted heat coupling,
file/default activation, simultaneous solute companions and pond/source stay open;
aquifer stays rejected. No full capability/master count promotion.

Selection: literal original defect and exact one-line corrected B1 first at
O0/O2; tiny actual calendar process driver; actual crop/soil day and Richards
with original material/uptake/reaction oracles and explicit manual counterparts.
Audit any reused unchanged provider prefix against same-session source/compiler/
flags/object/module hashes; compile added providers and all drivers and execute
every native assertion fresh. Expected process1s, direct15s, joint150s from the
prior unit; measure all categories, per-physics UNKNOWN. Reuse immutable admitted
science only after complete dependency binding. Persist before expensive work.

At stable admission select one full local moving OFF, expected1616s, because the
new calendar-to-application publication route changes external physical forcing
under AGENTS/protocol four-level rule. No duplicate Actions/full run. Highest
low-air NOT_SELECTED_POLICY. Running/incomplete evidence is never PASS.
