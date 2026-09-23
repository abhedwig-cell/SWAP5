# SW-RIB-SWM01: legacy SWAP surface-water ownership decomposition

**Date:** 2026-09-23  
**Status:** PROPOSED / OPEN QUALIFICATION  
**Baseline:** `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`  
**Scope:** research and migration authority only; no production admission and no retirement authority.

## Research question

Can the legacy SWAP surface-water-management functionality be decomposed so that Ribasim owns surface-water state and management in a Ribasim-coupled application, SWAP retains soil-to-surface-water exchange physics, and the coupler owns soil-state-driven management policy, without loss of qualified SWAP functionality?

## Important mode-aware correction

Current canonical SWAP5 already contains F-CI52/F-VQ59 qualified restricted fixed-weir surface-water physics. That capability is real current production physics, not merely legacy residue. It includes optional surface-water storage, storage/level mapping, bounded supply, positive secondary-drainage attribution and fixed-weir discharge with hard mass and transaction semantics.

SW-RIB-SWM01 therefore does **not** propose deleting all SWAP5 surface-water functionality.

The target distinction is:

```text
standalone SWAP5 profile:
    SWAP5 F-CI52 may own the restricted fixed-weir surface-water state

Ribasim-coupled profile:
    Ribasim owns surface-water state/storage/level/network
    SWAP owns soil-to-surface-water exchange physics
    coupler owns cross-model management policy and transaction ordering
```

For one physical surface-water store, `SWAP_FIXED_WEIR` and `EXTERNAL_RIBASIM` must not be simultaneously authoritative.

See [SW-RIB-SWM01 legacy surface-water responsibility inventory](SW-RIB-SWM01_LEGACY_INVENTORY.md) for the bounded decomposition and evidence limits.

## Why this work unit exists

Legacy SWAP 4.3.1 contains more than drainage physics. The surface-water functionality includes a local surface-water store, dynamic or prescribed surface-water levels, discharge/control structures, water supply logic and soil-state-driven management behaviour. A coupled SWAP5 + Ribasim system should avoid duplicated ownership of the same surface-water state and management decisions.

The current migration map already classifies `surfacewater.f90` as `SPLIT_RETAIN_PHYSICS`. SW-RIB-SWM01 makes the required decomposition and qualification explicit before any stronger retirement claim is made.

## Provisional ownership hypothesis

This is a hypothesis to test for the Ribasim-coupled profile, not current production authority.

### Ribasim candidate ownership

Ribasim is the candidate owner for system-level surface-water state and management realization:

- surface-water storage and level;
- network connectivity and routing/composition;
- structures and controlled releases;
- pumps, outlets and external supply paths;
- allocation, priorities and scarcity handling;
- system-level target-level realization.

### SWAP5 retained ownership

SWAP5 remains the candidate owner for soil-column process physics that determines exchange with surface water:

- drainage from soil/groundwater toward surface water;
- infiltration or subirrigation response from surface water toward the soil;
- multi-level drainage behaviour where part of the qualified SWAP process contract;
- runoff and other soil-column fluxes delivered to the surface-water system;
- macropore/crack contributions where applicable and separately qualified.

Ribasim may receive or supply these exchanges, but does not become owner of the SWAP soil-response equations merely because it owns the receiving or supplying surface-water state.

### Coupler / management-policy candidate ownership

A separate coupling or management-policy layer is the candidate owner for rules that translate accepted SWAP state into a surface-water management target:

```text
accepted SWAP soil state
    -> management policy
    -> requested/target surface-water level or demand
    -> Ribasim control/allocation
    -> realized surface-water state
    -> SWAP exchange physics
```

This is especially relevant for legacy soil-moisture-controlled weir behaviour based on groundwater level, pressure head or available unsaturated storage.

A trial SWAP state must not become external management authority merely because it was computed. Any soil-state-driven management action must respect the accepted-state and coupling-window contract.

## Legacy inventory

The responsibility-level inventory is persisted in:

- `docs/integration/SW-RIB-SWM01_LEGACY_INVENTORY.md`;
- `integration/research/SW_RIB_SWM01_INVENTORY.json`.

The exact B0 identity of `surfacewater.f90` is known, and B1.11 leaves that source body unchanged. The current inventory deliberately distinguishes exact file identity from a line-complete raw-source reconstruction. Whole-file retirement remains blocked until the latter is unnecessary by accepted equivalence evidence or is explicitly reconstructed.

## Qualification sequence

The work is split to avoid testing several ownership changes at once:

1. **Q1A:** real-Ribasim ownership of storage/level/fixed-weir discharge, with positive drainage forcing and no supply.
2. **Q1B:** bounded level-triggered external supply.
3. **Q2:** soil-state-driven automatic management policy with accepted-state rollback/replay.
4. **Q3:** signed active drainage/infiltration exchange while Ribasim owns surface-water state.
5. **Q4:** adjudicate which remaining legacy container/parser responsibilities can actually retire.

Q1A is preregistered at `integration/research/SW_RIB_SWM01_Q1A_PREREGISTRATION.json`.

## Closure criteria

SW-RIB-SWM01 can close only when:

1. the legacy responsibility inventory is complete enough to exclude hidden ownership;
2. each retained behaviour has exactly one target owner per application profile;
3. the real-Ribasim reconstructions pass their preregistered conservation and trajectory requirements, or divergences are explicitly adjudicated;
4. rejected SWAP trials cannot leak into Ribasim management state or accepted allocation state;
5. no physical behaviour is retired solely because Ribasim has a superficially similar component;
6. coupled mode cannot activate two authoritative surface-water state owners for the same store;
7. the resulting ownership split is reflected in current architecture/coupling contracts before production admission.

## Current decision boundary

**Not authorized:** deleting or retiring `surfacewater.f90` behaviour as a whole, or removing the qualified F-CI52 standalone fixed-weir capability.

**Authorized research direction:** determine whether the legacy container can ultimately retire after responsibilities are separated into Ribasim-owned system state in coupled mode, SWAP-owned exchange physics and coupler-owned management policy, while standalone SWAP5 retains its separately qualified fixed-weir profile.

This work unit is deliberately non-blocking for the minimal SWAP5 + MODFLOW6 + Ribasim triangle unless that triangle depends on a legacy surface-water-management behaviour covered here. It is blocking for any claim that the legacy SWAP surface-water subsystem is obsolete or safe to retire.


## Research closeout

The ownership/decomposition research question is closed. Q4B demonstrates that the retained signed extended exchange physics can be bound transactionally without reintroducing SWAP-owned surface-water storage. The externally coupled target split is therefore research-qualified.

Production admission remains separate. Whole-file deletion remains unauthorized until the coupled application profile enforces the ownership XOR and explicitly disposes of the remaining representation choices documented in the closeout.
