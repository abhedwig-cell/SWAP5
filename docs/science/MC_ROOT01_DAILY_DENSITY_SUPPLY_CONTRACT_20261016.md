# Daily adaptive root density and supply composition

Status: implemented candidate; qualification/admission state and raw evidence
are maintained in the existing root-growth/oxygen status record, under
`daily_density_supply_20261016`. PR1251 is the single work PR.
Baseline: `2194651f55881e5aa7ea7ffd3f9e2eebfae952f9`.
Existing SWRD2 modes0/1 and their absent-density defaults remain authoritative.

## Source and ownership

Authenticated B1.11 `MOD_cropdevelopment.f90` owns update_rootextension,
update_wroot_node, update_cumdens, update_cumdens_top and finalize_wroot_node.
Reuse the existing depth, supply and adaptive-profile production components.
SWRDC1 updates shape using daily potential extraction and positive reduction;
finalize_wroot_node then normalizes that shape to the accepted WOFOST root
biomass. The existing raw candidate alone is not that complete source route.
Do not treat a static assigned biomass array as adaptive density evidence.

The existing F-WOF38 crop transaction owns optional nodal root biomass beside
its existing depth and actual/potential crop owners. No second commit owner,
runtime biomass cache or solver policy. Parameters include immutable geometry,
initial density table and adaptive controls. Only committed density feeds the
next real Richards uptake evaluation. Crop growth, death, extension, density
and the consumed water-event receipt publish together or not at all.

## Accepted water evidence

Extend the existing accepted-window lineage with optional nodal potential and
reduction integrals. Bind these to the existing interval certificate, window,
event token, identity and persistence. Contiguous intervals must supply both
arrays consistently, with unchanged shape and finite uncompensated values.
Their sums must match the accepted scalar transpiration and uptake integrals.
Missing, mixed, stale, foreign or duplicate evidence cannot update density.
Default absent arrays preserve all existing routes. Layer values come from
the real existing root-uptake process diagnostics, not an invented spatial split.

## Bounded first envelope

Explicit SWRD2, adaptive density, uncompensated Feddes and existing empirical
oxygen. SWDMI2RD2 uses the actual committed deepest-layer root biomass and
accepted daily drought factor in the existing supply limiter. Potential depth
remains independent of actual water stress. Initialize from authenticated
RDCTB atomically at authentic existing task2 emergence, with no density state
before emergence. Explicit active-crop initialization uses the same initializer.
Exclude zero initial root depth, arbitrary density resets, advanced
oxygen/drought selectors, harvest/rotation composition and native
weather disk codec until specifically qualified. Existing opaque joint restart
must preserve all added state, layer receipt and configuration.

## Verification and admission

Start with direct production O0/O2 tests of source recurrence, finalization,
layer identity, nonfinite inputs, candidate nonmutation and persistence.
Then real daily Richards uptake, growth/death/extension discrimination,
current/lagged events, rejected/stale/duplicate replay and joint restart.
Select only affected owner preservation after stable science. Exact source
guards remain binding and cannot be relaxed to inherit old PASS. No full
moving F-CI or highest low-air run is selected at this development checkpoint.
No capability or master count promotion before actual bounded admission.

The current proportional admission selection is the real39-provider crop and
lineage direct matrix (40 O0/O2 programmes), the233-provider actual daily
Richards matrix (36 programmes, including all28 unchanged incumbent cases),
eight stronger independent nodal-receipt current/lagged and restart executions,
and16 actual INT12-C/WU01/WU03/Black/Boesten/Rutter owner executions. Preserve
the30 original direct and28 original physical stdout identities against their
immutable qualified root capsule, and all16 application stdout identities
against their immutable admitted INT12-C capsule. No original assertion or
physical trajectory is shortened. New source, missing science, missing owner
proof, corrupt capsule and omitted/duplicate matrix entries must refuse proof.

The default source review is bounded to absent adaptive configuration/nodal
payloads and old depth modes0/1. Original production bodies and both original
owner guard bodies are reconstructed byte-for-byte after removing the named
reviewed additions. This structural review alone is not numerical evidence;
fresh changed-physics and unchanged-owner executions remain required. Full
moving F-CI is NOT_SELECTED_AFFECTED_CONTRACTS: this route changes optional
crop/lineage semantics, not the qualified Richards or independent solver
equations. The new owner proof supplements the actual immutable admitted
incumbent rather than claiming a fresh full numerical PASS.
