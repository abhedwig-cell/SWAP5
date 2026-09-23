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
| `SWST` | conserved secondary surface-water storage for `SWSEC=2` | **RIBASIM OWNER**. Do not allocate the same physical store in SWAP | retain F-CI52 optional state | Q1A/Q1B/Q2 plus mode-exclusion gate |
| `WLS` under `SWSEC=2` | level derived from `SWST` | **RIBASIM OWNER**. Pass accepted level to SWAP exchange physics | derived from F-CI52 storage | Q1A |
| `WLS` under `SWSEC=1` | prescribed secondary level forcing | **RIBASIM-RESOLVED FORCING** | legacy/adapter forcing if supported | forcing mapping only |
| `WLP` | prescribed primary-system level forcing | **RIBASIM-RESOLVED FORCING** | external forcing | forcing mapping only |
| `STTAB` | 22-knot secondary storage-level relation | **RETIRE FROM COUPLED SWAP STATE**. Represent storage geometry in Ribasim Basin profile | retain where F-CI52 requires it | geometry mapping, not duplicate calibration |
| `SWMAN=1`, `HBWEIR`, power Q(h) | fixed-weir target and physical discharge relation | **RIBASIM HYDRAULICS** using physical rating relation | retain F-CI52 | Q1A. Ribasim interpolation semantics must be explicit |
| `SWQHR=2`, tabular Q(h) | tabulated discharge relation with legacy crest-threshold seam | **RIBASIM HYDRAULICS** using the Q(h) table itself | not admitted by current restricted F-CI52 | separate mapping; do not migrate inferred legacy crest seam silently |
| `WLDIP` + `WSCAP` | one-sided low-level supply trigger plus maximum supply capacity | **RIBASIM ALLOCATION/ROUTE CAPACITY** | retain current fixed-weir envelope | Q1B |
| `SWMAN=2` phase selection | choose managed target from GWL, total air volume and selected pressure head | **COUPLER MANAGEMENT POLICY** driven only by accepted SWAP state | future standalone feature only if separately admitted | Q2A |
| `WLSTAR` | continuation-critical managed target memory | **COUPLER ACCEPTED POLICY STATE** | not in current F-CI52 scope | Q2A rollback/replay |
| `DROPR` | downward target-rate limiter | **COUPLER POLICY** | not in current F-CI52 scope | Q2A temporal semantics |
| automatic discharge capacity | attempt to realize target subject to hydraulic capacity | **RIBASIM REALIZATION**. Candidate design: LevelDemand band + allocation-controlled rating curve | legacy branch has documented discrepancy | Q2B |
| extended `QDRAIN` drainage/infiltration law | stateless soil/drain exchange from GWL, water level, geometry and resistance | **RETAIN IN SWAP** | retain/qualify as SWAP process physics | Q3A |
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

The pinned Ribasim release explicitly supports allocation-controlled TabulatedRatingCurve nodes whose allocated flow remains bounded by the physical Q(h) curve. A **positive** route priority is the candidate policy for the automatic-weir discharge route: discharge should occur only as needed to remove surplus above the managed upper level, not because the route is rewarded for flowing.

This is a hypothesis for Q2B, not current production authority.

## Important non-retirement conclusion

The statement “Ribasim makes the SWAP surface-water module unnecessary” is only correct for the **surface-water state and system-management realization** in a coupled application. It is incorrect for the whole legacy source file.

The future architecture should therefore remove duplicated ownership, not indiscriminately remove process physics.
