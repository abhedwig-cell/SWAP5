# RM29 — SWAP5–Ribasim management coupling transfer and ownership matrix

Status: **bounded closeout authority**

This matrix consolidates RM02–RM28. It does not create new physics or widen any admitted model envelope.

| Quantity / state | Physical or semantic owner | Trial / provisional authority | Accepted / persistent authority | External transfer booking | Qualification status |
|---|---|---|---|---|---|
| SWAP physical irrigation demand | SWAP management process | read-only derivation from immutable accepted origin | not stored as external mass; decision provenance persists through typed continuation | none | RM07 qualified |
| Ribasim management request | outer coupler materialization of SWAP demand | provisional at management boundary | request identity retained through typed realization provenance | none | RM10 qualified |
| Ribasim allocated water | Ribasim allocation | provisional management result | diagnostic/management result; **not** physical water mass | none | RM09/RM10 qualified in bounded full-realization profile |
| Physically supplied surface water | Ribasim physical UserDemand route | candidate transfer receipt | accepted only at outer transaction publication | Ribasim donor → SWAP gross irrigation receiver, exactly once | RM09/RM10 qualified in bounded profile |
| SWAP gross irrigation | SWAP application owner | candidate application forcing | accepted with same outer transaction | equal to accepted physical Ribasim supply before internal interception | RM06/RM09/RM10 |
| Rutter interception / canopy storage | SWAP | candidate internal transformation | persistent SWAP state | no second external transfer | RM06 and F-APP05/F-APP07 authority |
| SWAP net surface irrigation | SWAP application owner | candidate dynamic-top forcing | accepted only with hydrological candidate | internal result of gross transfer; not new external mass | application semantics qualified; active-irrigation temporal admission unresolved |
| SWAP irrigation continuation | SWAP typed TCS1/DCS2 process | candidate `dayfix` / active-event continuation | persistent committed state | none | RM05/RM06 qualified |
| Legacy `nirri` | legacy SWAP route only | not used by typed management owner | legacy persistent state only | none | RM05 ownership gate closed for typed route |
| Crop / DVS continuation | SWAP | immutable origin identity for current demand; candidate where process changes | persistent SWAP crop state | none | preserved by management contract; active root uptake outside first triangle |
| SWAP Richards soil-water state | SWAP | trial/candidate only | sole physical unsaturated-zone storage authority | surface irrigation and fixed-interface groundwater exchange affect this state | groundwater no-irrigation authority closed; active-irrigation temporal acceptance unresolved |
| Ribasim Basin / surface-water storage | Ribasim | isolated candidate process/state | Ribasim accepted state after outer publication | surface-water ledger only | real candidate replay/isolation qualified |
| Ribasim allocation clock | outer coupler owns scheduling; Ribasim owns solve semantics at boundary | next boundary is explicit scheduler state | next-boundary identity persists over restart | none | RM11/RM12 qualified for fixed allocation v2026.1.1 |
| Current forecast forcing | coupler / source process that owns the forcing | provisional, boundary-specific | does not overwrite accepted storage memory | none unless physically realized | RM01 frozen semantics |
| MODFLOW hydraulic head | MODFLOW6 under fixed-interface contract | XOLD remains accepted origin during prepared solve | accepted MODFLOW head state after publication | none by itself | canonical F-GC fixed-interface authority |
| SWAP–MODFLOW interface flux | fixed-interface coupling contract | trial equal-and-opposite transfer | accepted once after preflights | SWAP outward `q_swap` = MODFLOW API source; separate groundwater ledger | canonical admitted closed |
| MODFLOW STO | MODFLOW | numerical head-state capacitance | accepted head memory | **not** independent additive physical groundwater storage | canonical fixed-interface contract |
| Drainage | none in admitted first triangle | disabled | disabled | none | owner = NONE |
| Surface-water shortage | coupler / management diagnostic | provisional | diagnostic/output only | none | explicit request/allocation/supply separation qualified |
| Outer accepted coupled state | outer transaction owner | all model candidates + transfer receipts | published only after all bounded preflights | each physical transfer booked exactly once | management transaction qualified; full active-irrigation triangle not production-admitted |

## Transaction order

For the bounded management route:

`accepted SWAP state → read-only demand receipt → Ribasim request → allocation → physical supply → SWAP application candidate → outer acceptance`

For the fixed-interface groundwater route, the already admitted publication order remains:

`all preflights → finalize MODFLOW timestep once → commit SWAP once → commit groundwater ledger once`

A future production three-model publication boundary must compose these without changing either transfer owner.

## Hard non-double-booking rules

1. **Allocated water is not irrigation mass.**
2. Only measured/qualified **physical Ribasim supply** becomes an external SWAP irrigation transfer.
3. Rutter interception is an internal SWAP transformation and creates no second external inflow.
4. SWAP–MODFLOW groundwater exchange is a separate physical transfer and separate ledger.
5. MODFLOW STO is not added to SWAP storage as independent physical groundwater storage.
6. Rejected candidates own no accepted state and no accepted transfer mass.
7. Drainage remains disabled and unowned in this first composition profile.
