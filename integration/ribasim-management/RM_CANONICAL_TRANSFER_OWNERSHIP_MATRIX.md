# SWAP5–Ribasim management coupling bounded canonical ownership matrix

Status: **governance closeout only**. This file records bounded authorities and does not admit the active-irrigation three-model production triangle.

| Object | Owner | Accepted meaning | External mass booking | Authority |
|---|---|---|---|---|
| SWAP irrigation demand | SWAP typed management process | Read-only demand from accepted SWAP origin | none | qualified |
| Ribasim management request | outer coupler | Provisional request at explicit management boundary | none | qualified |
| Ribasim allocated water | Ribasim allocation | Management authorization, not physical water | none | qualified bounded |
| Ribasim physically supplied water | Ribasim physical UserDemand route | Physical surface-water donor quantity | exactly once as donor side of surface-water transfer | qualified bounded |
| SWAP gross irrigation | SWAP application owner | Receiver view of the same physical supply | exactly once as receiver side of surface-water transfer | qualified bounded |
| Rutter interception | SWAP | Internal transformation and canopy storage | no second external transfer | qualified |
| SWAP net surface irrigation | SWAP application owner | Richards top-boundary forcing derived from gross irrigation | internal transformation of the same surface-water transfer | application semantics qualified; active-irrigation temporal production admission blocked |
| SWAP irrigation continuation | SWAP typed TCS1/DCS2 state | Persistent accepted management continuation | none | qualified |
| Ribasim Basin storage | Ribasim | Persistent accepted surface-water memory | surface-water ledger only | qualified bounded |
| Allocation clock | outer coupler | Explicit fixed-allocation boundary schedule with restart state | none | qualified for Ribasim v2026.1.1 |
| MODFLOW head | MODFLOW6 | Accepted fixed-interface groundwater state | none | canonical admitted |
| SWAP–MODFLOW interface flux | fixed-interface coupling contract | One equal-and-opposite groundwater transfer | separate groundwater ledger | canonical admitted |
| MODFLOW STO | MODFLOW6 | Head-state capacitance only | not an extra physical groundwater store | canonical admitted |
| Drainage | none in first combined profile | disabled | none | owner NONE |

## Hard rules

1. Allocation is never booked as irrigation mass.
2. Only qualified physical Ribasim supply becomes external SWAP irrigation.
3. Rutter interception is internal to SWAP and creates no second inflow.
4. SWAP–MODFLOW exchange is a separate physical transfer with its own ledger.
5. Rejected candidates have no accepted-state or accepted-mass authority.
6. Drainage remains disabled and unowned in this first combined profile.

## Production blocker

The remaining blocker is not mass conservation or ownership. It is independent temporal-fidelity authority for active irrigation. Repository evidence characterizes the numerical effect, but no post-hoc threshold may be chosen from that evidence to manufacture a pass.
