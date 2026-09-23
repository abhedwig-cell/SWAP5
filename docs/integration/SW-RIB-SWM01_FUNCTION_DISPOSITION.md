# SW-RIB-SWM01 functional disposition matrix

**Date:** 2026-09-23  
**Status:** research disposition, not production admission or retirement authority  
**Canonical base:** `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`

This matrix is the compact architecture outcome of the exact-source F-PM08D reconciliation and the current SWAP5/Ribasim authority review.

| Legacy responsibility | Exact legacy meaning | Standalone SWAP5 | Ribasim-coupled target owner | Status / gate |
| --- | --- | --- | --- | --- |
| `SWST` | Conserved secondary surface-water storage for `SWSEC=2` | Retained in restricted F-CI52 fixed-weir profile | **Ribasim Basin** | Q1A physical external-owner test |
| `WLS` in simulated mode | Level derived from `SWST` | SWAP5 F-CI52 derived state | **Ribasim Basin level**, exposed to SWAP as exchange forcing/view | Q1A |
| `WLS` in prescribed mode | Secondary level forcing | External forcing | Ribasim Basin/Boundary state or explicit forcing adapter | Mapping only, no duplicate state |
| `WLP` | Primary-water-level forcing used by exchange law | External forcing | Ribasim primary-network state/boundary view | Must remain distinct from secondary storage |
| `STTAB` | Secondary open-channel storage-level geometry | Retained where F-CI52 profile requires its admitted equivalent | Ribasim Basin profile, from governed shared geometry | Physical provenance mapping required |
| Extended drainage/infiltration law | Signed soil/watercourse exchange response | SWAP process physics | **SWAP** | Retain; external state supplied through coupling view |
| Multi-level drainage geometry/resistances | Soil/drain response parameters | SWAP | **SWAP** | Retain |
| Legacy availability limiter | Limits negative exchange from projected `SWST` plus `WSCAP` | Internal only where surface-water store is SWAP-owned | **Coupling feasibility**, using Ribasim-owned storage/supply availability | Q3 |
| Positive drainage bookkeeping | Soil to internal SWAP surface store | Internal transfer in F-CI52 combined system | **SWAP -> Ribasim interface transfer** | Q3 mass reclassification |
| Negative drainage/infiltration bookkeeping | Surface store to soil | Outside current F-CI52 restricted production envelope | **Ribasim -> SWAP interface transfer** | Q3; must be availability-safe |
| Rapid drainage/interflow delivery | Soil-generated contribution to surface water | SWAP generation, internal/external according to profile | **SWAP generation -> Ribasim transfer** | Later mapped-process qualification |
| Runoff/top surface exchange | Soil/surface process contribution | SWAP generation | **SWAP generation -> Ribasim transfer** when represented in Ribasim | Later mapped-process qualification |
| `SWQHR=1`, `ALPHAW/BETAW/HBWEIR` | Analytic power-law fixed-weir Q(h) | Retained in F-CI52 restricted profile | **Ribasim explicit controlled discharge** for exact hard-kink mapping; native TabulatedRatingCurve only under an approximation envelope | Q1A-R3/R3L pass for `BETAW=1`; nonlinear Q1C open |
| `SWQHR=2`, `HHTAB/QHTAB` | Tabular Q(h) relation | Not in restricted F-CI52 admission | Ribasim TabulatedRatingCurve | Structurally direct; legacy HBWEIR threshold seam must be adjudicated |
| `WLDIP` | Fixed-weir supply target below crest | F-CI52 restricted supply logic | **Ribasim LevelDemand lower target** | **Q1B bounded research PASS** |
| `WSCAP` | Maximum external supply capacity | F-CI52 restricted capacity | **Ribasim supply-route capacity** | **Q1B PASS**; capacity remains distinct from realized supply |
| Actual supply flux | Realized water added to surface store | SWAP combined-system external inflow in F-CI52 | **Ribasim realized inflow/allocation** | **Q1B PASS** with direct cumulative Pump ledger |
| Fixed-weir discharge | Surface-system external outflow | SWAP F-CI52 | **Ribasim network outflow** | Q1A/Q1C |
| `SWMAN=2` target selection | Soil-state-driven water-level management | Not in current restricted F-CI52 production admission | **Coupler / management policy** | **Q2A bounded research PASS**, including phase seams and accepted-state rollback/replay |
| `GWLCRIT` | Groundwater criterion for automatic target phase | Legacy policy input | Not Ribasim-native soil state | **Coupler reads accepted SWAP state** | Q2 |
| `VCRIT` | Total soil-air-volume criterion | Legacy policy input | Not Ribasim-native soil state | **Coupler reads accepted SWAP state** | Q2 |
| `HCRIT/HDEPTH` | Pressure-head criterion at selected soil depth | Legacy policy input | Not Ribasim-native soil state | **Coupler reads accepted SWAP state** | Q2 |
| `WLSMAN` | Phase-specific target water levels | Legacy policy table | Ribasim realizes requested target; does not select it from soil state | **Q2A policy PASS + Q2B1 managed-band realization PASS** |
| `WLSTAR` | Continuation-critical previous automatic target | Legacy management memory | Not physical surface-water storage | **Coupler accepted policy state** | **Q2A PASS**: between-event memory, reject/replay and stale-commit fail-closed |
| `DROPR` | Bounds downward target change | Legacy policy | Not surface-water hydraulics | **Coupler policy** | **Q2A PASS**, including `DROPR=0.001` equality seam and immediate upward changes |
| `INTWL` / calendar adjustment schedule | Target reevaluation timing | Legacy controller timing | Not intrinsic Ribasim hydraulic state | **Coupler explicit event schedule** | Replace calendar arithmetic with explicit coupling events |
| `WLSBAK` | Oscillation/numerical history | Legacy numerical continuation | No physical owner | Candidate retire in external-owner mode |
| `OSSWLM` | Legacy timestep-reduction/oscillation policy | Legacy numerical policy | No physical owner | Candidate retire; do not preserve as physics |
| Legacy fixed-weir bisection tolerance | Numerical implementation detail | Replaced by qualified F-CI52 numerics in current standalone profile | Ribasim solver/numerics | Do not copy as physical requirement |
| Legacy parser/index state | File-driven schedule/config plumbing | Adapter only as needed | Typed external configuration | Candidate retire after mapping qualification |

## Core ownership rule

For one physical surface-water store:

```text
SWAP_FIXED_WEIR_STATE_OWNER XOR EXTERNAL_RIBASIM_STATE_OWNER
```

The same physical storage, level, supply or discharge may not be authoritative in both models.

## Core exchange rule

In external-Ribasim mode:

```text
accepted Ribasim level/state
    -> SWAP unconstrained soil-exchange response
    -> cross-model feasibility / availability resolution
    -> one realized signed transfer
    -> book once in SWAP and once in Ribasim with opposite signs
```

The legacy state-dependent availability limiter is therefore not allowed to survive as a hidden second surface-water model inside SWAP.

## Remaining qualification blocks

1. **Q1A**: linear fixed-weir external ownership with real Ribasim. **Closed as bounded research PASS through R3/R3L; native TRC exactness separately falsified.**
2. **Q1B**: level-triggered supply with explicit Ribasim demand and route capacity. **Closed as bounded research PASS for the three preregistered cases.**
3. **Q1C**: nonlinear SWQHR1 power-law representation by Ribasim tabulated rating curves.
4. **Q2**: accepted-soil-state-driven automatic management policy and `WLSTAR` transaction semantics. **Q2A PASS. Q2B1 managed-band realization PASS; dynamic Q(h)-limited composition remains Q2B2.**
5. **Q3**: signed drainage/infiltration exchange, availability and mass reclassification.
6. **Q4**: final legacy container/parser retirement adjudication.

Until these gates are closed or explicitly excluded by a narrower application contract, whole-subsystem retirement remains unauthorized.
