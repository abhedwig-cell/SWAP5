# Surface evaporation

## Physical role

Surface evaporation transfers water from the local surface system to the atmosphere. The scientific formulation distinguishes a ponded surface from an unponded soil surface.

For a ponded surface, the admitted restricted process can satisfy the ponded-water evaporation demand. For an unponded surface, atmospheric demand can be limited by the hydraulic capacity of the upper soil to supply water to the surface.

## Restricted algebraic process

For the historically qualified restricted `SWREDU=0` route, the process relation is:

```text
unponded:
E_soil = min(E_soil,pot, max(0, E_capacity))
E_pond = 0

ponded:
E_soil = 0
E_pond = E_pond,pot
```

`E_capacity` is supplied through the qualified hydraulic surface view. The surface-evaporation process therefore does not need to own HeadCalc internals or a second soil-water state.

The broader SWAP scientific lineage contains other empirical evaporation-reduction approaches. They are not silently admitted by this restricted Status-A explanation.

## State ownership

The restricted evaluator is stateless: it calculates a rate from demand and the current hydraulic/surface view. It does not own persistent soil or surface storage.

This is important for mass accounting. The physical evaporation loss is booked once through the accepted surface/soil-water transaction. Diagnostics or process outputs do not create a duplicate authoritative loss.

## Performance versus science

F-PE11 later addressed bounded performance behaviour around the admitted surface-evaporation path. Its closure preserves the scientific semantics and does not constitute a new evaporation model, a new mass policy or a whole-model speedup claim.

For current evidence see [Status-A traceability](../status-a/TRACEABILITY.md). For the architecture around candidate/accepted process output see [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md).

## Review boundary

Reviewers should distinguish:

- atmospheric demand calculation;
- hydraulic capacity supplied by the soil-water side;
- the local evaporation law;
- accepted mass accounting;
- performance implementation details.

A change in allocation/copy strategy is not a scientific change if the process result and state/accounting contracts remain identical. Conversely, a change in the limiting law or capacity semantics is scientific/numerical and requires its own qualification authority.
