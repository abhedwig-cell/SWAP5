# SW-RIB-SWM01: legacy SWAP surface-water ownership decomposition

**Date:** 2026-09-23  
**Status:** PROPOSED / OPEN QUALIFICATION  
**Baseline:** `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`  
**Scope:** research and migration authority only; no production admission and no retirement authority.

## Research question

Can the legacy SWAP surface-water-management functionality be decomposed so that Ribasim owns surface-water state and management, SWAP retains soil-to-surface-water exchange physics, and the coupler owns soil-state-driven management policy, without loss of qualified SWAP functionality?

## Why this work unit exists

Legacy SWAP 4.3.1 contains more than drainage physics. The surface-water functionality includes a local surface-water store, dynamic or prescribed surface-water levels, discharge/control structures, water supply logic and soil-state-driven management behaviour. A coupled SWAP5 + Ribasim system should avoid duplicated ownership of the same surface-water state and management decisions.

The current migration map already classifies `surfacewater.f90` as `SPLIT_RETAIN_PHYSICS`. SW-RIB-SWM01 makes the required decomposition and qualification explicit before any stronger retirement claim is made.

## Provisional ownership hypothesis

This is a hypothesis to test, not current production authority.

### Ribasim candidate ownership

Ribasim is the candidate owner for system-level surface-water state and management:

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

A separate coupling or management-policy layer is the candidate owner for rules that translate accepted SWAP state into a surface-water management target, for example:

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

## Required legacy inventory

Before implementation or retirement, every relevant responsibility in `surfacewater.f90` and adjacent drainage/management code must be classified into one of these categories:

- `MOVE_TO_RIBASIM`
- `RETAIN_IN_SWAP`
- `MOVE_TO_COUPLER`
- `LEGACY_ONLY_CANDIDATE_RETIRE`
- `UNRESOLVED`

The inventory must identify state ownership, flux ownership, input/configuration ownership, temporal semantics and any dependency on accepted versus trial state.

## Minimum qualification case

The first decisive regression/qualification case should reproduce a representative legacy SWAP surface-water-management case using:

```text
SWAP5 soil/exchange physics + real Ribasim/RibaMod + explicit coupler
```

The case should not be limited to a prescribed level. It should include dynamic surface-water state and, if the exact legacy authority can be reconstructed, a soil-moisture-controlled management rule so that loss of SWAP-specific management semantics is detectable.

At minimum compare:

- water balance across the SWAP/Ribasim interface;
- surface-water level trajectory;
- drainage and infiltration/subirrigation exchange;
- runoff contribution where active;
- management target and realized action;
- accepted-state/retry behaviour at coupling-window boundaries.

## Closure criteria

SW-RIB-SWM01 can close only when:

1. the legacy responsibility inventory is complete enough to exclude hidden ownership;
2. each retained behaviour has exactly one target owner;
3. the real-Ribasim reconstruction has a preregistered comparator and passes its declared conservation and trajectory requirements, or any divergence is explicitly adjudicated;
4. rejected SWAP trials cannot leak into Ribasim management state or accepted allocation state;
5. no physical behaviour is retired solely because Ribasim has a superficially similar component;
6. the resulting ownership split is reflected in the current architecture/coupling contracts before production admission.

## Current decision boundary

**Not authorized:** deleting or retiring `surfacewater.f90` behaviour as a whole.

**Authorized research direction:** test whether the legacy container can ultimately be retired after its responsibilities are separated into Ribasim-owned system state, SWAP-owned exchange physics and coupler-owned management policy.

This work unit is deliberately non-blocking for the minimal SWAP5 + MODFLOW6 + Ribasim triangle unless that triangle depends on a legacy surface-water-management behaviour covered here. It is blocking for any claim that the legacy SWAP surface-water subsystem is obsolete or safe to retire.
