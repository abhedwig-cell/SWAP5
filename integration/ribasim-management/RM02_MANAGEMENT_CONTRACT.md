# RM02 SWAP5–Ribasim management contract

## Scope

This contract defines the smallest management boundary needed for real SWAP5 to request irrigation from real Ribasim/RibaMod without conflating management decisions with physical water transfer. It is intentionally narrower than a general Ribasim allocation API.

The causal order is:

`accepted SWAP state -> physical irrigation demand -> Ribasim management request -> allocated water -> physically supplied water -> SWAP trial -> accepted SWAP state`.

No object in that chain may be silently substituted for another.

## Typed semantic objects

| Object | Meaning | Lifecycle |
|---|---|---|
| SWAP physical irrigation demand | Water that the accepted SWAP crop/hydrology/management state says would be requested at the management boundary | derived from accepted state; read-only for the management solve |
| Ribasim management request | Explicit quantity presented to the Ribasim UserDemand/allocation layer | provisional input for one allocation boundary |
| Allocated water | Management authorization/capacity returned by allocation | provisional management result; not yet physical mass |
| Physically supplied water | Water actually transferred from the surface-water route during the coupled physical window | trial until the whole coupled window is accepted |
| SWAP accepted irrigation | Physically supplied water that has passed interception/application physics and belongs to an accepted SWAP window | accepted physical transfer |
| Shortage | demand minus relevant supplied quantity under the chosen diagnostic convention | diagnostic only; never persistent hydrological state by itself |
| SWAP irrigation continuation | dayfix plus any active typed irrigation-event continuation required to reproduce the next decision | persistent accepted process state |
| Crop state | accepted crop owner state that determines DVS/emergence and accepted root/transpiration history used by irrigation triggering | persistent accepted process state |
| Rutter canopy storage | accepted canopy reservoir state used to convert gross sprinkler supply to net surface irrigation under SWINTER=3 | persistent accepted physical/process state |
| Ribasim surface-water state | Basin/network state owned by Ribasim | persistent accepted Ribasim state |
| Groundwater contribution | accepted SWAP–MODFLOW interface transfer and any separately represented Ribasim groundwater forecast quantity | physical transfer or forecast according to its explicit interface; never inferred from allocation |
| Forecast forcing | current-boundary forcing used by the Ribasim allocator | provisional read-only allocation input, distinct from accepted storage memory |
| Accepted coupled state | mutually consistent SWAP, Ribasim and, when active, MODFLOW states after one successful outer transaction | persistent |

## Ownership

SWAP owns its physical column, crop continuation, irrigation continuation and Rutter canopy storage. Ribasim owns surface-water storage and allocation state. MODFLOW owns regional groundwater head under the closed fixed-interface contract. The outer coupler owns transaction ordering, boundary scheduling and cross-model transfer receipts.

A physical surface-water-to-SWAP irrigation transfer has one transfer identity. Ribasim records the withdrawal from its donor side; SWAP records the corresponding gross supplied amount on its receiver side. Rutter interception is internal to SWAP application physics and must not create a second external irrigation inflow. Net irrigation is a downstream transformation of the same accepted gross transfer.

## Transaction rule

At a management boundary the coupler snapshots the accepted origins before creating any request or physical trial. Demand and allocation may be recomputed from that origin. Neither allocation nor a SWAP candidate commits state.

The outer transaction may commit only after:
1. the management boundary and request identity are fixed;
2. Ribasim allocation succeeds;
3. the physical supply route produces a bounded supplied quantity;
4. SWAP application/hydrology accepts the supplied quantity;
5. every participating physical-transfer ledger closes within its qualified tolerance;
6. all candidate origins still match the snapshotted accepted revisions.

A rejection discards every provisional allocation/application/physical candidate and restores the same accepted origins. A retry from the same accepted origin and identical external inputs must reproduce the same SWAP irrigation decision.

## Demand, allocation and supply

`allocated <= requested` is a management constraint, not proof of physical delivery. `supplied <= allocated` is the default bounded realization rule for the first real fixture. If the actual Ribasim route can physically curtail an allocation further, the measured physical transfer is authoritative and the difference remains a diagnostic realization shortfall.

SWAP must never book `allocated` as irrigation mass. Only physically supplied water can enter SWAP application physics. Likewise Ribasim allocation output must not be decremented twice when the physical transfer is later booked.

## Current-boundary groundwater and surface-water forcing

Accepted Ribasim storage memory and current forecast forcing are separate allocation inputs. The tested Ribasim release has direction-sensitive current forcing semantics. Positive groundwater drainage and negative infiltration cannot be normalized into one unsigned quantity. The coupler therefore transports sign, direction and semantic role explicitly.

No same-boundary retroactive management correction is inferred from a physical exchange that the Ribasim allocator did not observe at that boundary.

## Qualified real-Ribasim realization envelope

RM08 falsified the assumption that sufficient source supply plus a full allocation automatically implies full physical UserDemand realization. In that fixture, the accepted Basin source level lay inside Ribasim's physical source-level reduction band: allocation was 2.0 cm while measured physical supply was 1.6488994020651218 cm. The component water ledger still closed.

RM09 therefore qualifies a narrower first full-realization profile in which the relevant physical reduction mechanisms are inactive by construction. For the tested Ribasim v2026.1.1 route:

- allocated depth must equal the accepted SWAP request within 1e-6 cm;
- physically supplied depth must equal the accepted SWAP request within 1e-4 cm;
- the source-level margin must be at least three times `level_difference_threshold`;
- the physical low-storage factor must equal one within 1e-12.

RM10 encodes that envelope in an origin-bound realization receipt. The receipt binds the SWAP management lineage, revision, crop-origin revision, interval and requested quantity to an opaque coupler-owned Ribasim origin id/revision while retaining allocated and physically supplied quantities as separate fields. Cross-origin mixing and RM08-like partial realization fail closed for this first profile.

These bounds are admission conditions, not a claim that partial realization is physically invalid. A future partial-supply policy requires its own preregistered transaction and hydrological response contract.

## Initial admitted profile

The first real SWAP–Ribasim fixture is one SWAP column, one surface-water supply route, one irrigation demand, no drainage and aligned management/coupling clocks. RM09 qualifies that fixture only inside the bounded full-realization envelope above. RM11/RM12 additionally qualify explicit coupler-owned fixed-allocation scheduling for one noncommensurate clock case. The first three-model fixture adds one MODFLOW cell using the bounded canonical fixed-interface groundwater contract and still keeps drainage disabled.

## Nonclaims

This contract does not claim full Ribasim optimizer equivalence, arbitrary competing demands, active SWAP drainage composition, generic MODFLOW storage ownership, dynamic allocation-policy switching, or a general all-process SWAP restart format.
