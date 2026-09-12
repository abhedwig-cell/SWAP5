# F-DOC16 — SWAP5 Physical-System Scope, 1D Column Abstraction & Conceptual Model Authority

## Decision and bounded authority

F-DOC16 closes the bounded `SCI-FOUND-01` gap identified by F-DOC15 at the **model-foundation level**.

Decision, once the exact branch head passes the F-DOC16 qualification workflow:

`QUALIFIED_SCI_FOUND_01_CONCEPTUAL_FOUNDATION_AUTHORITY`

This authority establishes the SWAP5 chain

`physical system -> modelling purpose -> spatial and temporal scales -> system boundary -> abstraction and idealisation -> conceptual model -> downstream formal/numerical/implementation authorities`.

It is authoritative for **system scope, abstraction, conceptual entities, process disposition categories and model-level nonclaims**. It does **not** replace process-specific T1-T4 theory/equation authorities, T6-T7 numerical authorities, T11 verification, T12 validation or application-specific fitness-for-purpose evidence.

No production source, reference data, physical equation, solver policy, release qualification or RB1 source authority is changed.

## 1. Source and lineage basis

The conceptual foundation is based on four source classes that have different roles.

1. **SWAP 4.3 theory and user guide, Model overview, Working Group SWAP, 30 June 2026.** The manual describes SWAP as a one-dimensional vertically directed field-scale model, with a domain from the atmosphere/canopy through the soil toward shallow groundwater, and explicitly states the assumptions and limitations of the 1D abstraction. For SWAP5 this is classified as `LEGACY_MANUAL` with lineage `STRUCTURALLY_REIMPLEMENTED`: the scientific 1D-column concept is retained, while system composition, time semantics, I/O boundaries, deep-vadose treatment, MultiSWAP and direct groundwater coupling are modernised.
2. **Kroes et al. (2017), SWAP version 4; Theory description and user manual, WENR Report 2780, DOI 10.18174/416321.** This is historical SWAP technical-report authority for the model domain and process family, not evidence that SWAP5 code implements every described process.
3. **Van Dam (2000), Field-scale water flow and solute transport: SWAP model concepts, parameter estimation and case studies, DOI 10.18174/121243.** This supports the field-scale agro-/ecohydrological modelling purpose and long-standing conceptual lineage.
4. **Heinen et al. (2024), SWAP 50 years: Advances in modelling soil-water-atmosphere-plant interactions, Agricultural Water Management 298, 108883, DOI 10.1016/j.agwat.2024.108883.** This supports the current scientific domain and major process families, but is not implementation or release evidence.

The SWAP5 architecture authorities at `integration/f-ci-canonical@ca1dbf6f51e606bdd2a89aa9057ed40b2d99b868` are used only to reconcile the historical scientific abstraction with the new computational composition. A moving integration branch is not made a release authority by this document.

## 2. Real-world system represented by SWAP

### `SW5-PHEN-0001` — Local soil-plant-atmosphere hydrological system

The primary real-world object represented by SWAP is a **local vertical soil-plant-atmosphere system over a defined horizontal support**, in which water is stored and exchanged through the canopy/surface, root zone, unsaturated soil and, where included in the configured column, an upper saturated part of the profile.

The scientific focus is the water balance and related soil-plant processes at local-to-field support. Additional process families such as solute transport, heat transport, crop growth, macropore flow, snow/frost and drainage may be active when they are explicitly part of the configured and qualified physics profile.

SWAP does not represent the complete surrounding catchment, atmosphere, aquifer or surface-water network as spatially resolved domains. Those systems enter through forcing, boundary conditions, parameterised exchange laws or explicit external components.

### Modelling purpose

The model foundation is intended to support process-based simulation of water storage and fluxes in the soil-plant-atmosphere column, including the consequences of meteorology, vegetation, soil properties and water management for variables such as soil moisture, evapotranspiration, root water uptake, surface exchange, drainage and bottom exchange.

The foundation also supports coupled use in which SWAP supplies local soil-plant-atmosphere physics while another component represents groundwater, surface-water aggregation, regional composition or deep-vadose transfer.

This purpose statement is not a validation claim for any particular application.

## 3. Spatial abstraction

### `SW5-CONCEPT-0001` — Representative one-dimensional column

A logical SWAP column is a one-dimensional vertical representation of a horizontally supported part of the landscape. State variables may vary with depth and time. Horizontal coordinates are not resolved inside the column.

The column has **no universal fixed horizontal area**. Its quantities are interpreted per unit horizontal area unless an explicit surrounding runtime/coupler applies an area weight. The horizontal support may be point-like, plot-like, tile-like or representative of a field/parcel, but only if forcing, parameters, boundary conditions and the unresolved lateral variability are representative at that support.

### Why the 1D abstraction is admissible

The 1D abstraction is scientifically admissible only when all of the following application-level conditions are sufficiently met for the target outputs and tolerances:

1. vertical storage and transport through the soil-plant profile are the dominant internally resolved spatial dynamics;
2. unresolved horizontal variability within the chosen support is small enough, or can be represented by effective parameters, multiple columns/tiles or an external spatial model;
3. relevant lateral water exchanges can be represented by parameterised source/sink terms, imposed boundary exchange, or an external coupler without requiring the internal horizontal flow field;
4. the supplied meteorological, soil, crop, management and boundary information is representative for the chosen support;
5. the requested output does not require a spatially resolved 2D or 3D distribution within that support.

These are **conditions of use**, not conclusions guaranteed by SWAP itself. They must be assessed for each application class.

### Consequence

A single SWAP run cannot, by construction, resolve horizontal redistribution within a field. Examples that normally require another representation include the geometry of a wetted bulb below a local dripper, lateral hillslope redistribution, channelised surface routing across a landscape, or spatial groundwater flow through an aquifer.

## 4. Vertical system boundary

### `SW5-CONCEPT-0002` — Upper atmosphere/surface interface

The upper conceptual boundary separates the local SWAP system from atmospheric forcing and management inputs. Precipitation, radiation, temperature, humidity, wind and other meteorological quantities are forcing. Irrigation or analogous management additions are prescribed or runtime-generated management forcing. Interception, ponding, infiltration, soil evaporation, transpiration and runoff are internal or boundary-process responses only when their corresponding physics is active.

SWAP does not resolve atmospheric fluid dynamics.

### `SW5-CONCEPT-0003` — Layered soil and root-zone domain

The internal soil domain is vertically layered and may be variably saturated. Soil hydraulic, thermal, solute and root-related properties can vary by layer or depth according to active physics. The one-dimensional coordinate represents depth; no horizontal discretisation is implied.

### `SW5-CONCEPT-0004` — Lateral exchange abstraction

Lateral field-scale exchange is not a second spatial dimension inside SWAP. Drainage, ditch/drain infiltration and similar lateral interactions may be represented as depth-dependent or system-level source/sink terms or boundary exchange laws. Such terms are aggregate representations of lateral interaction and do not recover the internal horizontal head/flux field.

### `SW5-CONCEPT-0005` — Bottom interface

The lower boundary is the bottom of the configured SWAP column. It is an explicit physical interface through which a head or flux condition, or a coupled head/flux relation, may act.

The lower boundary is **not universally identical to deep groundwater recharge**. Three compositions are distinguished:

- in standalone use, a qualified bottom boundary condition can prescribe or calculate the exchange relevant to the configured profile;
- in direct groundwater coupling, the bottom interface can exchange head and flux with a groundwater model under the coupling contract, with mass-conservative opposite interface fluxes;
- when groundwater is materially deeper than the SWAP profile and travel/storage in the intervening vadose zone matters, an explicit external deep-vadose transfer component may lie between the SWAP bottom and groundwater.

This modernises the historical SWAP description in which the domain was commonly described as extending into shallow groundwater. SWAP5 retains the local 1D soil-column concept but makes the bottom-system composition explicit and external where appropriate.

## 5. Temporal abstraction

### `SW5-CONCEPT-0006` — Generic time interval

The scientific system evolves continuously in time, while forcing, process events and numerical solution operate on distinct time scales.

For SWAP5 the kernel advances a state over a generic interval `[t0,t1]`. A day, month or year is not a fundamental computational unit. The following must remain conceptually separate:

- characteristic physical-process time scales;
- forcing-data intervals;
- internal solver time steps and retries;
- management/event times;
- groundwater coupling windows;
- reporting/output intervals;
- crop/calendar events where the crop model explicitly requires them.

Historical documentation that describes daily meteorological or crop updates is therefore interpreted as process/input practice, not as a universal SWAP5 time boundary.

## 6. Conceptual process disposition

The following table defines the **default conceptual disposition**. `RESOLVED` means that, when that physical option is active and qualified, SWAP contains an internal state/flux representation for the process. It does not mean that the process is resolved from first principles or that every SWAP5 release already includes the capability.

| Process or external influence | Conceptual disposition | Foundation meaning |
|---|---|---|
| meteorological drivers | `FORCING` | external atmospheric state/flux information supplied over time |
| precipitation | `FORCING` | imposed atmospheric water input; internal partitioning may respond to it |
| prescribed irrigation/management water | `FORCING` | external management input unless generated by an explicitly active management policy outside/inside the qualified profile |
| canopy interception | `RESOLVED` | internal canopy storage/flux process when active |
| snow/frost | `RESOLVED` | optional internal process when active; not a universal column requirement |
| surface water storage/ponding | `RESOLVED` | local surface store when active |
| infiltration/exfiltration at soil surface | `RESOLVED` | coupled surface/soil boundary response |
| surface runoff from local support | `RESOLVED` | local runoff generation when active; spatial routing outside the support is external |
| soil evaporation | `RESOLVED` | local atmosphere-soil water loss when active |
| crop transpiration and root uptake | `RESOLVED` | local plant/soil sink process when active |
| vertical matrix soil-water flow | `RESOLVED` | central vertical variably saturated flow process for Richards-based profiles |
| macropore/preferential flow | `RESOLVED` | optional internal process when selected; absence must not silently imply equivalent physics |
| lateral drainage/infiltration exchange | `PARAMETERISED` | aggregate lateral exchange law/source-sink; horizontal field is not spatially resolved |
| imposed surface-water stage or drainage-system state | `BOUNDARY_CONDITION` | external boundary information for exchange law |
| bottom head or bottom flux | `BOUNDARY_CONDITION` | externally imposed or coupled condition at bottom interface |
| groundwater aquifer dynamics | `EXTERNAL_COMPONENT` | groundwater model/coupler owns regional/spatial groundwater evolution |
| deep-vadose travel/storage below a shallow SWAP column | `EXTERNAL_COMPONENT` | optional mass-conserving transfer component where material |
| MultiSWAP spatial aggregation and tile fractions | `EXTERNAL_COMPONENT` | runtime/coupler composition, not column physics |
| soil heat transport | `RESOLVED` | optional internal process when active |
| solute transport | `RESOLVED` | optional internal process at SWAP's admitted process detail |
| detailed pesticide chemistry beyond admitted SWAP solute physics | `EXTERNAL_COMPONENT` | specialised model such as PEARL when required |
| detailed nutrient biogeochemistry beyond admitted SWAP nutrient physics | `EXTERNAL_COMPONENT` | specialised model such as ANIMO when required |
| dynamic crop growth | `RESOLVED` | optional internal crop process, e.g. WOFOST-derived, when active |
| horizontal unsaturated flow field | `OUT_OF_SCOPE` | no 2D/3D internal soil-flow discretisation in one column |
| regional surface-water routing | `OUT_OF_SCOPE` | requires external surface-water/catchment component |
| atmospheric circulation/turbulence field | `OUT_OF_SCOPE` | atmospheric processes enter through forcing/closures, not resolved CFD |
| economic, social or policy-system dynamics | `OUT_OF_SCOPE` | may inform scenarios but are not SWAP physical state |

A process being listed as `RESOLVED` at the conceptual level does not admit it to RB1 or any other release. Release capability matrices and exact code/evidence authorities remain controlling.

## 7. Composition beyond one column

### `SW5-CONCEPT-0007` — Standalone column

Standalone SWAP applies the column abstraction directly. The user/application owns the representativeness of forcing, parameters and boundary conditions for the chosen horizontal support.

### `SW5-CONCEPT-0008` — MultiSWAP ensemble

MultiSWAP is not a wider 2D/3D SWAP soil domain. It is a runtime-managed set of logical columns, potentially with different parameters, forcing and states. Columns may be grouped for efficient execution, but the grouping may not silently change physics.

Spatial heterogeneity can be represented by multiple columns, provided the external application defines how those columns map to land units and how their outputs are aggregated.

### `SW5-CONCEPT-0009` — Surface tiles and area fractions

One groundwater cell or application unit may contain multiple surface fractions/tiles. Tile fractions and area-weighted aggregation belong to runtime/coupler composition. A SWAP column does not internally know the fraction of a MODFLOW cell that it represents.

Only tiles needing full soil-plant-atmosphere physics require a SWAP column.

### `SW5-CONCEPT-0010` — Direct groundwater coupling

In direct coupling the local SWAP bottom interface and the groundwater component exchange physically consistent head/flux information over a coupling window. The target interface relation is head consistency within qualified tolerance and equal/opposite water flux across the interface. Coupling does not turn the SWAP column into a groundwater model.

### `SW5-CONCEPT-0011` — Optional deep-vadose transfer

Where the groundwater table is too deep for direct interpretation of the SWAP bottom flux as groundwater recharge, a separate transfer component may represent storage and travel between the SWAP bottom and groundwater. Its stored water is not SWAP column state. Component transitions must conserve mass.

## 8. Principal assumptions and nonclaims

The SWAP5 conceptual foundation makes the following assumptions explicit.

1. **Dominant vertical dynamics.** The column abstraction assumes that resolving vertical gradients is sufficient for the requested local outputs after accounting for represented lateral exchange.
2. **Representative horizontal support.** Parameters, forcing and boundary conditions are treated as representative of the column support. Within-support heterogeneity is not automatically generated by the kernel.
3. **No hidden lateral conservation.** Water that leaves or enters through a drainage, runoff, bottom or coupling term must be booked explicitly. Lateral effects cannot be introduced as unaccounted corrections.
4. **No universal bottom interpretation.** Bottom flux is an interface flux. Its interpretation as recharge depends on the surrounding composition and application.
5. **No universal application accuracy.** Conceptual admissibility does not imply an error bound for groundwater head, crop yield, soil moisture, recharge or any other application output.
6. **No 2D/3D reconstruction.** Multiple columns do not become a horizontally coupled soil-flow model unless an explicit external component supplies that coupling.
7. **Optional physics is explicit.** Inactive macropore, crop, heat, solute or special drainage physics is not assumed to be represented implicitly.
8. **Numerical policy cannot redefine conceptual physics.** Reference/balanced/throughput or fallback choices may alter numerical strategy only within their qualified error envelope.
9. **Mass conservation remains hard.** All internal and external water exchanges must participate in an explicit water balance; no abstraction or performance path may create or destroy water.

## 9. Fitness-for-purpose consequences

### Conceptually suitable application classes

Subject to separate parameter, verification, validation, sensitivity and uncertainty evidence, the abstraction is naturally aligned with applications in which local vertical soil-plant-atmosphere dynamics and water balances are the principal target, including field/parcel agrohydrology, water-management effects, soil-moisture and root-zone studies, and coupled local land-surface exchange with groundwater or other models.

### Application classes requiring additional composition or scrutiny

The abstraction requires explicit external composition or a separate model when the target depends materially on:

- regional groundwater dynamics;
- deep-vadose storage/travel below the SWAP profile;
- spatially distributed surface-water routing;
- horizontal soil-water redistribution within a field;
- strong sub-field heterogeneity that cannot be represented by effective properties or multiple columns/tiles;
- localised 2D/3D irrigation or preferential pathways not represented by admitted SWAP options.

### Failure of the 1D admissibility test

A single-column application is not fit for purpose if a material target quantity depends on unresolved horizontal structure or exchange at a magnitude comparable to the application's tolerance and that effect is neither parameterised nor represented externally.

This is a conceptual screening rule. It does not substitute for T12 validation or quantified uncertainty.

## 10. Traceability to formal authorities

F-DOC16 deliberately stops before adopting process equations.

| Conceptual ID | Downstream authority obligation |
|---|---|
| `SW5-CONCEPT-0001` representative 1D column | process-specific T1-T4 authorities must use a vertical coordinate and state what lateral effects are excluded or represented as source/sink/boundary terms |
| `SW5-CONCEPT-0002` upper interface | surface/ET/interception/forcing authorities define the mathematical flux and store relations |
| `SW5-CONCEPT-0003` layered soil/root domain | soil-water, heat, solute and root-uptake authorities define equations, state variables and closures |
| `SW5-CONCEPT-0004` lateral exchange abstraction | drainage/interflow authorities define aggregate exchange equations and sign conventions |
| `SW5-CONCEPT-0005` bottom interface | bottom-BC and groundwater-coupling authorities define head/flux contracts and conservation signs |
| `SW5-CONCEPT-0006` generic time | F-DOC13 and subsequent temporal authorities define the numerical/formal interval treatment |
| `SW5-CONCEPT-0008` MultiSWAP ensemble | runtime/transaction authorities define execution without changing physical identity |
| `SW5-CONCEPT-0009` tile composition | coupler/runtime authorities define fractions and conservative aggregation |
| `SW5-CONCEPT-0010` direct groundwater coupling | groundwater-coupling authorities define residuals, coupling windows and interface conservation |
| `SW5-CONCEPT-0011` deep-vadose transfer | external-component authority defines transfer storage and conservative hand-off |

No process-specific mathematical formula in the SWAP 4.x manual becomes a SWAP5 T3/T4 authority merely because it is cited here.

## 11. RB1 versus post-RB1 scope

### Immutable RB1

RB1 remains pinned by its scientific source, qualification and release metadata authorities. Its required denominator is the 15-capability release matrix documented by F-DOC07.

F-DOC16 may be used to interpret the **conceptual foundation** of those RB1 capabilities, especially the local column, interval, mass, soil-water reference, ET/root and restricted surface-evaporation concepts. It does not retroactively add any process capability that is absent from the RB1 release matrix.

In particular, the broader conceptual process table above must not be read as an RB1 feature list.

### Current and future post-RB1 canonical

Post-RB1 capabilities may reuse the stable conceptual IDs in this authority when their scientific meaning matches. Each added process or composition still needs its own downstream T1-T14 evidence as applicable.

The current integration branch remains moving. Formal Status-A assessment of a current SWAP5 candidate therefore still requires a frozen exact source/release candidate and evidence reconciliation against that candidate.

## 12. SCI-FOUND-01 closure disposition

F-DOC15 required seven foundation questions. F-DOC16 resolves them at the conceptual-authority layer as follows:

| Foundation question | F-DOC16 disposition |
|---|---|
| Which part of the real soil-plant-atmosphere-hydrological system is represented? | `CLOSED_AT_CONCEPTUAL_FOUNDATION` |
| Why can a 1D column be an admissible abstraction? | `CLOSED_AT_CONCEPTUAL_FOUNDATION`, conditional application test explicit |
| Which processes are resolved, parameterised, forcing/BC, external or out of scope? | `CLOSED_AT_CONCEPTUAL_FOUNDATION` |
| Which assumptions and limitations arise from the abstraction? | `CLOSED_AT_CONCEPTUAL_FOUNDATION` |
| How does a column relate to MultiSWAP, groundwater, tiles and transfer components? | `CLOSED_AT_CONCEPTUAL_FOUNDATION` |
| What are the model-foundation fitness limits? | `CLOSED_AT_CONCEPTUAL_FOUNDATION`; application-specific FFP/validation remains open |
| Are conceptual entities traceable to downstream formal authorities? | `CLOSED_AT_FOUNDATION_EDGE_LEVEL`; process-specific T1-T4 population remains open |

Therefore `SCI-FOUND-01` is closed **only as the missing model-foundation authority**. It does not close F-DOC15's separate gaps for physical-process T0-T7 population, T11 completion, T12 validation, sensitivity, uncertainty, parameter provenance, user guidance or formal WR-QA-2024 reconciliation.

## 13. Status-A effect

After exact-head qualification, F-DOC16 removes `SCI-FOUND-01` itself as the direct blocker from the conceptual-foundation layer of public requirements 1.1, 1.2, 4.5 and 7.1.

Those requirements are **not thereby satisfied**. They remain dependent on the other evidence/documentation gaps identified by F-DOC15, including process-specific theory/formal authority, validation and populated fitness-for-purpose/user guidance.

F-DOC16 does not claim `READY_FOR_FORMAL_STATUS_A_ASSESSMENT`, Status A, Status AA or external audit completion.

## 14. Architecture-invariant review

F-DOC16 was checked against all 30 SWAP5 core invariants. It introduces no production implementation delta and is conceptually aligned with them. The strongest direct bindings are:

- invariants 1, 16, 17 and 28 for one-kernel/many-column composition;
- invariants 9 and 10 for generic time and coupling windows;
- invariants 11-19 for coupling, interface conservation and optional deep-vadose composition;
- invariants 20-23 for separation of physical model from solver implementation and policy;
- invariant 13 for absolute mass conservation;
- invariant 29 for absence of hidden file/day/MODFLOW assumptions.

The 1D scientific abstraction is a physical-system concept; it is not an excuse to reintroduce legacy software boundaries or hidden assumptions.

## 15. Qualification and nonclaims

F-DOC16 is qualified only if the exact branch head passes `.github/workflows/fdoc16-conceptual-foundation.yml` and the validator confirms the bounded authority, source provenance, conceptual IDs, process dispositions, RB1/current separation and all explicit nonclaims.

This authority may be superseded only by an explicit scientific workunit that records the conceptual change and its consequences. It must not be silently rewritten by later implementation work.