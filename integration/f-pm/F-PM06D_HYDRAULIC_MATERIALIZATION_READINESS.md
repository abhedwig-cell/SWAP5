# F-PM06D Surface Evaporation Hydraulic Materialization Readiness

## Purpose

F-PM06D defines the smallest safe runtime boundary needed to feed the independently qualified F-PM06C/F-VQ52 structural surface-evaporation process with two hydraulic inputs:

- dry versus ponded classification;
- atmospheric hydraulic evaporation capacity corresponding to legacy `Emax`.

This workunit is readiness-only. It does not modify production source and does not migrate the full legacy `BoundTop` routine.

## Frozen scope

The first runtime materialization slice is deliberately narrower than all legacy top-boundary physics:

- `SWINTER = 0`;
- `SWREDU = 0`;
- frost inactive;
- macropore surface scaling inactive;
- no snow-mediated widening;
- no runoff-law migration;
- no full flux/head regime migration;
- no accepted evaporation-result publication yet.

The purpose of the frost/macropore restriction is architectural, not scientific convenience. Legacy `Emax` multiplies atmospheric-side conductivity by frost and matrix-area factors. Those factors are not yet exposed through a clean common hydraulic capability. They must not be smuggled through ET or process globals.

## Source-bound legacy relation

For the frozen B1.10 `BoundTop` path:

`hatm = -2.75e5 cm`

`katm = K_1(hatm)`

with frost inactive and macropore surface scaling inactive:

`ksurf = katm`

The atmospheric/top-node face conductivity is:

`k1Atm = hcomean(swkmean, ksurf, K_1(h_top), dz_1, dz_1, 0, hatm, h_top)`

and the hydraulic evaporation capacity is:

`Emax = -k1Atm * ((hatm - h_top) / disnod_1 + 1)`

The independently qualified structural surface process then applies, for a dry base surface:

`reva = min(peva, max(0, Emax))`

and, if the base surface is ponded:

`reva = 0; epd = epond`.

## Key ownership decision

### Ponding classification

Ponding classification is derived from the exact trial base state, not from mutable trial output:

`surface_is_ponded = base_state.ponding_depth > 1e-10 cm`.

This matches the B1.10 use of `pondm1`, the previously accepted ponding state.

Consequences:

- retries from the same checkpoint see the same classification;
- rejected trials cannot change it;
- after an accepted substep, a later substep may legitimately see a different classification because its base state has changed by commit;
- candidate ponding generated during a nonlinear trial must not be fed back as if it were committed `pondm1`.

`process_hydraulic_view_t` already carries `ponding_depth`, so no new persistent state is required.

### Evaporation capacity

`Emax` is owned by soil hydraulics, not ET.

ET/process code must receive a scalar capability result. It must not compute `Emax` by reading:

- HeadCalc arrays;
- Newton vectors;
- Jacobian state;
- raw conductivity arrays;
- solver module globals.

The current `constitutive_hydraulics_provider_t%evaluate()` is not the preferred direct API for this materialization. It is all-node/vector oriented and also computes water content, moisture capacity and `dK/dh`; the concrete B1.10 provider is additionally bound to `step_duration`. Calling that full path merely to obtain top-surface conductivity would mix responsibilities and impose unnecessary work.

## Required hydraulic capability

A production candidate should introduce a narrow solver/hydraulics-owned capability, conceptually equivalent to:

```text
surface_evaporation_capacity_provider.evaluate(base_state) -> result
```

The concrete provider may be bound to immutable/shared hydraulic parameter data and numerical conductivity-mean policy. The common result must expose only what downstream surface evaporation needs, for example:

- status;
- `evaporation_capacity` (`Emax`, cm/time);
- optional route/diagnostic identifier.

The capability must not expose conductivity arrays or solver scratch.

The scalar `Emax` should remain signed. A negative finite `Emax` is valid hydraulic information and is clamped by the already qualified surface process through `max(0,Emax)`. The capability must therefore not silently clamp it.

## Conductivity-mean ownership

Legacy `hcomean` supports seven policies, including arithmetic, geometric, harmonic and Szymkiewicz means. That choice is hydraulic/numerical ownership, not ET physics.

The surface process must not know `swkmean` or duplicate `hcomean`.

A B1.10 reference implementation of the new capability may internally reuse the same qualified constitutive and conductivity-mean logic, but the common process interface remains scalar and solver-independent.

## Data classification

### Immutable/shared parameters

- atmospheric limiting head parameter, with B1.10 reference value `-2.75e5 cm`;
- top-node geometry needed by the hydraulic implementation;
- top-layer constitutive parameter reference;
- conductivity-mean policy/reference;
- future frost/macropore factors only in later widened scopes.

These are not per-trial mutable process state.

### Committed persistent state

No new state.

Existing committed/base `ponding_depth` is reused. Top pressure head remains part of the committed soil-water state.

### Forcing

Potential demands `peva` and `epond` remain ET-owned forcing/process inputs. They are not inputs to the hydraulic capacity provider itself.

### Trial-local hydraulic result

- signed `Emax`;
- validity/status;
- diagnostic route.

### Surface-process trial result

From F-PM06C/F-VQ52:

- actual bare-soil evaporation decomposition `reva`;
- actual pond-water evaporation decomposition `epd`;
- route/status.

These are not yet authoritative accepted receipts.

### Worker scratch

Any atmospheric conductivity, top conductivity, face mean conductivity and temporary constitutive values are worker/call scratch.

## Validation contract

The materializer must fail closed if the base hydraulic input cannot be trusted, including at least:

- missing/invalid top state;
- non-finite ponding depth;
- non-finite computed capacity;
- unsupported hydraulic configuration for the qualified scope.

The first restricted production candidate should reject, rather than approximate, active frost or active macropore surface scaling.

A negative finite `Emax` is not an invalid input.

## Transaction contract

For every trial/subtrial:

1. read the exact trial base committed state;
2. classify ponding from that base state;
3. evaluate hydraulic capacity without mutating state;
4. evaluate F-PM06C surface evaporation into worker-local trial result;
5. discard all trial results on rejection;
6. only a later accepted-runtime workunit may publish accepted evaporation attribution.

No `last_Emax`, `last_reva`, `last_epd` or similar provider-global continuation state is permitted.

## Mass contract

F-PM06D adds no mass contribution.

Even after materialization, `reva` and `epd` remain decomposition values until tied to an accepted solver/top-boundary result. The authoritative soil-column top water exchange remains the accepted solver-returned external top flux.

A later accepted-result publisher may attribute soil versus pond evaporation, but may not book that water a second time.

## Time contract

`Emax` is a rate evaluated for a generic solver trial. No day boundary is required.

The materialization API must not assume midnight, one-day forcing or a fixed reporting interval. If the concrete hydraulic implementation requires a numerical step duration for other constitutive outputs, that implementation detail must not become part of the surface-process contract unless physically required.

## Recommended implementation slices

### F-PM06E or equivalent: scalar hydraulic-capacity provider candidate

Implement only the restricted B1.10 reference `Emax` capability for:

- frost inactive;
- macropore inactive;
- already admitted default B1.10 hydraulic family and conductivity-mean policies that can be source-bound and qualified.

Do not yet alter the active top-boundary provider.

### Independent F-VQ

Verify the scalar capability against frozen B1.10 over a matrix of top heads, hydraulic parameter sets and admitted mean policies. Include negative `Emax`, dry/wet extremes and O0/O2 identity.

### Runtime composition

Bind:

`exact base state -> ponding classification + Emax capability -> F-PM06C surface process`.

Keep outputs trial-local.

### Accepted top-boundary integration

Only after the above, integrate the surface evaporation partition into a qualified atmospheric top-boundary candidate and prove exact-once mass handling.

### Later optional families

Separate workunits remain required for:

- frost scaling;
- macropore surface scaling;
- `SWREDU=1`;
- `SWREDU=2`;
- interception/wet-canopy evaporation;
- runoff/snow interactions where they alter the boundary path.

## Readiness exit criterion

F-PM06D is ready to close when source locks and a no-production-delta gate prove:

- committed/base ponding is the correct classification authority;
- current canonical has no scalar `Emax` capability;
- the current all-node constitutive interface is intentionally not reused as the public surface-process API;
- signed `Emax` ownership and validation are explicit;
- mass, transaction, time and optionality contracts are fixed;
- the next candidate is restricted to hydraulic capability materialization rather than full `BoundTop` migration.
