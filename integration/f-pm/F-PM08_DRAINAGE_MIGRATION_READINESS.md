# F-PM08 Drainage Process Boundary & Migration Readiness

## Decision

`QUALIFIED_DRAINAGE_MIGRATION_READINESS_READY_FOR_RESTRICTED_STRUCTURAL_CANDIDATE`

This is a migration-readiness decision, not a production drainage implementation or a claim that all SWAP 4.3.1 drainage modes form one modern process object.

The source-bound conclusion is the opposite: legacy `MOD_drainage` combines at least three architecturally different responsibilities that must be separated before migration:

1. a stateless or externally controlled lateral drainage exchange law;
2. a spatial distributor that maps a level-integrated exchange onto soil compartments;
3. for extended drainage, a separate stateful surface-water storage and control system.

The first restricted structural candidate is therefore deliberately narrow: single-level basic drainage, `SWDRA=1`, `DRAMET=3`, drainage-only linear resistance, no interflow, no `DIVDRA`, no surface-water storage, no macropores and no solute coupling. The exchange is evaluated from the committed/start-of-trial groundwater state and held fixed during one admitted soil-water solve, matching the legacy ordering in which drainage sinks are constant for the current time step.

## Source authority and branch activation

The reserved branch `work/f-pm08-drainage-migration-readiness` was still at the old generic reservation head `fafeebdece209abcc320b24a3c8c2757800b2e0e` and contained no F-PM08-specific commits. The repository default `main` was also still at that stale head. F-PM08 was therefore activated from the live canonical branch `integration/f-ci-canonical` at exact head `df435824de175e3f868b680aab2cd0a395aa19ff`.

The frozen SWAP 4.3.1 B0 manifest at that source line identifies the canonical nested legacy archive by SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. The drainage files used for equation-level review match the repository manifest exactly:

| Legacy source | SHA-256 | Role |
| --- | --- | --- |
| `SWAP/drainage.f90` | `48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc` | basic drainage exchange laws |
| `SWAP/MOD_drainage.f90` | `cb354ea13a099422c9f3b9c87a60ccbe440c0dd3c83ba0502108da8ca70ff255` | switches, parameters, legacy SAVE data and dispatch |
| `SWAP/divdra.f90` | `d5917c80dde091f8264f875997ee7105d8b5f9b88e9d091ce162860930de8c91` | vertical/transmissivity distribution |
| `SWAP/headcalc.f90` | `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5` | legacy soil-water residual/Jacobian consumer |
| `SWAP/surfacewater.f90` | `d38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e` | extended drainage and surface-water balance/control |

No production `src` or frozen `reference` file is changed by this readiness workunit.

## What legacy drainage actually contains

`SWDRA=0` disables lateral drainage, `SWDRA=1` selects the basic drainage route and `SWDRA=2` selects drainage plus surface-water simulation. The legacy dispatcher in `MOD_drainage.f90:145-166` calls the basic reader/evaluator for `SWDRA=1`, and the extended reader/`SurfaceWater` route for `SWDRA=2`.

The time-step ordering matters. In `swap.f90:433-457`, drainage task 2 is evaluated before `SoilWater(2)`. For `SWDRA=2`, surface-water task 3 is evaluated after the soil-water solve. If the time step is rejected, soil-water state is restored and the step is retried. This legacy ordering is useful evidence for the first structural seam, but its global mutation pattern is not an architecture to copy.

The basic route first computes one total lateral exchange per drainage level. It then either calls `DIVDRA` or lumps each level's exchange into the bottom compartment. `drainage.f90:40-50` aggregates `qdrain(level)` and compares it with `sum(qdra)` using a legacy warning tolerance of `1e-5`. That warning tolerance is not acceptable as a modern mass-conservation policy. SWAP5 should instead derive both representations from one transfer object and enforce the accounting identity structurally.

### Option matrix

| Option | Physical law / role | Required hydraulic information | Persistent process state | Migration disposition |
| --- | --- | --- | --- | --- |
| `SWDRA=1, DRAMET=1` | tabulated `gwl -> q` using `AFGEN(qdrtab,abs(gwl))`, `drainage.f90:74-77` | groundwater level | none | later response-law child |
| `SWDRA=1, DRAMET=2` | Hooghoudt/Ernst family, IPOS 1 to 5, `q=diffl/R_total`, `drainage.f90:79-149` | groundwater level plus immutable geometry/conductivity parameters | none | later response-law child |
| `SWDRA=1, DRAMET=3` | per-level drainage/infiltration resistance, `drainage.f90:151-194` | groundwater level plus drain/control level | none when control level is external | selected family, narrow subset first |
| `DRAMET=3, SWNRSRF=1` | empirical power interflow `q=COFINTFL*diffl**EXPINTFL`, `drainage.f90:170-179` | groundwater and drain level | none | held for nonlinear derivative qualification |
| `NRLEVS>1` | composition of multiple per-level exchange laws | shared groundwater level plus per-level controls | none for externally controlled levels | held until one-level route qualifies |
| `SWDIVD=1` / `DIVDRA` | transmissivity-based spatial distribution of lateral exchange, principal partition `divdra.f90:237-250` | groundwater level, grid, layer mapping, Ksat, anisotropy, spacing | none | separate child, not part of scalar exchange law |
| `SWDRA=2` exchange | groundwater to primary/secondary surface-water exchange with geometry, resistances and branch logic, `surfacewater.f90:468-641` | groundwater level, ponding, resolved surface-water level | none if receiver head is external | held with surface-water composition work |
| `SWDRA=2` storage/control | secondary surface-water storage, water level, management and supply/discharge, `surfacewater.f90:5-75` and `MOD_drainage.f90:91-134` | explicit hydraulic/control summaries | yes when secondary storage is simulated | separate stateful component owned by runtime/coupler composition |

These modes are related physical functionality, but they are not one migration object. The exchange law can remain reusable across standalone SWAP and coupled runtimes. `DIVDRA` is a soil-water distribution seam. Surface-water storage/control is system composition.

## State and data classification

The legacy use of module `SAVE` does not prove that a quantity is persistent physical state. F-PM08 classifies data by continuation semantics instead.

For the selected basic linear-resistance candidate, immutable parameters are drainage resistance, drain-bottom semantics and the allowed exchange direction. The resolved drain head is forcing/control for the current interval. The hydraulic view supplies groundwater level. The physical output is a signed external exchange rate. Branch selection, raw head difference and clamping are diagnostics. `diffl` is scratch. There is no drainage continuation state.

For `DRAMET=1`, the interpolation table is immutable model data and interpolation temporaries are scratch. For `DRAMET=2`, IPOS, conductivities, geometry, drain spacing and entry resistance are immutable parameters; equivalent depth and resistance components are scratch/diagnostics, not persistent column state.

`DIVDRA` contains many arrays that are temporary construction data, including drainage ordering, discharge-layer depths, transmissivity accumulators and `Khor/Kver/KD`. These belong to worker/job scratch. They must not become permanent per-column state merely because the legacy module saved them.

Extended surface-water simulation is different. `SWST` is real secondary-system water storage when that system is simulated and therefore requires committed persistent state. `WLS` may be persisted or derived from the chosen canonical storage representation. Target/control memory such as `WLSTAR`, adjustment history and counters only belongs in persistent state if exact continuation semantics require it. Static storage-level and discharge relationships are immutable parameters. Prescribed water levels and management inputs are forcing/control.

Optional functionality must allocate state only when active. A column using the selected basic drainage candidate therefore carries no surface-water state and no `DIVDRA` workspace.

## Owner and dependency map

The target ownership is deliberately narrow.

The drainage exchange process owns the physical response law. It receives immutable parameters, a generic interval/control view and the hydraulic information it needs. It returns signed physical transfer, derivative metadata when available, and diagnostics. It does not know file formats, calendar parsing, MODFLOW topology or solver arrays.

A separately qualifiable drainage spatial distributor owns the mapping from each level-integrated exchange to per-node soil-water source/sink contributions. Its hard identity is that the node vector aggregates exactly to the scalar transfer represented by the same exchange object. `DIVDRA` physics belongs here, not in a generic drainage resistance object.

The soil-water solver owns residual and Jacobian assembly. It consumes process outputs through an interface. It owns Newton vectors, the Jacobian, factorization, line search/backtracking and any chain rule from process-level hydraulic response to solver unknowns. Drainage process code must never mutate a HeadCalc-equivalent Jacobian.

The runtime/coupler owns transaction composition, event subdivision, receiver/component wiring and accepted mass-ledger publication. A future stateful surface-water component belongs to this composition layer. SWAP drainage must not know whether a receiver is an internal ditch component, an external surface-water model or part of a groundwater coupling system.

The current canonical source already provides the useful first half of this boundary. `process_hydraulic_view_t` exposes pressure head, water content, ponding depth and groundwater level, and the runtime can construct that view from a committed-state snapshot. The current B1.10 source/sink provider consumes precomputed `drainage_flux_by_level(:,:)` and adds it to the soil-water sink. There is not yet a dedicated drainage process owner in `src/process`.

## Hydraulic interface

The logical process interface should distinguish the scalar exchange law from spatial distribution. A concrete Fortran type layout is intentionally not frozen here, but the semantic contract is:

```text
DrainageExchangeLaw.evaluate(
    parameters,
    control,
    hydraulic_summary,
    [t0,t1]
) -> {
    q_external_by_level,
    optional dq_dhydraulic,
    derivative_availability,
    branch_diagnostics
}

DrainageSpatialDistributor.distribute(
    q_external_by_level,
    immutable_profile_data,
    qualified_hydraulic_view
) -> {
    q_external_by_node,
    optional response_metadata,
    distribution_diagnostics
}
```

The sign convention is explicit: `q_external > 0` means water leaves the soil column toward the drainage receiver. Negative exchange means water enters the soil from the receiver. The soil-water seam may internally represent this as a signed sink, or split positive/negative contributions, but there must be one physical transfer identity.

The first candidate requires only `groundwater_level` and an externally resolved `drain_head`. No process should reach into HeadCalc arrays to reconstruct these values.

## Derivative contract

Derivative ownership has two levels and must not be conflated.

The process owns derivatives of its physical response law with respect to the hydraulic summary it consumes. For the selected drainage-only linear route,

```text
q = max(0, (gwl - h_drain) / R_drain)
```

so the active branch has `dq/dgwl = 1/R_drain` and the inactive branch has derivative zero. At the branch point `gwl=h_drain`, the response is nonsmooth. The implementation must expose the branch or nondifferentiability explicitly rather than silently smoothing the law.

The solver owns transformation of that derivative to solver unknowns. If an implicit route later needs `dq/dh_i`, and groundwater level itself is a hydraulic summary derived from the head vector, the solver/hydraulic-summary owner must provide the relevant `dgwl/dh_i`. The solver then assembles the chain rule. Process code never writes `dFdhM`, `dFdhL`, `dFdhU` or an equivalent Jacobian.

This distinction is source-bound by the legacy code. `headcalc.f90:82-91` calls the drainage contribution a sink term constant for the current time step. `headcalc.f90:632-691` builds the Jacobian without a drainage derivative. Therefore the first candidate can preserve B1.10 ordering by evaluating drainage once from the committed/start-of-trial hydraulic view and freezing it during the solve.

A later fully implicit route is intentionally held. The current generic source/sink callback receives trial `pressure_head` and `water_content`, but it has no explicit trial groundwater-level summary and returns no generic source/sink derivative. Those are owner-interface prerequisites, not reasons for drainage code to reach around the solver contract.

## Mass contract

Drainage is an external water transfer, not a diagnostic flux.

For every accepted interval, exactly the same integrated exchange object that enters the soil-water state update must enter the mass ledger. For positive drainage,

```text
M_out,drain += integral(q_external dt)
```

and for negative exchange,

```text
M_in,drain += integral(-q_external dt)
```

There is no second independently reconstructed drainage quantity for reporting. Scalar-per-level and per-node representations are two views of the same transfer and must have an exact aggregation identity by construction.

During checkpoint -> trial/retry -> commit, a trial may carry a proposed integrated drainage exchange so its candidate balance can be checked. A rejected trial changes neither committed physical state nor committed mass ledger. The committed drainage transfer is published exactly once when the candidate is accepted. Re-evaluating or retrying a step must therefore never accumulate drainage mass on top of a previous rejected attempt.

There is no configurable drainage mass tolerance. Floating-point residuals may be reported diagnostically, but they cannot legalize lost, duplicated or omitted water. The legacy `1e-5` warning in `drainage.f90:46-50` is not carried forward as an acceptance policy.

## Time contract

Drainage physics operates over a generic `[t0,t1]`. Day, midnight, date strings and `.dra` tables are not kernel concepts.

Legacy `DRAMET=3` samples prescribed drain levels from `OWLTAB` using `t1900` and `dt`. In SWAP5, a legacy adapter may still parse that input and a runtime control provider may resolve it, but the drainage process receives a control value valid for its interval. If a control changes inside `[t0,t1]`, runtime subdivides at the event or supplies another independently qualified representation.

The extended surface-water route contains stronger legacy calendar assumptions. In particular, `INTWL` is validated as a one-to-31-day management interval and the control logic detects its subperiod from legacy time variables. Those semantics are held for F-PM08D and must be expressed as generic runtime events/cadence before migration. They are not evidence that drainage itself has a fundamental daily time step.

## First restricted candidate

F-PM08 selects child `F-PM08A`, **Restricted Single-Level Linear-Resistance Drainage Structural Candidate**.

Admitted scope:

```text
SWDRA   = 1
DRAMET  = 3
NRLEVS  = 1
SWALLO  = 3       drainage only
SWNRSRF = 0       no empirical interflow
SWDIVD  = 0       no transmissivity distribution
SWMACRO = 0
SWSOLU  = 0
```

The process has no persistent state. It reads groundwater level from the qualified hydraulic view, receives a drain head/control value for the generic interval, and evaluates the linear resistance law. The resulting transfer is frozen during one soil-water solve and can initially be projected to the existing precomputed source/sink seam with bottom-node lumping. This is a restricted parity mechanism, not the final distribution architecture.

This candidate is preferable to starting with `DRAMET=1`. The table route is shorter code, but it primarily tests legacy interpolation. The selected resistance route exposes the intended physical process boundary, a meaningful head-response derivative and the transaction/mass ownership needed by later drainage modes without importing surface-water state or Hooghoudt/Ernst submodels.

## Held options and child workunits

The decomposition requires four explicit children:

- `F-PM08A`: restricted single-level linear-resistance drainage structural candidate.
- `F-PM08B`: drainage spatial distribution and `DIVDRA` migration qualification, including exact scalar-to-node mass identity and any nonlocal hydraulic response.
- `F-PM08C`: response-law family and sensitivity qualification for `DRAMET=1`, `DRAMET=2`, empirical interflow and multi-level aggregation.
- `F-PM08D`: surface-water-controlled drainage composition readiness, separating the stateful surface-water system from the reusable drainage exchange law and placing component composition under runtime/coupler ownership.

Before any fully implicit groundwater-level-dependent drainage route, the soil-water interface owner must separately qualify a trial hydraulic-summary/GWL seam and a source/sink response-derivative contract. F-PM08 does not assign an unverified existing F-SI workunit number to that dependency.

## Architecture invariant audit

| # | F-PM08 assessment |
| ---: | --- |
| 1 | PASS: one reusable process boundary, no separate standalone/MultiSWAP/MODFLOW drainage kernel. |
| 2 | PASS: files, `.dra`, `AFGEN` date parsing and paths remain adapter/runtime concerns. |
| 3 | PASS: parameters, committed state, controls/forcing, hydraulic view, results, diagnostics and scratch are classified separately. |
| 4 | PASS: selected candidate has zero drainage continuation state; stateful surface water is separate and only active when used. |
| 5 | PASS: `DIVDRA` construction arrays and solver/Jacobian data are worker/job scratch. |
| 6 | PASS: logical process API does not prevent SoA, pooled per-level data or batched homogeneous execution. |
| 7 | PASS: drainage transfer is trial-local until commit; rejected trials cannot book committed mass. |
| 8 | PASS: response can be cheaply recomputed from the same committed hydraulic state with changed drain control; warm numerical guesses do not redefine physical base state. |
| 9 | PASS: `[t0,t1]` is generic; legacy day/calendar control is translated outside the process. |
| 10 | PASS: no 00:00-to-00:00 coupling-window assumption is introduced. |
| 11 | PASS: transaction and response-derivative seams are designed now even though system coupling is not implemented here. |
| 12 | N/A to direct implementation: F-PM08 does not alter the SWAP-MODFLOW head/flux interface contract. Future composition must preserve it. |
| 13 | PASS: one signed transfer object drives state and ledger; no mass tolerance concession. |
| 14 | PASS by design: process response derivatives are first-class optional output; solver chain rule/assembly is separate. |
| 15 | PASS: no finite-difference multi-run derivative requirement is introduced for drainage. |
| 16 | PASS: stateless selected candidate and worker scratch are compatible with batched MultiSWAP. |
| 17 | PASS: drainage process knows nothing about MODFLOW cell/tile area fractions. |
| 18 | PASS: no deep-vadose ownership is introduced into drainage. |
| 19 | PASS: all receiver/component transitions must use the same signed transfer identity; no duplicate storage ownership. |
| 20 | PASS: drainage consumes a soil-water interface, not one Richards implementation. |
| 21 | PASS: reusable drainage physics remains separate from legacy global structures. |
| 22 | PASS: no HeadCalc internals are visible to process code. |
| 23 | PASS: physical drainage options are distinct from numerical explicit/implicit/fallback policy. |
| 24 | PASS by boundary: difficult nonlinear modes are held for bounded-cost qualification rather than hidden in the first candidate. |
| 25 | PASS: B1.10 remains the frozen reference and the initial route preserves its explicit sink ordering. |
| 26 | PASS: route, branch, derivative availability, retries and accepted mass transfer are explicit diagnostic requirements. |
| 27 | PASS: surface-water state, `DIVDRA` scratch and nonlinear-law metadata exist only for active options. |
| 28 | PASS: stateful surface-water/drain receiver composition is owned by runtime/coupler, not by the SWAP drainage kernel. |
| 29 | PASS: no midnight, one-day, `.dra` or MODFLOW assumption enters the process contract. |
| 30 | PASS: this readiness workunit records source locks, ownership, mass, derivative, time, children and held scope before structural migration. |

## Exit

F-PM08 has completed the source-bound process decomposition needed to start the smallest drainage migration candidate without conflating exchange physics, spatial distribution, surface-water state or solver Jacobian ownership.

`QUALIFIED_DRAINAGE_MIGRATION_READINESS_READY_FOR_RESTRICTED_STRUCTURAL_CANDIDATE`
