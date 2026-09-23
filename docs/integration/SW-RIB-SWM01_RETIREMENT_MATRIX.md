# SW-RIB-SWM01 coupled-mode retirement matrix

**Date:** 2026-09-23  
**Status:** research disposition; no production retirement authority  
**Baseline:** `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`

This matrix answers a narrower question than “can `surfacewater.f90` be deleted?”. It records, per legacy responsibility, what happens when the same physical surface-water system is represented by real Ribasim.

The core conclusion is mode-dependent:

- **standalone SWAP5:** the admitted F-CI52 restricted fixed-weir capability remains valid inside its qualified envelope;
- **SWAP5 + Ribasim:** Ribasim must be the sole owner of surface-water storage, level and network realization for the represented water body;
- the remaining SWAP responsibilities are process exchange physics, not a second surface-water model;
- soil-state-driven management logic belongs to the outer management/coupling layer.

| Legacy responsibility | Exact legacy meaning | Ribasim-coupled disposition | Standalone SWAP5 | Qualification still required |
|---|---|---|---|---|
| `SWST` | conserved secondary surface-water storage for `SWSEC=2` | **RIBASIM OWNER**. Do not allocate the same physical store in SWAP | retain F-CI52 optional state | Q1A/Q1B/Q2A/Q2B1 are bounded research PASS; production mode-exclusion gate still required |
| `WLS` under `SWSEC=2` | level derived from `SWST` | **RIBASIM OWNER**. Pass accepted level to SWAP exchange physics | derived from F-CI52 storage | Q1A-R3/R3L bounded research PASS for the declared linear fixed-weir profile |
| `WLS` under `SWSEC=1` | prescribed secondary level forcing | **RIBASIM-RESOLVED FORCING** | legacy/adapter forcing if supported | forcing mapping only |
| `WLP` | prescribed primary-system level forcing | **RIBASIM-RESOLVED FORCING** | external forcing | forcing mapping only |
| `STTAB` | 22-knot secondary storage-level relation | **RETIRE FROM COUPLED SWAP STATE**. Represent storage geometry in Ribasim Basin profile | retain where F-CI52 requires it | geometry mapping, not duplicate calibration |
| `SWMAN=1`, `HBWEIR`, power Q(h) | fixed-weir target and physical discharge relation | **RIBASIM HYDRAULICS** using an explicitly qualified representation | retain F-CI52 | `BETAW=1`: Q1A-R3/R3L PASS via ContinuousControl + Pump. General nonlinear `BETAW`: Q1C open |
| `SWQHR=2`, tabular Q(h) | tabulated discharge relation with legacy crest-threshold seam | **RIBASIM HYDRAULICS** using the Q(h) table itself | not admitted by current restricted F-CI52 | separate mapping; do not migrate inferred legacy crest seam silently |
| `WLDIP` + `WSCAP` | one-sided low-level supply trigger plus maximum supply capacity | **RIBASIM ALLOCATION/ROUTE CAPACITY** | retain current fixed-weir envelope | Q1B bounded research PASS |
| `SWMAN=2` phase selection | choose managed target from GWL, total air volume and selected pressure head | **COUPLER MANAGEMENT POLICY** driven only by accepted SWAP state | future standalone feature only if separately admitted | Q2A bounded research PASS |
| `WLSTAR` | continuation-critical managed target memory | **COUPLER ACCEPTED POLICY STATE** | not in current F-CI52 scope | Q2A rollback/replay PASS |
| `DROPR` | downward target-rate limiter | **COUPLER POLICY** | not in current F-CI52 scope | Q2A temporal semantics PASS |
| automatic discharge capacity | attempt to realize target subject to hydraulic capacity | **RIBASIM REALIZATION** | legacy branch has documented discrepancy | Q2B1 managed-band + bounded routes PASS; dynamic Q(h)-limited capacity is separate Q2B2 |
| extended `QDRAIN` drainage/infiltration law | stateless soil/drain exchange from GWL, water level, geometry and resistance | **RETAIN IN SWAP** | **production owner still incomplete for full signed legacy route**; F-PM08D2 is readiness-only | Q3A research coupling + later production migration/admission required before whole-file deletion |
| `DIVDRA` distribution | distribute one authoritative drainage transfer over soil nodes | **RETAIN IN SWAP** | already separately qualified in restricted routes | Q3A composition |
| secondary availability limiter | cap net infiltration using `SWST` + supply availability | **CROSS-MODEL FEASIBILITY**, not hidden SWAP state | internal only when SWAP owns the store | Q3A, especially negative exchange |
| `QRapDra` | rapid/macropore delivery into secondary water | **SWAP PROCESS -> RIBASIM TRANSFER** | SWAP process | Q3B |
| positive `RUNOTS` | top-surface/runoff delivery into secondary water | **SWAP PROCESS -> RIBASIM `surface_runoff`-class transfer** | SWAP process | Q3B |
| negative `RUNOTS` | inundation/water transfer from secondary water to SWAP surface | **RIBASIM -> SWAP TOP-BOUNDARY TRANSFER** | legacy internal balance | Q3B; cannot be encoded as negative Ribasim surface_runoff |
| `WLSBAK`, `OSSWLM` | legacy oscillation/timestep history and policy | **RETIRE OR REPLACE AS NUMERICAL POLICY**, never physical state | no claim of required physical preservation | numerical-policy disposition |
| `IMPEND`, `INTWL`, legacy day arithmetic | management calendar and adjustment cadence | **COUPLER SCHEDULER** using explicit event times; RM11/RM12 authority is reusable | adapter/runtime concern | Q2A |
| `NUMADJ` | adjustment diagnostic | optional diagnostic only | optional diagnostic | no physical retention requirement |
| `SWSRF=1` extended route | source route with documented undefined/stale local `WL` risk | **DO NOT DIRECTLY MIGRATE** | held from deterministic production migration | explicit retirement or separate qualification |

## Ribasim names do not imply physics ownership

The pinned Ribasim release exposes Basin forcings named `drainage`, `infiltration` and `surface_runoff`. They are non-negative lumped surface-water balance forcings. They are suitable receiver/sender terms for an external SWAP coupling, but they do not reproduce the SWAP exchange law.

For the lower exchange, the intended directional mapping is:

```text
q_swap > 0  (soil/drainage system -> surface water)
    => Ribasim drainage-class inflow

q_swap < 0  (surface water -> soil/drainage system)
    => Ribasim infiltration-class outflow
```

The coupler must preserve one transfer identity and must not independently activate an internal Ribasim groundwater-exchange process for the same water.

## Automatic-management mapping hypothesis

The legacy automatic regime naturally decomposes into:

```text
accepted SWAP GWL / air volume / selected pressure head
    -> phase selection
    -> requested target WLSMAN
    -> accepted WLSTAR memory + DROPR rule
    -> Ribasim LevelDemand band:
         min = WLSTAR - WLDIP
         max = WLSTAR
    -> bounded supply route
    -> allocation-controlled physical rating-curve discharge
```

Q2B1 has now qualified the narrower and cleaner realization claim: a Ribasim LevelDemand band plus separately bounded supply and discharge routes reaches the band when capacity is adequate, remains explicitly outside it when capacity is insufficient, and closes the direct mass ledger. Dynamic Q(h)-limited discharge remains Q2B2. It must not inherit an exactness claim from native `TabulatedRatingCurve`, because Q1A-V1/R2 demonstrated the pinned PCHIP representation is not exactly equivalent to the legacy hard-kink linear law.

## Important non-retirement conclusion

The statement “Ribasim makes the SWAP surface-water module unnecessary” is only correct for the **surface-water state and system-management realization** in a coupled application. It is incorrect for the whole legacy source file.

The future architecture should therefore remove duplicated ownership, not indiscriminately remove process physics.


## Whole-file deletion remains a stronger migration decision

Even if Q3 closes the external-owner coupling semantics, `surfacewater.f90` cannot yet be deleted solely on that basis. The exact-source F-PM08D2 work identifies a scientifically retained signed drainage/infiltration law that is not yet a fully admitted production provider in current canonical SWAP5. In particular, the current Drainage-v1 documentation explicitly does not admit unrestricted drain-to-soil reverse exchange.

Therefore the final sequence is:

```text
external Ribasim ownership qualified
    -> signed exchange transaction qualified
    -> retained exchange physics receives a non-legacy production owner
    -> application-profile mode guard admitted
    -> only then consider deleting the legacy container
```

This distinction is intentional: removing duplicate surface-water **state ownership** can be correct before deleting every legacy source container that still contains retained SWAP process physics.


## Research closeout disposition

SW-RIB-SWM01 is now research-closed for the ownership/decomposition question. Q3A/Q3B qualify the signed and identity-preserving coupling semantics, and Q4A/Q4B qualify extraction and transactional runtime binding of the retained signed exchange law.

For an explicitly declared external-Ribasim application profile, legacy surface-water **state/control/container ownership** is therefore a research-qualified retirement candidate. This does not extend to retained SWAP process physics and is not yet production retirement authority.

Two representation choices must remain explicit in any production profile:

1. direct exact STTAB-to-Ribasim mapping is false; use a qualified controlled representation such as Q1H with an application-frozen error envelope;
2. exact generic nonlinear SWQHR1 parity is not established by native Ribasim TabulatedRatingCurve semantics.

See [SW-RIB-SWM01 research closeout](SW-RIB-SWM01_CLOSEOUT.md).
