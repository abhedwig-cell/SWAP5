# F-PM06B Restricted Surface Evaporation & Top-Boundary Readiness

## Purpose

F-PM06B decomposes the smallest remaining evapotranspiration-to-soil-water boundary under the already restricted baseline:

- `SWINTER = 0`;
- `SWREDU = 0`;
- reference ET demand already supplied by the canonical F-PM06A/F-CI24 family;
- no interception state;
- no empirical soil-evaporation memory;
- no new root-uptake physics;
- no production implementation in this workunit.

The target is the ownership seam for **actual bare-soil evaporation** and **actual pond evaporation**. Potential demand stays ET-owned. Actual removal stays surface-hydraulic/top-boundary-owned.

## Source authority

Current canonical source authority at activation:

`integration/f-ci-canonical@c0fc660c1e68064f77f4ec4f3376d385fbe88b4a`

The canonical movement from the final F-CI34 status head to this authority contains no `src/` delta. It is F-CI35 parallel-restart governance/capability continuation, so the ET/top-boundary sources listed in `F-PM06B_SOURCE_LOCK.json` remain byte-identical.

Frozen B1.10 source identity is recorded in `F-PM06B_SOURCE_LOCK.json`.

## Legacy restricted equations and regime selection

The B1.10 `BoundTop` path establishes that potential ET demand is not itself an accepted water sink.

For the top surface, B1.10 first derives an atmospheric hydraulic evaporation capacity. With `hatm = -2.75e5 cm`, top-surface conductivity `ksurf`, top-node conductivity `k(1)`, top half-node distance and the configured conductivity mean, the relevant legacy relation is:

`Emax = -k1Atm * ((hatm - h(1)) / disnod(1) + 1)`

where `k1Atm` is the hydraulic mean between atmospheric-surface and top-node conductivities. Frost and, when enabled, macropore matrix fraction enter the hydraulic-side conductivity calculation. Those details belong to the hydraulic owner, not to ET.

The restricted evaporation partition is then:

1. if previous accepted ponding `pondm1 > 1e-10 cm`:
   - `reva = 0`;
   - `epd = epond`;
2. otherwise, for `SWREDU = 0`:
   - `reva = min(peva, max(0, Emax))`;
   - `epd = 0`.

The net atmospheric/surface forcing is subsequently composed with precipitation, irrigation, snowmelt, runon and the two evaporation components. The top boundary then selects a flux or head regime and may form ponding/runoff. Therefore `reva` cannot safely be computed as a standalone ET sink before the hydraulic boundary decision.

## Ownership decision

### ET atmospheric-demand owner

Owns only potential/reference quantities, including:

- `peva`, potential bare-soil evaporation demand;
- `epond`, potential pond-water evaporation demand;
- `ptra`, potential transpiration demand.

These are trial inputs/results. They do not book water.

### Surface-hydraulic/top-boundary owner

Owns:

- atmospheric hydraulic evaporation capacity;
- dry-surface versus ponded-surface regime;
- `actual_soil_evaporation` corresponding to legacy `reva`;
- `actual_pond_evaporation` corresponding to legacy `epd`;
- net top boundary flux;
- surface head / candidate ponding interaction;
- runoff interaction where enabled.

Only the accepted transaction may turn these trial results into authoritative mass/result receipts.

### Soil-water solver

Consumes a clean top-boundary contract and solves the soil-water state. Other process modules must not read HeadCalc arrays, Newton vectors, Jacobians or solver globals.

## Why the current canonical top-boundary contract is insufficient

The canonical `top_boundary_provider_t` currently receives:

- top pressure head;
- top water content;
- `soil_water_boundary_conditions_t` containing only generic top/bottom flux/head values.

It returns only:

- `actual_top_flux`;
- `surface_head`;
- `runoff_flux`.

The current fixed-flux provider simply returns `requested%top_flux` and therefore cannot reproduce the B1.10 atmospheric evaporation boundary.

This interface lacks explicit fields for:

- potential soil evaporation demand;
- potential pond evaporation demand;
- accepted/base ponding depth for the trial;
- external liquid-input composition needed by the atmospheric boundary;
- generic interval duration needed for surface storage/runoff accounting;
- actual soil-evaporation component;
- actual pond-evaporation component;
- candidate ponding/surface-storage contribution;
- a clean hydraulic evaporation-capacity capability.

Adding hidden mutable fields such as `last_reva` or `last_epd` to a provider is explicitly rejected. A nonlinear solver may evaluate a boundary provider repeatedly, retries may be rejected, and MultiSWAP workers may execute concurrently. Trial output must be returned explicitly and remain worker-local until accepted.

## Required structural contract for a later candidate

F-PM06B does not prescribe final Fortran names, but any structural candidate must separate the following logical data.

### Immutable physical parameters

Surface/top-boundary parameter references only, for example atmospheric limiting head, surface geometry and relevant runoff/ponding configuration. Existing immutable soil and hydraulic parameter sets remain shared by ID/reference.

### Forcing/process inputs

A typed trial request should be able to carry, directly or through typed views:

- potential soil evaporation demand;
- potential pond evaporation demand;
- liquid input rates relevant to the top boundary;
- event/source provenance;
- generic `[t0,t1]` duration.

No files, records, day counters or parsing state belong here.

### Read-only committed/base state

At minimum:

- base ponding depth;
- top soil hydraulic state through an accepted hydraulic interface.

The surface process does not duplicate soil-water or ponding state.

### Worker scratch

Hydraulic means, `Emax`, regime booleans and trial algebra are scratch. They are not persistent column state.

### Explicit trial result

A later common top-boundary result must make the physically relevant partition observable without provider-global mutation. At minimum it must be possible to recover:

- net actual top flux;
- actual soil evaporation;
- actual pond evaporation;
- runoff flux where applicable;
- surface head / candidate ponding information required by the solver;
- diagnostics identifying the boundary regime and any hydraulic limitation.

## Hydraulic capability boundary

The ET process must not reconstruct `Emax` from raw `h(1)`, `K(1)`, Jacobian state or HeadCalc internals.

Two implementation families remain architecturally admissible for the later structural work:

1. the common top-boundary provider owns the hydraulic capacity evaluation through a clean constitutive/hydraulic capability supplied by the soil-water implementation;
2. the soil-water implementation supplies a typed `surface_evaporation_capacity` capability/result to the boundary process.

The qualification requirement is behavior and ownership, not one specific class layout. In both cases alternative soil-water solvers remain behind the common soil-water interface.

A raw extension of `process_hydraulic_view_t` with solver-internal conductivity arrays is not acceptable.

## Mass contribution contract

Potential quantities `peva` and `epond` never enter the authoritative mass ledger directly.

For an accepted interval, the surface/top-boundary owner must satisfy one coherent water partition. The solver-returned external top flux remains the authoritative soil-column top exchange. Surface-component receipts may attribute that exchange, but may not book the same water a second time.

Rejected trials contribute zero authoritative:

- soil evaporation;
- pond evaporation;
- runoff;
- ponding mutation;
- mass-ledger entry.

If a future runtime publishes `actual_soil_evaporation` or `actual_pond_evaporation`, publication must be bound to the exact accepted candidate/forcing lineage, following the same lesson as F-VQ48/F-MR31: no post-hoc re-pairing of a committed candidate with a different valid demand/forcing object.

## Generic-time contract

No day is fundamental.

Boundary evaluation is over a generic trial span `[t0,t1]`. The duration is explicit. Atmospheric forcing validity, precipitation events, irrigation events, snow events, runoff events and reporting windows may introduce their own boundaries.

The B1.10 use of `dt` in ponding/runoff algebra is physical interval duration, not evidence that the kernel step is daily.

## Transaction contract

A later implementation must support:

`checkpoint -> trial/retry -> commit or rollback`

Rules:

- base ponding and soil state are read-only during a trial;
- all evaporation partition and boundary-regime calculations are trial-local;
- retry starts from the same committed physical state unless a committed step has occurred;
- rejected trial results are discarded;
- accepted candidate state changes once;
- accepted mass/result receipts are emitted once;
- no provider-global `save` state or last-result cache may act as continuation authority.

## Optionality

Within this restricted candidate, no new persistent ET state is justified.

Later options remain separate:

- `SWINTER = 1/2/3` may introduce interception aggregates/state;
- `SWREDU = 1` owns `ldwet` only when active;
- `SWREDU = 2` owns `spev/saev` only when active;
- special runoff/macropore/snow interactions are separate qualification slices where needed.

Inactive options must not enlarge every column state.

## Current canonical gap

Canonical SWAP5 already contains:

- the restricted reference ET-demand process;
- runtime ET-demand binding;
- authoritative `ptra` binding;
- restricted root-uptake composition;
- accepted actual-transpiration attribution;
- a generic fixed-flux top-boundary provider.

It does **not** yet contain a B1.10-equivalent atmospheric surface boundary that owns the `peva/epond -> reva/epd -> top boundary regime` transition.

This is the next missing restricted ET migration seam.

## Migration slices after F-PM06B

Recommended order:

1. **Structural top-boundary request/result candidate**
   - typed demand/input/result partition;
   - no stateful SWREDU or SWINTER;
   - no provider-global result mutation.
2. **Restricted B1.10 atmospheric surface-boundary physics**
   - `SWINTER=0`, `SWREDU=0`;
   - hydraulic `Emax` equivalence;
   - dry/ponded partition;
   - flux/head regime equivalence;
   - hard mass balance.
3. **Runtime composition and accepted result attribution**
   - exact forcing/candidate binding;
   - no second mass booking.
4. Only then qualify optional interception and soil-evaporation-reduction families in separate workunits.

Do not combine slices 1 through 4 into one production branch.

## Invariant audit

1. One kernel: PASS, no alternate ET kernel proposed.
2. Kernel separate from I/O: PASS.
3. Explicit data separation: PASS, demand/state/forcing/result/scratch separated.
4. Compact persistent state: PASS, restricted slice adds none.
5. Scratch per worker: PASS, `Emax` and regime algebra remain scratch.
6. Scalable layout: PASS, no object-per-column heavy solver state required.
7. Transactional timesteps: PASS by contract.
8. Cheap replay/warm start: PASS, no trial mutation of committed surface state.
9. Generic time: PASS.
10. Flexible coupling windows: PASS, no midnight/day assumption.
11. Coupling is core: PASS, boundary/result contract remains transaction-compatible.
12. Groundwater interface: NOT AFFECTED.
13. Mass conservation: PASS as hard requirement; no double booking allowed.
14. Interface sensitivities: NOT AFFECTED.
15. Coupling cost: NOT AFFECTED.
16. MultiSWAP primary: PASS, provider/result must be worker-safe and batchable.
17. No mandatory 1:1 MODFLOW relation: NOT AFFECTED.
18. Deep-vadose optional: NOT AFFECTED.
19. Component transitions mass conserving: NOT AFFECTED.
20. Alternative soil-water solvers: PASS, no HeadCalc-specific public contract.
21. Reuse SWAP physics: PASS, B1.10 behavior is the reference.
22. No HeadCalc internals in other modules: PASS, raw hydraulic arrays explicitly rejected.
23. Physics versus numerical policy: PASS, SWREDU/SWINTER remain physical options.
24. Predictable runtime: PASS, restricted boundary is bounded local work.
25. Reference mode: PASS, B1.10 remains qualification oracle.
26. Diagnostics part of runtime: PASS, boundary regime/limitation required as result diagnostics.
27. Optional functionality scales with use: PASS.
28. Runtime/coupler composes system: PASS.
29. No silent dependencies: PASS.
30. Every architecture change audited: PASS, this document is the readiness audit.

## Readiness decision

The ownership boundary is sufficiently clear to proceed to a separate structural contract candidate, but **not** to a full surface-evaporation production migration in this workunit.

Decision:

`QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_BOUNDARY_READINESS_READY_FOR_STRUCTURAL_CONTRACT_CANDIDATE`

The structural candidate must start from the then-current canonical source authority and must be independently qualified before any production admission.
