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

At audit closure, the principal application-level limitation was not the Richards kernel but the absence of a production config-to-owned-FMR bootstrap. **Post-audit PPA-WU01 closes that absence for two explicitly restricted existing profiles:** an already-qualified serialized Reference standalone profile and an all-`bottom_mode=5` groundwater-owner profile that can materialize F-GC49D. **Post-audit PPA-WU03 subsequently closes one bounded common normal-input slice** for precipitation, SWETR=1 reference ET, explicit canopy view and already-resolved surface irrigation under SWINTER=0. Broader meteorological preprocessing/file-calendar ingestion remains open, and the qualification fixture remains qualification-only.

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
| Lower boundary | nonzero prescribed qbot | C | yes, restricted | PPA-WU02-A canonically admits homogeneous typed bottom_mode=2; legacy SWBOTB=2 sine/table and dry continuation remain separate |
| Lower boundary | remaining legacy SWBOTB variants | F | no for remaining families | PPA-WU02 recovered the B1.11 catalogue; remaining gaps are explicit migration slices rather than authority ambiguity |
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
| Application | restricted typed config -> owned FMR runtime/context bootstrap | C | yes, restricted | PPA-WU01; no legacy parser or normal meteo/calendar ingestion |
| MultiSWAP | serialized real-physics runtime | B | yes | only admitted physics families |
| MultiSWAP | restricted parallel real-physics runtime | C | yes, restricted | unsupported physics fails closed; no speedup claim |
| External coupling | F-GC49D generic groundwater application service | C | yes from restricted PPA-WU01 owner or existing context | broader product/input startup remains outside F-GC49D |
| External coupling | actual iMOD Coupler product integration | F | no | upstream driver registration + product-config mapping remain |

The machine-readable register contains, for every row, the legacy authority, SWAP5 implementation authority, typed config authority, state owner, transaction status, qualification evidence, production admission, restrictions, migration risk, use relevance and dependencies.

## What is currently usable as production physics

The current envelope is stronger than the old frozen Status-A summary in several places.

Reference ET is no longer merely a migration candidate. F-CI27 canonically admitted the restricted generic-time reference-ET runtime binding, F-CI29 established ptra ownership, and F-CI31 canonically composed that demand into the restricted Feddes root-uptake execution route.

MultiSWAP is also stronger than the frozen Status-A wording suggests. F-CI30 canonically admitted a restricted parallel real-physics profile, F-CI35 added committed-boundary parallel restart, and the later F-CI37 line added a restricted root-active parallel source path. These admissions remain option-bounded and do not imply that Snow, macropores, thermal physics or every lower boundary can run in parallel.

The groundwater stack is much further than a structural gateway. F-GC33 through F-GC49D provide response semantics, typed MODFLOW6 package binding, live XMI/prepared solve, N:1 aggregation, whole-window acceptance, application plans, participant registries and a production cross-language application context. F-GC44-F-GC47 qualified live MODFLOW6 mixed 1:1/N:1 application shapes. What is missing is the **product/application startup route**, not the entire coupling runtime.

## Largest functional gaps

### 1. Production application bootstrap

**Post-audit status: restricted production route qualified by PPA-WU01.**

`mod_fmr_production_application_bootstrap` now owns typed FMR columns/templates, parameters, already-resolved forcing and committed state. For an all-`bottom_mode=5` groundwater profile it additionally owns the production head-forcing materializers, F-GC49B participant registry, participant handles and interface mass ledgers, and can materialize the existing F-GC49D context without the qualification fixture.

The admitted standalone profile is deliberately the already-qualified serialized Reference `bottom_mode=7` route. The admitted groundwater bootstrap is deliberately the existing mode-5 participant route. Mixed 5/7 ownership fails closed. PPA-WU01 does not provide legacy input parsing, meteorological/calendar ingestion or a broad application grammar.

Evidence and exact restrictions are in `docs/audits/PPA_WU01_PRODUCTION_APPLICATION_BOOTSTRAP.md` and `integration/audits/PPA_WU01_STATUS.json`.

### 2. Complete atmospheric/input composition

The runtime can consume explicit typed effective forcing. Restricted reference ET, PMdirect, Rutter and irrigation bindings exist. Post-audit PPA-WU03 now provides a canonical bounded outer application route for generic-time precipitation, SWETR=1 reference ET, explicit canopy view and already-resolved surface irrigation under SWINTER=0. It remains stateless and keeps file I/O, calendars and cursors outside the physics kernel.

The **complete** atmospheric/input envelope is still open. Legacy weather-file/calendar preprocessing, PMdirect normal-input derivation, Rutter state ownership, SWINTER=1/2, irrigation scheduling and snow/runon ingestion are not implied by PPA-WU03. The remaining work is application-semantics breadth and state ownership, not a reason to redesign the solver.

### 3. Stateful ET and advanced stress physics

PPA-WU04-A is canonically admitted for SWREDU=1 Black. LDWET is an option-discriminated committed process state, rejected candidates cannot mutate it, changed-dt retries re-evaluate from the same checkpoint, restart preserves it exactly, and accepted actual evaporation remains owned by the hydraulic dynamic-top boundary.

PPA-WU04-B has now qualified SWREDU=2 Boesten-Stroosnijder for the bounded production profile `0 < COFRED <= 1`. SPEV/SAEV form one atomic committed/restart pair, retries recompute from the same checkpoint, and the exact drying, rewetting and ponding branches are source-qualified. The legacy `COFRED=0` edge remains outside the admitted envelope because the exact inverse branch can divide by zero.

SWINTER=1/2 remain open because their source-window aggregate/progress semantics are distinct from both evaporation-reduction methods.

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
5. **The external-coupling blocker remains mainly above the physics runtime, but one prerequisite is now narrower.** PPA-WU01 supplies a restricted internal SWAP5 production owner/context bootstrap. Actual iMOD Coupler product startup still requires an authorized upstream driver-extension route and an explicit product-config mapping into an admitted PPA-WU01 profile.

## Dependency-aware backlog

### Almost free to make more production-reachable

**Prescribed qbot** is the clearest case. F-SI38/F-MR44R provide qualified restricted runtime evidence, but F-MR44R remains explicitly non-canonical. A bounded admission can be low-science-risk if it preserves the exact source and does not pretend that all legacy SWBOTB selectors are now mapped.

The **canonical result serializer** is already admitted and state-free. Wiring it into a future application bootstrap is low risk as long as output-file formats are kept out of that workunit.

### Important missing routes with low scientific uncertainty

PPA-WU01 has now closed the absence of any production bootstrap for the restricted admitted profiles, with Fortran/FMR ownership and no new physics.

PPA-WU03 has closed the first **bounded common outer forcing/config adapter** slice while preserving kernel I/O separation. The remaining application-completeness work is to broaden ingestion only through separate evidenced slices, especially legacy file/calendar preprocessing, PMdirect normal-input derivation and stateful interception/management routes.

In parallel, the **lower-boundary application map** remains high value. Recover the exact B1.11 mode catalogue first, then migrate common modes as small independent slices.

Fourth is **accepted-result/output composition**. Full legacy output compatibility is useful, but should follow a stable application/result vocabulary rather than drive physics design.

### Important routes requiring scientific review first

- SWINTER=1/2 because their nonlinear source-window aggregate provenance and mid-window restart semantics still require dedicated qualification;
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

**PPA-WU01, Production application bootstrap for an admitted normal-run profile. CLOSED / QUALIFIED RESTRICTED PRODUCTION.** The Fortran/FMR owner now reaches the existing serialized Reference standalone runtime without fixtures and materializes F-GC49D for the existing mode-5 groundwater profile. O0/O2 qualification and output identity passed in run 35365440351. Broad input/application composition remains outside WU01.

**PPA-WU02, Source-bound lower-boundary application-envelope inventory. CLOSED / CANONICAL ADMITTED.** The B1.11 SWBOTB catalogue is source-bound, common-mode H authority ambiguity is closed, and PPA-WU02-A canonically admits homogeneous typed prescribed qbot via PR #324 at `013c549686a8f310834ddb3e8d1270166f8283f1`. Legacy SWBOTB=2 sine/table forcing and dry continuation plus selectors 1, 3, 4, standalone 5 and 8 remain explicit follow-on slices.

**PPA-WU03, Atmospheric forcing and normal-input adapter boundary. CLOSED / CANONICAL ADMITTED.** PR #323 merged at `97c4471155001e12133109be5eb6bd95f799eb00`. The admitted slice covers generic-time precipitation, SWETR=1 reference ET, explicit canopy view and no/already-resolved surface irrigation under SWINTER=0, with only pure-flux dynamic-top handoff to PPA-WU01. File/calendar grammar, PMdirect ingestion, Rutter state ownership and broader management ingestion remain outside the workunit.

**PPA-WU04, Stateful ET/interception scientific review. CLOSED / AUTHORITY FROZEN.** The parent review froze SWINTER=1/2 and SWREDU=1/2 state, event, restart and rollback semantics from B1.11. **PPA-WU04-A, SWREDU=1 Black: CANONICAL ADMITTED RESTRICTED PRODUCTION.** PR #395 merged as `50e7d1dece5b75d0103459d5c118d03a2665eea3`. **PPA-WU04-B, SWREDU=2 Boesten-Stroosnijder: QUALIFIED / READY FOR CANONICAL ADMISSION.** Workflow 35439112147 passed exact equations, atomic SPEV/SAEV rollback/restart, changed-dt retry, hard mass and predecessor-preservation gates. PPA-WU04-C/D remain the open interception slices.

**PPA-WU05, Advanced water-process triage.** Build the dependency graph and acceptance criteria for macropore, frost and advanced root-stress migration, then select the first high-use bounded target. No production physics should be migrated inside the triage unit.

## Closeout

The requested major SWAP4.3.1 hydrological subsystems have been classified. The audit does not claim full legacy option enumeration where the repository does not support it; those cases are explicitly marked H or grouped as F rather than inferred from filenames.

The main conclusion is that SWAP5's numerical and transactional core is no longer the dominant production-envelope gap. The dominant gap is **application composition around that core**, followed by a smaller set of scientifically stateful legacy process families: advanced ET/stress, macropores, frost, hysteresis, full management/tillage and the now-enumerated but not-yet-migrated lower-boundary remainder.

This audit changes documentation/evidence only. No production source, solver, physics, ROM, reference source or scientific tolerance is modified.


## Post-audit update: PPA-WU01

PPA-WU01 was executed after this gap audit and is tracked as a bounded post-audit closure, not as a reinterpretation of the original evidence baseline.

Qualified source head: `92181c96486c7d49ac1d6cd19a7236f1dcf204b7`  
Qualification workflow run: `35365440351`  
Qualification job: `105666642389`

The workunit closes the former **absence of any production config-to-owned-FMR owner** for its restricted typed profiles. It does not close the broader normal-application envelope. PPA-WU03 has since closed one bounded common atmospheric/input slice; broader meteorological preprocessing remains open. PPA-WU02 remains the authority-recovery route for the broader lower-boundary catalogue.


## Post-audit update: PPA-WU03

PPA-WU03 is canonically admitted and closed through PR #323 at merge commit `97c4471155001e12133109be5eb6bd95f799eb00`.

Qualified production subject: `74b3bcbfffc6efe7125e39e1c6052dd130e2a42d`  
Qualification workflow run: `35374130545`  
Owner job: `105694706631` PASS  
Independent job: `105694706401` PASS, 54 cases  
Preservation job: `105694706721` PASS

The admitted capability is intentionally narrower than the complete legacy meteorological route. A stateless outer adapter maps generic real-valued interval input for precipitation, SWETR=1 reference ET, explicit canopy view and no/already-resolved surface irrigation under SWINTER=0 into existing typed contracts. A read-only forcing seam lets the existing PPA-WU01 owner execute changing interval forcing without transferring FMR, committed-state, transaction, timestep or retry ownership.

The canonical nonclaims remain: no legacy weather-file grammar or calendar/date ingestion, no PMdirect normal-input derivation, no Rutter canopy-state ownership, no SWINTER=1/2, no irrigation scheduling/management parser, no snow/runon ingestion, and no dynamic-top head/ponding/runoff pre-resolution into the PPA-WU01 fixed-flux route.


## Post-audit update: PPA-WU02

PPA-WU02 completed the exact B1.11 lower-boundary selector inventory and removed the prior common-mode H authority ambiguity. After reconciling the shared production-bootstrap surface with canonical PPA-WU03, head `eff8670a2614f72d34016dbfc7eba040c940c245` passed owner and independent qualification in workflow `35374976662`, plus PPA-WU01 preservation. PR #324 merged at `013c549686a8f310834ddb3e8d1270166f8283f1`.

The admitted delta is deliberately narrow: homogeneous typed `bottom_mode=2` with already-resolved prescribed qbot through the existing production application owner. It does not admit the legacy SW2 sine/table materializer, DATE2/QBOT2 parser, oven-dry 2-to--2 continuation, or remaining selector families.


## Post-audit update: PPA-WU04-A

PPA-WU04-A qualifies the restricted SWREDU=1 Black production path on source head `f1fd0fa5633cea1fa5f3870eb2aa7b236d40a938`.

Qualification workflow run: `35438366101`  
Qualification job: `105884808295` PASS

The slice introduces no new water-mass owner. `EMPREVA` remains a demand, while the existing dynamic hydraulic top boundary determines and accounts accepted actual evaporation. The only new persistent process state is `LDWET`, carried in an option-discriminated transaction/restart family.

The workunit does not admit SWREDU=2, SWINTER=1/2, legacy weather/calendar parsing, snowmelt/runon Black composition, groundwater mode-5 Black composition or RossFast Black composition.


## Post-audit update: PPA-WU04-B

PPA-WU04-B qualifies the restricted SWREDU=2 Boesten-Stroosnijder production path on source head `eb0e635975b77ec92084e1416038b1bc1f8232bc`.

Qualification workflow run: `35439112147`  
Qualification job: `105886744366` PASS

The admitted process continuation is the atomic SPEV/SAEV pair. Accepted actual evaporation remains owned and mass-accounted by the existing dynamic hydraulic top boundary. The production envelope deliberately requires `0 < COFRED <= 1`; the legacy zero case is not reinterpreted.

With WU04-A and WU04-B complete, the remaining PPA-WU04 implementation work is the source-window interception pair WU04-C/D.
