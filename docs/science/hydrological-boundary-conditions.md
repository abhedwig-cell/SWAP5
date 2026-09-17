# Hydrological boundary conditions

This page documents the hydrological boundary semantics that can be supported for the frozen SWAP5 Status-A scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`. It is deliberately not an exhaustive catalogue of every lower- or upper-boundary option in the historical SWAP family.

For the exact admitted groundwater lower-boundary composition, including hydraulic-head datum conversion, flux signs and units, whole-window exchange, predictor-corrector ownership and accepted-state publication, see [Groundwater coupling and the lower hydrological boundary](groundwater-coupling.md).

## Boundary role in the column balance

The one-dimensional soil column exchanges water through an upper and a lower boundary. In the frozen solver contract, each side can carry a requested flux or head representation:

```text
upper boundary: top_flux or top_head
lower boundary: bottom_flux or bottom_head
```

The solver contract also returns the realized top and bottom fluxes for the candidate solve. Those values only become authoritative model transfers when the surrounding transaction accepts and commits the interval.

Boundary variables must be read in their local contract. A meteorological supply term, a hydraulic vertical flux and a normalized mass-accounting amount do not necessarily use the same sign convention. See [Water balance, signs and units](water-balance-and-conventions.md).

## Upper boundary: restricted dynamic surface route

The frozen B1.10 dynamic top-boundary implementation is represented by `src/solver/mod_b110_dynamic_top_boundary_provider.f90`. Its request combines, in `cm/day`:

- precipitation;
- irrigation;
- snowmelt;
- runon;
- potential bare-soil evaporation;
- potential ponded-water evaporation.

It also receives the previous and candidate ponding depth, the top-compartment hydraulic state, the step duration, a maximum ponding depth and the restricted runoff parameters.

The process first forms the net potential surface supply

```text
q_surface,pot = precipitation + irrigation + snowmelt + runon
                - bare-soil evaporation - ponded-water evaporation
```

This quantity is a surface-supply bookkeeping expression. The provider then converts it into the hydraulic boundary problem and evaluates whether the surface is flux-controlled or head-controlled.

The frozen restricted implementation exposes four successful route labels:

- `atmospheric-head`;
- `surface-flux`;
- `ponded-head`;
- `ponded-head-linear-runoff`.

The atmospheric route uses the frozen atmospheric pressure-head limit and a conductivity-limited evaporation capacity. The surface-flux route is selected when the requested flux can be accommodated without positive surface head. If positive head is required, the provider represents ponding and, within the admitted restricted profile, can resolve linear runoff when the ponding threshold is exceeded.

Surface evaporation is evaluated through the separately documented restricted evaporation process. See [Surface evaporation](surface-evaporation.md).

### Upper-boundary sign caution

Inside the dynamic provider, positive precipitation, irrigation, snowmelt and runon increase `q_surface,pot`, while evaporation reduces it. The hydraulic flux passed into the Richards calculation is constructed with the hydraulic vertical-flux convention. These are two different local representations of the same surface exchange problem and should not be collapsed into a universal raw-code sign rule.

## Lower boundary: solver interface

The frozen soil-water solver contract contains an explicit lower-boundary interface with `bottom_flux` and `bottom_head` fields. That establishes the lower boundary as a first-class solver boundary, but the contract type by itself does not prove which historical bottom-boundary modes are production-admitted.

F-DOC21 therefore makes only two stronger statements:

1. bottom exchange is part of the column water balance and must be booked once with an explicit sign/unit translation;
2. the separately admitted Groundwater Coupling v1 can supply a bounded coupled lower-boundary context.

No broader free-drainage, prescribed-head, seepage, regional-groundwater or MODFLOW option catalogue is inferred from the existence of the generic solver fields.

## Groundwater Coupling v1 at the lower boundary

Groundwater Coupling v1 is an admitted Status-A capability. Its restricted predictor-corrector runtime is implemented in `src/runtime/mod_groundwater_predictor_corrector_window.f90` and is bounded by the F-GC qualification/admission chain.

The detailed interface contract is documented in [Groundwater coupling and the lower hydrological boundary](groundwater-coupling.md). That page is the reviewer-facing reference for the mandatory head datum, the distinction between native SWAP `qbot` and outward coupling flux, exact action/reaction pairing, governed head convergence and the staged/prepared/committed interface ledger.

The coupling window follows this ownership sequence:

```text
capture accepted SWAP and groundwater origins
        |
        v
predictor SWAP trial
        |
        v
predictor groundwater trial
        |
        v
discard predictor candidates
        |
        v
corrector SWAP trial using predicted groundwater head
        |
        v
corrector groundwater trial
        |
        v
interface/convergence and publication checks
        |
        v
prepare and commit accepted coupled state
```

The predictor is therefore informative, not authoritative. Its candidate states are discarded. Publication authority belongs to the accepted corrector path after the coupling checks and transaction preconditions have passed.

The SWAP-side whole-window bottom exchange is converted at the coupling interface into a paired SWAP/groundwater flux representation. The interface and mass ledger are responsible for unit and sign pairing. A rejected or non-converged coupling attempt must not publish the tentative exchange as accepted state.

The capability page [Groundwater Coupling v1](../capabilities/groundwater-coupling-v1.md) owns the higher-level admission statement.

## Water-balance implications

For an accepted interval, an upper- or lower-boundary transfer is external to the soil-column accounting domain. If SWAP is coupled to another component, the same lower-boundary transfer is external to each component-local balance but internal to the combined coupled system.

A head-convergence condition is not a substitute for this transfer identity. The accepted SWAP and groundwater sides must describe the same physical exchange over the same accepted time window.

## What this page does not establish

This page does not claim:

- an exhaustive historical top-boundary option set;
- an exhaustive historical bottom-boundary option set;
- unrestricted runoff laws or interception physics;
- unrestricted MODFLOW or other groundwater backends;
- arbitrary coupling schedules or interpolation policies;
- that a generic `top_flux`, `top_head`, `bottom_flux` or `bottom_head` field is itself evidence of production admission;
- one global raw-variable sign convention across all process, solver and accounting layers.

Those claims require their own scientific, implementation and qualification authority.

## Traceability

Primary frozen implementation anchors used here are:

- `src/solver/mod_soil_water_solver_contract.f90`;
- `src/solver/mod_b110_dynamic_top_boundary_provider.f90`;
- `src/runtime/mod_groundwater_predictor_corrector_window.f90`.

Groundwater admission is bounded by F-GC28 and the current Status-A traceability chain. Historical scientific lineage is used only where it has been reconciled to the frozen production postimage.
