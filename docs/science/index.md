# Scientific model

This section explains the scientific model represented by the frozen SWAP5 Status-A review baseline. It is a **review narrative**, not a replacement for the distributed scientific authorities and capability-specific qualification records.

The foundation follows the long-standing SWAP scientific lineage while making the modern SWAP5 system boundaries explicit. The historical F-DOC16 conceptual authority qualified the chain

`physical system -> modelling purpose -> spatial/temporal scales -> system boundary -> abstraction -> conceptual model`.

F-DOC18 then qualified a bounded historical RB1 physical-science authority for three restricted capability families: reference matrix soil-water flow, restricted ET/root uptake and restricted surface evaporation. F-DOC17 explicitly classified that F-DOC18 material as a **qualified historical RB1 authority**, not automatically as current-canonical documentation authority. The present review pages therefore reconcile that scientific material with the current Status-A traceability map rather than promoting the historical branch wholesale.

## What SWAP represents

SWAP represents a local soil-plant-atmosphere hydrological system as a vertically resolved one-dimensional column over a defined horizontal support. The model is primarily concerned with water storage and water fluxes through the surface, root zone, unsaturated soil and the configured lower boundary, together with explicitly admitted coupled processes.

The one-dimensional abstraction means that state can vary with depth and time, while horizontal coordinates are not resolved inside one logical SWAP column. Horizontal heterogeneity can instead be represented through effective properties, multiple columns/tiles or an explicitly external spatial model when that composition is appropriate.

A column has no universal fixed horizontal area. Quantities are naturally interpreted per unit horizontal area unless an external runtime/coupler supplies an area weight.

## Read this section in this order

1. [Conceptual system and boundaries](conceptual-model.md)
2. [Vertical soil-water flow](soil-water-flow.md)
3. [Surface evaporation](surface-evaporation.md)
4. [Status-A capability review pages](../capabilities/index.md)
5. [Numerical formulation](../numerics/index.md)
6. [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md)
7. [Theory, code and evidence traceability](../status-a/TRACEABILITY.md)

## Admitted capability narratives

Some Status-A capabilities need a bounded reviewer-facing explanation even though their primary authority is architectural, runtime or capability-specific rather than one historical master theory document. The [Status-A capability review pages](../capabilities/index.md) now document:

- Restart v1;
- serialized MultiSWAP v1;
- Drainage;
- bounded WOFOST runtime;
- restricted one-call-daily Snow;
- Groundwater Coupling v1.

These pages reconstruct only what can be supported from accepted theory, code, qualification and Status-A evidence. Where authority is insufficient for a broader scientific statement, the boundary or gap is documented rather than filled by assumption.

## Conceptual scope is not release admission

A process can belong to the scientific SWAP concept without being admitted in the frozen Status-A denominator. Conceptual statements answer **what kind of system SWAP can represent**; the Status-A capability map answers **what this frozen review baseline actually claims**.

For current admission questions, [Current Status-A scope](../status-a/CURRENT_STATUS.md) and [Theory, code and evidence traceability](../status-a/TRACEABILITY.md) are controlling.

## Main scientific sources

The reconstructed conceptual/scientific documentation draws on the controlled SWAP lineage used by F-DOC16/F-DOC18, including:

- the SWAP 4.3 theory and user-guide lineage;
- Kroes et al. (2017), *SWAP version 4; Theory description and user manual*, DOI `10.18174/416321`;
- Van Dam (2000), *Field-scale water flow and solute transport: SWAP model concepts, parameter estimation and case studies*, DOI `10.18174/121243`;
- Heinen et al. (2024), *SWAP 50 years: Advances in modelling soil-water-atmosphere-plant interactions*, Agricultural Water Management 298, 108883.

These sources establish scientific lineage. They do not by themselves prove that every described option is implemented or admitted in SWAP5.

## Review discipline

For a scientific claim, reviewers should distinguish:

- **scientific lineage** — the theory or physical concept;
- **SWAP5 formulation** — the bounded formulation actually represented;
- **production authority** — the admitted implementation;
- **qualification evidence** — tests/evidence that support the implementation claim;
- **preservation authority** — the mechanism that protects the admitted behaviour on later heads.

The current mapping between these layers is maintained in [Status-A traceability](../status-a/TRACEABILITY.md).
