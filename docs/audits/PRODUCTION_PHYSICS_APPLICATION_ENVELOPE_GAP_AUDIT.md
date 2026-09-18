# Production Physics & Application Envelope Gap Audit

**Audit date:** 2026-09-18  
**Repository:** `abhedwig-cell/SWAP5`  
**Canonical basis:** `integration/f-ci-canonical@71626be59b81d00a3fd6a5d5a561febe9b5023b8`  
**Reference authority:** corrected SWAP 4.3.1 B1.11  
**Machine-readable register:** `integration/audits/production_physics_application_envelope_gap_register.json`

## Decision

SWAP5 already has a substantial typed, transactional production runtime, but it does **not** yet expose the full SWAP 4.3.1 application envelope as a normal production application.

The strongest current production envelope is:

- mandatory typed Reference-Richards soil-water execution with transaction/retry/rollback semantics;
- typed dynamic top boundary with precipitation, irrigation, snowmelt, runon, evaporation, ponding and a restricted linear-runoff route;
- restricted reference-ET and PMdirect demand routes;
- restricted Feddes drought-only root uptake;
- bounded WOFOST81 runtime;
- drainage-v1 and restricted fixed-weir surface-water storage;
- restricted one-day Snow;
- restricted sensible soil-temperature conduction without frost/phase change;
- committed-boundary Restart;
- serialized and restricted parallel real-physics MultiSWAP;
- a generic typed groundwater application service through F-GC49D, including live MODFLOW6 qualification in bounded topologies.

The principal application-level limitation is not the Richards kernel. It is the gap between **admitted typed components** and a **normal application bootstrap/configuration path**. F-GC49D can operate an already existing FMR application context, but F-GC50 confirms there is no admitted production `create_context_from_config`-type owner and the qualification fixture may not be promoted. The same gap limits ordinary standalone use of otherwise admitted physics.

No production source was changed by this audit.

## Audit rule

A source file, type or test does not by itself make a capability production-reachable.

For this audit, a capability counts as production-reachable only if the evidence chain establishes:

`application/config ownership -> typed input/config -> runtime execution -> state ownership -> transaction semantics -> qualification -> production admission`.

When a route is production-admitted only for a narrow profile, or depends on caller-supplied already-resolved typed values rather than a normal broad application bootstrap, it is classified as **C, SWAP5_RESTRICTED_PRODUCTION**, not B.

The controlled classifications are:

- **A LEGACY_PRESENT**: legacy capability is established, but no stronger SWAP5 disposition can be made;
- **B SWAP5_TYPED_PRODUCTION**: complete typed production route inside the stated capability scope;
- **C SWAP5_RESTRICTED_PRODUCTION**: admitted production route with explicit option/profile/application restrictions;
- **D QUALIFICATION_ONLY**: implemented/qualified, but canonical production admission or normal application reachability is missing;
- **E PRESERVED_BUT_NOT_TYPED**: preserved through a reference/legacy execution path but not owned by a typed production route;
- **F NOT_YET_MIGRATED**: relevant capability lacks a complete typed production route;
- **G INTENTIONALLY_EXCLUDED**: explicitly outside the SWAP5 target;
- **H AUTHORITY_UNCLEAR**: repository evidence is insufficient to resolve exact semantics without overclaiming.

All rows also carry a separate `legacy_present` field in the machine-readable register. This avoids treating “legacy present” as mutually exclusive with B-F.

## Authority reconciliation

The audit started from canonical `73bd6571de1c7f17a34417d407b14075d58b8798`, the F-GC50 merge. During the audit canonical advanced by seven commits to `71626be59b81d00a3fd6a5d5a561febe9b5023b8`. The delta is confined to `docs/publication/PUB_GC_*` E4 publication evidence. It does not touch `src/`, `reference/`, capability admission records or the audit dependency surface. The audit is therefore bound to the later head without reopening traced production evidence.

The legacy authority is not inferred from filenames alone. The B0 manifest pins the exact 63-member SWAP 4.3.1 source archive, while B1.11 pins the corrected executable reference and its expected-difference ledger. Relevant source authorities include `MOD_meteo.f90`, `boundtop.f90`, `boundbottom.f90`, `rootextraction.f90`, `oxygenstress.f90`, `RWU_micro.f90`, `drainage.f90`, `divdra.f90`, `surfacewater.f90`, `macropore.f90`, `snow.f90`, `temperature.f90`, `frozencond.f90`, `hysteresis.f90`, `solute.f90`, `irrigation.f90`, `management_soil.f90`, `tillage.f90`, `soilwater.f90` and the WOFOST sources.

B1.11 is also relevant to migration risk. It contains admitted corrections for macropore array shape, PDI hydraulics, model-7 capacity, inverse retention, tillage start-state selection and model-specific Richards Jacobian derivatives. Two tillage findings, SWAP-003 and SWAP-004, remain outside B1 as confirmed but unresolved findings. A tillage migration is therefore not a low-risk transcription task.

## Capability inventory

| Subsystem | Capability | Class | Production reachability | Main restriction / gap |
| --- | --- | --- | --- | --- |
| Atmospheric forcing | resolved effective forcing | C | restricted typed caller route | no normal meteo-file/application bootstrap |
| Atmospheric forcing | complete legacy weather preprocessing | F | no | file/calendar/cursor semantics not migrated |
| Dynamic top | atmosphere/flux/ponding/linear runoff switching | C | yes, restricted | nonlinear active runoff outside admitted profile |
| Interception | SWINTER=0 | C | yes, restricted | Hupsel-qualified composition |
| Interception | SWINTER=3 Rutter | C | yes, restricted | no broad normal application config |
| Interception | SWINTER=1/2 | F | no | readiness only |
| Reference ET | SWETR=1 reference-ET demand | C | yes, restricted | stateless restricted option set |
| Reference ET | SWETR=0 PMdirect | C | yes, restricted | resolved Hupsel inputs, not generic meteo route |
| Evaporation | SWREDU=1/2 persistent reduction | F | no | continuation state and retry semantics need review |
| Evaporation | actual hydraulic surface evaporation | C | yes, restricted | excludes SWREDU continuation-state routes |
| Crop | WOFOST81 daily crop-event runtime | C | yes, restricted | bounded N-unlimited route; no RD/TRA/Soil-N expansion |
| Root uptake | Feddes drought-only, precomputed QROT | C | yes, restricted | advanced stress families excluded |
| Root/stress | oxygen, salinity, frost, compensation, MICRO/JvL/macropore | F | no | shared state/physics not migrated |
| Soil water | Reference Richards production core | B | yes | surrounding process envelope still restricted |
| Lower boundary | SWBOTB=6 zero flux | C | yes, restricted | only selector 6 mapped |
| Lower boundary | nonzero prescribed qbot | D | not as normal application route | F-MR44R qualified but not canonically admitted |
| Lower boundary | other legacy SWBOTB variants | H | no | complete selector/semantic inventory absent |
| Groundwater | typed head/exchange/coupling route | C | yes, restricted | bounded forcing/timestep/physics envelope |
| Drainage | drainage-v1 family | C | yes, restricted | no fully implicit drainage; parallel DIVDRA restrictions |
| Surface water | fixed-weir storage route | C | yes, restricted | not complete surface-water family |
| Surface | ponding/runoff/runon top response | C | yes, restricted | linear active-runoff profile only |
| Macropore | legacy macropore flow | F | no | state/mass/restart/parallel envelope absent |
| Snow | one-call-per-day Snow | C | yes, restricted | no subdaily/multiday active Snow |
| Thermal | sensible soil-temperature conduction | C | yes, restricted | no frost, latent heat or snow+temperature composition |
| Frost | frozen-water/phase-change hydraulic feedback | F | no | coupled thermal-water state absent |
| Hysteresis | hydraulic hysteresis | F | no | no typed state/runtime authority |
| Solute-hydraulic | salinity/solute state affecting water/root execution | F | no | no typed production composition |
| Irrigation | fixed surface + TCS1/DCS2 sprinkling | C | yes, restricted | no TCS7/SSDI, no generic management parser |
| Irrigation | other legacy modes | F | no | process fragments do not form an admitted app route |
| Tillage | tillage event/state route | F | no | SWAP-003/004 unresolved in reference governance |
| Management | complete management/calendar route | F | no broad route | bounded WOFOST event lifecycle is not full management |
| Restart | committed-boundary restart | B | yes | no mid-transaction or stable file-format claim |
| Output | canonical typed result serialization | C | yes, restricted | no legacy output-family equivalence |
| Output | full legacy output family | F | no | formats and report composition not migrated |
| Application | normal config -> owned FMR context bootstrap | F | no | central application-envelope blocker |
| MultiSWAP | serialized real-physics runtime | B | yes | only admitted physics families |
| MultiSWAP | restricted parallel real-physics runtime | C | yes, restricted | unsupported physics fails closed; no speedup claim |
| External coupling | F-GC49D generic groundwater application service | C | yes from existing context | no production context bootstrap |
| External coupling | actual iMOD Coupler product integration | F | no | upstream registration + bootstrap blockers |

The machine-readable register contains, for every row, the legacy authority, SWAP5 implementation authority, typed config authority, state owner, transaction status, qualification evidence, production admission, restrictions, migration risk, use relevance and dependencies.

## What is currently usable as production physics

The current envelope is stronger than the old frozen Status-A summary in several places.

Reference ET is no longer merely a migration candidate. F-CI27 canonically admitted the restricted generic-time reference-ET runtime binding, F-CI29 established ptra ownership, and F-CI31 canonically composed that demand into the restricted Feddes root-uptake execution route.

MultiSWAP is also stronger than the frozen Status-A wording suggests. F-CI30 canonically admitted a restricted parallel real-physics profile, F-CI35 added committed-boundary parallel restart, and the later F-CI37 line added a restricted root-active parallel source path. These admissions remain option-bounded and do not imply that Snow, macropores, thermal physics or every lower boundary can run in parallel.

The groundwater stack is much further than a structural gateway. F-GC33 through F-GC49D provide response semantics, typed MODFLOW6 package binding, live XMI/prepared solve, N:1 aggregation, whole-window acceptance, application plans, participant registries and a production cross-language application context. F-GC44-F-GC47 qualified live MODFLOW6 mixed 1:1/N:1 application shapes. What is missing is the **product/application startup route**, not the entire coupling runtime.

## Largest functional gaps

### 1. Production application bootstrap

This is the most consequential gap because it sits above many already-admitted components.

`mod_fmr_soil_water_application_host` owns generic model selection, but not complete user configuration. F-GC49D exposes an existing registered Fortran application context through a handle. It deliberately does not expose a production context constructor. F-GC50 verified that the test fixture is qualification-only and may not be promoted.

Until a production bootstrap exists, SWAP5 has a strong typed runtime but a narrower normal-application envelope than its collection of production modules suggests.

### 2. Complete atmospheric/input composition

The runtime can consume explicit typed effective forcing. Restricted reference ET, PMdirect, Rutter and irrigation bindings exist. The missing piece is the complete outer application route that turns ordinary forcing/configuration into those typed values while keeping file I/O, calendars and cursors outside the physics kernel.

This is primarily an application-semantics and ownership gap, not a reason to redesign the solver.

### 3. Stateful ET and advanced stress physics

SWREDU=1/2 are important because their legacy continuation variables are real restart state. F-PM06 also identifies a legacy control-flow hazard: those states are mutated before the SoilWater retry loop. SWAP5 must preserve the equations while making trial-state mutation transactional.

Advanced root stress is a larger scientific block. Oxygen, salinity, frost, compensated uptake, MICRO/Jong-van-Lier and macropore uptake interact with distinct state owners and, for coupled groundwater response, derivative coverage.

### 4. Macropore flow

Macropore code is present in the corrected reference, including an admitted B1 correction, but no typed production macropore state, mass, restart and parallel route exists. This is a large state-topology migration rather than a small process plug-in.

### 5. Complete lower-boundary and management envelopes

Zero flux and the explicit groundwater coupling route are available. Nonzero prescribed qbot has qualified source evidence but not canonical normal-application admission. For the remaining historical SWBOTB modes, the current repository does not contain a complete evidenced selector-to-typed map. The audit therefore records **H**, rather than guessing.

Likewise, fixed/scheduled irrigation and bounded WOFOST are real production routes, but full legacy management, other irrigation modes and tillage are not.

## Surprising findings

The audit produced five findings that are easy to miss when reading only the Status-A portal.

1. **Parallel MultiSWAP is already a production capability, but only in a restricted profile.** The old Status-A wording that placed concurrent real-physics MultiSWAP in future scope is no longer a complete description of current canonical.
2. **Reference-ET to root uptake is already canonically composed.** The current gap is breadth of ET/stress options and application startup, not absence of the basic ptra-to-Feddes chain.
3. **Sensible soil temperature is production-admitted while frost is not.** Treating “temperature exists” as evidence for frozen-water physics would be incorrect.
4. **The top boundary already owns real ponding/runoff state and routing logic.** The missing surface-water scope is broader variants, not absence of all runoff/ponding physics.
5. **The external-coupling blocker is now mainly above the physics runtime.** F-GC50 found two concrete product-startup prerequisites: an authorized iMOD Coupler driver extension route and an admitted SWAP5 context bootstrap.

## Dependency-aware backlog

### Almost free to make more production-reachable

**Prescribed qbot** is the clearest case. F-SI38/F-MR44R provide qualified restricted runtime evidence, but F-MR44R remains explicitly non-canonical. A bounded admission can be low-science-risk if it preserves the exact source and does not pretend that all legacy SWBOTB selectors are now mapped.

The **canonical result serializer** is already admitted and state-free. Wiring it into a future application bootstrap is low risk as long as output-file formats are kept out of that workunit.

### Important missing routes with low scientific uncertainty

Highest value is the **production application bootstrap** for already-admitted profiles. It should create and own FMR state on the Fortran/runtime side, not in Python, and should not expand physics.

Second is the **outer forcing/config adapter** for common normal applications. This should translate ordinary forcing/configuration to existing typed ET/interception/top-boundary inputs while preserving the current kernel I/O separation.

Third is the **lower-boundary application map**. Recover the exact B1.11 mode catalogue first, then migrate common modes as small independent slices.

Fourth is **accepted-result/output composition**. Full legacy output compatibility is useful, but should follow a stable application/result vocabulary rather than drive physics design.

### Important routes requiring scientific review first

- SWREDU=1/2 because of persistent empirical state and legacy retry-control mutation;
- advanced root stress because multiple stateful stress mechanisms and coupling derivatives intersect;
- macropore flow because state topology, mass, restart and parallelism all change;
- frost because phase change couples hydraulic and thermal state and acceptance semantics;
- tillage because the corrected reference still carries unresolved SWAP-003 and SWAP-004 decisions.

### Routes that can wait

Hysteresis should remain behind normal application startup, common lower boundaries and high-use ET/root functionality unless concrete usage justifies reprioritization.

SWINTER=1/2 and less common irrigation modes can also wait behind the common forcing/application boundary, unless usage evidence shows they are needed by a target production case.

### Routes intentionally excluded

ROM is completely outside this audit.

Qualification fixtures are not candidates for production bootstrap. F-GC50 explicitly establishes that boundary.

Legacy B0 bug compatibility is also excluded by reference policy. Migration targets corrected B1 semantics or a separately qualified model change, not reproduction of known defects.

## Parallel versus serial work

Several next activities are ownership-disjoint enough to proceed in parallel:

- lower-boundary source inventory and output mapping;
- macropore scientific review and tillage reference review;
- hysteresis review and the inventory of non-F-APP07 irrigation modes;
- the SWAP5 production-bootstrap contract and an external upstream iMOD Coupler extension effort, provided both keep the already-fixed ownership boundary.

Other work must be serialized because it shares physical state or semantic ownership:

- application bootstrap before any broad “legacy parser” claim;
- SWINTER=1/2 and SWREDU=1/2 around ET/interception state ownership;
- frost with Snow plus soil-temperature composition;
- advanced root stress with solute/frost state and groundwater derivative coverage;
- macropore implementation with mass, restart and parallel state-topology changes;
- lower-boundary selector migration with groundwater application mapping where the same selector semantics are touched.

## Proposed next bounded workunits

**PPA-WU01, Production application bootstrap for an admitted normal-run profile.** Establish one authoritative config-to-FMR-context owner using only already-admitted physics. Exit when a normal standalone application profile reaches the canonical runtime without qualification fixtures. Do not add a legacy parser or new physics in this unit.

**PPA-WU02, Source-bound lower-boundary application-envelope inventory.** Recover the exact B1.11 SWBOTB mode catalogue and classify every mode against current typed runtime authority. Exit when common lower-boundary modes no longer sit under H authority ambiguity and later migration slices have frozen scientific authorities.

**PPA-WU03, Atmospheric forcing and normal-input adapter boundary.** Define the outer application ingestion route from normal precipitation/reference-ET/canopy inputs to the existing typed processes. Keep calendar/file/cursor ownership outside the kernel. Exit with one common forcing profile driving PPA-WU01 end-to-end without new physics.

**PPA-WU04, Stateful ET/interception scientific review.** Re-derive SWINTER=1/2 and SWREDU=1/2 state, event, restart and rollback semantics from B1.11. This should be a review/authority unit, not an implementation unit.

**PPA-WU05, Advanced water-process triage.** Build the dependency graph and acceptance criteria for macropore, frost and advanced root-stress migration, then select the first high-use bounded target. No production physics should be migrated inside the triage unit.

## Closeout

The requested major SWAP4.3.1 hydrological subsystems have been classified. The audit does not claim full legacy option enumeration where the repository does not support it; those cases are explicitly marked H or grouped as F rather than inferred from filenames.

The main conclusion is that SWAP5's numerical and transactional core is no longer the dominant production-envelope gap. The dominant gap is **application composition around that core**, followed by a smaller set of scientifically stateful legacy process families: advanced ET/stress, macropores, frost, hysteresis, full management/tillage and the unenumerated lower-boundary remainder.

This audit changes documentation/evidence only. No production source, solver, physics, ROM, reference source or scientific tolerance is modified.
