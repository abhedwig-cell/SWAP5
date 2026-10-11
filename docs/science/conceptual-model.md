# Conceptual system and boundaries

## Representative one-dimensional column

A logical SWAP column represents the vertical soil-plant-atmosphere system over a chosen horizontal support. State variables can vary with depth and time; horizontal coordinates are not internally discretised.

The abstraction is appropriate only when the unresolved horizontal structure is sufficiently represented for the intended application — for example through representative parameters, parameterised lateral exchange, multiple columns/tiles or an external spatial component. It is not a hidden 2D/3D soil-flow model.

## Upper boundary

The upper conceptual boundary separates the local system from atmospheric and management forcing. Depending on the admitted process configuration, the local response can include interception, surface storage/ponding, infiltration, evaporation, transpiration and local runoff generation.

Meteorological quantities are forcing; SWAP does not resolve atmospheric fluid dynamics.

## Soil and root-zone domain

The soil domain is vertically layered and may be variably saturated. Hydraulic and other active process properties can vary with layer/depth. Vertical matrix water movement is a central process in the admitted reference Richards route.

A root-zone process, when active in a qualified capability, removes water as an explicit soil-water sink. Reporting or attribution of transpiration must not create a second mass booking of the same extraction.

## Lateral exchange

Lateral field-scale interactions such as drainage are not a second internal spatial dimension. They are represented by bounded source/sink terms or exchange laws where admitted. The model therefore does not reconstruct the horizontal hydraulic-head or flux field from those terms.

## Bottom interface

The lower boundary is the bottom of the configured SWAP column. It is an explicit physical interface through which a head condition, flux condition or coupled head/flux relation can operate.

A bottom flux is **not universally synonymous with deep groundwater recharge**. Its interpretation depends on the surrounding composition:

- standalone boundary condition;
- admitted direct groundwater coupling;
- or, where material, a separate deep-vadose transfer component between the SWAP bottom and groundwater.

The frozen Status-A baseline admits Groundwater Coupling v1 as a bounded coupling capability. It does not imply a broad MODFLOW backend or unrestricted groundwater composition.

## Time abstraction

The physical system evolves continuously in time while forcing, process events, solver attempts and reporting can use different time scales. The SWAP5 kernel works over a generic interval `[t0,t1]`; a calendar day is not the universal fundamental numerical unit.

This distinction matters for review. Daily meteorological/crop practices in historical SWAP documentation are not automatically a kernel-level time-boundary rule.

## Process disposition

The conceptual SWAP system can be understood through four kinds of relationship:

| Disposition | Meaning |
| --- | --- |
| `FORCING` | externally supplied drivers such as meteorology or prescribed management water |
| `RESOLVED` | an internal state/flux process when that process is explicitly active and qualified |
| `BOUNDARY / PARAMETERISED EXCHANGE` | an external influence represented through an interface or aggregate exchange law |
| `EXTERNAL COMPONENT / OUT OF SCOPE` | dynamics owned by another component or not spatially represented by one SWAP column |

Examples of conceptual process families include surface storage, vertical matrix flow, root uptake, drainage, Snow, heat/solute/crop processes and coupling to groundwater. **Their presence in the conceptual model is not evidence that every option is part of the Status-A review denominator.**

## Multiple columns and spatial composition

Serialized MultiSWAP v1 coordinates multiple logical columns. It does not turn those columns into a horizontally coupled soil-flow grid. Area fractions, tile mappings and spatial aggregation belong to runtime/application composition rather than the internal physics of one column.

The same principle applies to direct groundwater coupling: SWAP supplies local column physics and an interface exchange contract; the groundwater component owns groundwater-system evolution.

## Core scientific nonclaims

The review baseline does not claim that:

- one column resolves within-field horizontal redistribution;
- bottom flux is always groundwater recharge;
- conceptual suitability provides an application-specific error bound;
- inactive optional physics is implicitly represented;
- multiple columns automatically form a 2D/3D hydrological model;
- numerical execution policy may redefine mass or process physics.

Mass conservation remains a hard cross-cutting requirement: internal and external exchanges must be explicitly accounted for by their owning capability.

## Authority trail

This narrative is reconciled from the qualified historical F-DOC16 conceptual authority and current Status-A architecture/traceability. For the exact frozen review claim follow:

- [Current Status-A scope](../status-a/CURRENT_STATUS.md)
- [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md)
- [Theory, code and evidence traceability](../status-a/TRACEABILITY.md)
