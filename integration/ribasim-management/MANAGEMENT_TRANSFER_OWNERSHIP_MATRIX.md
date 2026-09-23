# SWAP5–Ribasim–MODFLOW transfer and ownership matrix

Status: management authority qualified through RM12; first three-model composition RM13 pending qualification.

| Physical or management object | Producer / owner | Receiver / consumer | Trial or accepted semantics | Ledger / provenance authority | Current authority |
|---|---|---|---|---|---|
| SWAP irrigation demand | SWAP typed irrigation/crop-management state | outer coupler, then Ribasim UserDemand | read-only derivation from accepted SWAP management origin | RM07 receipt binds SWAP lineage, revision, crop-origin revision and interval | QUALIFIED RM07 |
| Ribasim management request | outer coupler mapping of the RM07 demand receipt | Ribasim allocation layer | provisional input at one explicit management boundary | demand receipt identity must remain unchanged through allocation | QUALIFIED RM07/RM10 |
| Allocated surface water | Ribasim allocation | outer coupler | management authorization only, never physical SWAP mass | separate field in RM10 realization receipt | QUALIFIED RM09/RM10 in bounded full-realization profile |
| Physically supplied surface water | Ribasim physical UserDemand route | SWAP irrigation application | provisional until outer transaction acceptance | RM10 realization receipt; Ribasim cumulative physical UserDemand transfer is authoritative | QUALIFIED RM09/RM10 in bounded full-realization profile |
| Gross SWAP sprinkler input | same physical transfer as Ribasim supplied water | SWAP application/Rutter | trial until SWAP candidate acceptance | must equal accepted physical Ribasim supply; never duplicate allocation as mass | QUALIFIED RM06/RM09/RM10 |
| Rutter interception | SWAP application process | SWAP canopy storage / net surface input | internal SWAP transformation | not a second external transfer | QUALIFIED RM06 |
| Net SWAP surface irrigation | SWAP application after interception | Richards top boundary | trial until hydrological acceptance | derived from the same gross transfer identity | MANAGEMENT QUALIFIED; real Richards composition pending RM13 |
| Ribasim accepted surface-water storage | Ribasim | next management boundary | persistent only after outer acceptance | Ribasim accepted state; current forcing remains distinct | product semantics frozen RM01; real bounded replay RM09 |
| MODFLOW fixed-interface head | MODFLOW | SWAP lower fixed coupling plane | accepted groundwater state; trial values remain solver/coupling-local | closed F-GC fixed-interface contract | CANONICAL_ADMITTED_CLOSED |
| SWAP outward lower-interface flux | real Richards SWAP | MODFLOW API source | trial during correctors; accepted once after coupled convergence | F-GC groundwater ledger, positive outward from SWAP | CANONICAL_ADMITTED_CLOSED |
| MODFLOW API groundwater source | outer groundwater service from SWAP interface flux | MODFLOW cell | equal physical transfer with groundwater sign convention | q_api_source = q_swap; opposite groundwater-out counterpart | CANONICAL_ADMITTED_CLOSED |
| Groundwater interface exchange ledger | outer groundwater coupling ledger | accounting/publication boundary | one prepared transfer, one commit after all preflights | F-GC fixed-interface ledger | CANONICAL_ADMITTED_CLOSED |
| Drainage | none in first combined profile | none | disabled | duplicate or unresolved ownership fails closed | OWNER=NONE canonical authority |
| Management boundary schedule | outer coupler | SWAP/Ribasim/MODFLOW orchestration | persistent scheduler state at accepted boundaries | RM11 restart state; RM12 exact-release Ribasim execution | QUALIFIED RM11/RM12 |
| Three-model outer acceptance | outer coupler | all accepted model states and ledgers | all candidates preflight before ordered publication | MODFLOW -> Richards SWAP -> GW ledger -> management SWAP -> accepted Ribasim candidate in RM13 fixture | PENDING RM13 |

## One-transfer-one-owner rules

1. Ribasim allocation is never booked as irrigation mass.
2. Ribasim physical UserDemand delivery and SWAP gross irrigation are donor and receiver views of one surface-water transfer.
3. Rutter interception and net irrigation are internal transformations of that same transfer, not additional external mass.
4. SWAP–MODFLOW lower-interface exchange is a separate physical transfer with its own equal-and-opposite groundwater counterpart and ledger.
5. Drainage is absent from the first combined profile. No SWAP, MODFLOW or Ribasim drainage route may appear implicitly.
6. Coupler ledgers own accounting and publication provenance, never physical process physics.
7. Rejected candidates have no accepted-state or mass authority.

## Bounded nonclaims

This matrix does not admit partial irrigation realization, active drainage, arbitrary Ribasim competition, adaptive allocation scheduling, root uptake in the groundwater-coupled triangle, field-scale MODFLOW storage interpretation, or a production iMOD Coupler driver.
