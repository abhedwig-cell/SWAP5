# Daily amendment calendar recovery

MC-NUT01-MANAGEMENT-CALENDAR, [PR1242](https://github.com/abhedwig-cell/SWAP5/pull/1242).
Baseline canonical `3b661766dc59298a7f541c970c2d3a55602d926c` (PR1239).
Status: `integration/audits/MC_NUT01_MANAGEMENT_CALENDAR_STATUS.json`.
Contract: `MC_NUT01_MANAGEMENT_CALENDAR_CONTRACT_20261015.md`.
Reference decision: `MC_NUT01_CALENDAR_REFERENCE_DECISION_20261015.md`.

The immutable typed daily plan carries dates, original kg/ha doses and resolved
material definitions, including per-record volatilization. It rejects decreasing
dates rather than sorting. Same-day records preserve source order. A query uses
the original date+1 end-clock trigger on an exact daily grid. The current batch
is disposable forcing; the existing crop/soil and water clock prevents replay.
No separate cursor, event history, pending forcing, water/N inventory or restart
schema is introduced. Restart supplies the next forcing plan again explicitly.

Three additive modules select and forward amendments into the existing daily
senescence and actual Richards entrypoints. Yesterday's crop death returns before
scheduled amendments; today's actual root/leaf/stem death remains pending for
tomorrow. All water/crop/soil/pending state publishes atomically. Existing process,
state, codec, WOFOST81 equations/fixation and solver/tolerances remain unchanged.

R2 is a separately classified source correction, not an unexplained B0/B2 change.
Original management_soil grouping uses strict<0.d-3 after rejecting decreasing
dates. A same-date second record therefore remains behind the once-daily cursor
and blocks later dates. Exact original source blocks execute first at O0/O2 and
witness that failure. The one-line corrected B1 block uses<1.d-3, with the original
trigger and order unchanged. Every corrected daily record selection is compared
to the actual B2 driver output. Immutable archive/reference manifest is unchanged.
No claim is made for arbitrary fractional-time or unsorted calendar migration.

Fresh3/46/266-provider O0/O2 routes exercise tiny calendar construction/selection,
20 invalid cases and units; actual crop/soil; and actual Richards. Full original
material/reaction/uptake oracle blocks compare all8 organic pools, biomass/humus,
NH4/NO3 and actual crop supply at5C and30C. Both scheduled and explicit manual
trajectories execute freshly, including late failure/retry/replay, pending
senescence, whole N and native/opaque/fresh-process restart. Every complete
restart/endpoint byte matches between profiles and between optimizations.

A separate fresh native driver proves that a future-only schedule applies no
premature material: current crop, all soil pools, clocks and actual pending death
exactly equal the existing empty-batch day. Its unchanged same-session provider
objects/modules are hashed before and after; driver compilation/link/native are
fresh. No native PASS is reused. Primary build/driver/link/native costs are
132.780/13.869/.680/108.568s. Direct costs12.905/3.375/.166/.012s; extra no-event
driver1.113/.251/.005s. Per-physics and full-shell category split UNKNOWN.

Strict source/raw validation binds complete actual inputs/commands/compiler flags,
historical literals, reference transform, native stdout, counterparts and complete
restart payloads. Original138 controls execute at the exact admitted baseline;
current negatives reject foreign/partial/stale/failed/unchecked/corrupted evidence,
missing actual/manual/fresh execution and altered reference or endpoint bytes.
Owning CLIs delegate only after complete successor proof. Read status for actual
terminal gate state; native science alone is not full preservation or admission.

One stable full local moving OFF is selected under AGENTS/protocol because this
calendar-to-application path changes external physical forcing/publication.
Expected1616s from actual prior execution. Highest low-air NOT_SELECTED_POLICY;
no duplicate Actions/full run. Metadata-only closeout preserves exact execution
identity and all scientific inputs; no repeated full for recording its result.

Coverage receipt: `integration/audits/MC_NUT01_MANAGEMENT_CALENDAR_COVERAGE_20261015.json`.
No full capability/master disposition/count promotion. File/date-string parsing,
default activation and accepted heat/profile coupling remain open. Harvest/reset/
rotation retains its separate shared phase decision. Existing surface-input PR1234
is not duplicated; pond/source stays open and aquifer stays rejected. Final
expected-head merge and exact canonical source/tree receipt supply admission
authority; premerge admission=false is intentionally frozen.

Terminal full local moving preservation: **PASS**, OFF, exit0, 1676.707s; all6382 tracked inputs unchanged. Actual execution `47ad7871cf48937e17e1e20e9a57c13a1df633c1`, tree `2fa2bf8d33964afcdec3b5dee813d5af9955250f`, source `8cf09f7be1c21693b7e50c62c4e6b37ed3c71d28`. Raw logs, complete input inventory, Git bundle and183 controls are bound in the admission capsule identified by status. Fresh physical costs132.780s compile/13.869s driver/.680s link/108.568s native; extra no-event native identity1.113/.251/.005s with audited unchanged same-session provider build. Per-physics and full shell split UNKNOWN. Qualification/preservation true and admission false are deliberately frozen premerge; PR1242 merge and exact canonical receipt establish admission.
