# Coupling concept primer: one physical system, different model links

Date: 2026-09-21
Status: RESEARCH EXPLANATION

## The question before the algorithm

Before choosing an exchange coefficient, predictor/corrector method or API
package, define one physical system and answer:

1. What is the physical state?
2. Which water volume is stored when that state changes?
3. Which model owns each part of that storage?
4. Which fluxes enter or leave the complete physical control volume?
5. Is the connection between models a real physical resistance, or only a
   numerical decomposition of one continuous system?

The coupling equations follow from these choices. They should not define them
after the fact.

## Example: one phreatic head

For the simplest dummy column:

```
             rain P
               |
               v
      +-------------------+  surface
      | unsaturated part  |
      |                   |
      |-------------------|  h = shared phreatic head
      | saturated part    |
      |                   |
      +-------------------+
               ^
               |
          groundwater flow
```

If SWAP and MODFLOW both describe this as one continuous column, the phreatic
head is one physical state:

```
h_swap = h_modflow = h
```

The total water balance is written once:

```
Delta V_total = V_atmosphere + V_groundwater - V_ET - V_drain
```

How the calculation is split between programs must reproduce this equation.

## Coupling family A: shared-state h-link

There are not two independent phreatic heads. Both model components update the
same state using one combined storage relation.

Conceptually:

```
        column processes
             |
             v
         [ shared h ]
             ^
             |
       groundwater flow
```

There is no physical resistance between two copies of the phreatic surface.
The inter-model quantity required by the algorithm is a balance contribution
and storage response, not necessarily a Darcy flux crossing a fixed material
interface.

This is the family described by Van Walsum and Veldhuizen (2011) for
MetaSWAP-MODFLOW.

## Coupling family B: finite-resistance q-link

Now there really are two states:

```
h_column ---- resistance c ---- h_groundwater
```

with

```
q_ex = (h_column-h_groundwater)/c
```

Each side may own its own storage. The exchange flux is a physical flux through
the represented resistance.

As `c -> 0`, the two heads approach each other. This limit can become
numerically stiff. The zero-resistance limit should approach the shared-state
solution only if storage ownership is also made consistent.

## Coupling family C: sequential boundary exchange

A model can instead receive the other model's previous/current state as a
boundary condition, calculate a flux, and return that flux:

```
MODFLOW head -> vadose model -> recharge -> MODFLOW
```

This can be iterated or used sequentially. It need not use a shared combined
storage relationship.

HYDRUS-MODFLOW is an example of this broader family: MODFLOW supplies water
table position to the vadose model, and the vadose model provides recharge to
MODFLOW.

## Where the current SWAP5 F-GC route sits

The current canonical F-GC implementation must not be described as if it had
already implemented coupling family A.

Its exchanged head is the hydraulic head on the SWAP lower coupling plane.
Canonical source explicitly distinguishes this from the freatic groundwater
level. The head-driven corrector applies that value as a mode-5 lower boundary.

So the current real-SWAP route is best described as an iterated lower-boundary
head/exchange coupling with one agreed interface head:

```
MODFLOW interface head
        |
        v
SWAP bottom-head corrector
        |
        v
accepted bottom exchange
        |
        +----> MODFLOW
```

That interface-head equality is physically meaningful, but it does not by
itself prove that SWAP and MODFLOW share one complete-profile phreatic storage
state.

This distinction matters for the double-storage question. The dummy h-link
experiments show exactly what duplicate storage would do if both model
components represented the same physical storage volume. MAP11 shows that the
synthetic F-GC45 fixture is not constructed as that coextensive volume, so it
cannot be used as a direct duplicate-storage proof.

## Four quantities that must not be given the same name

### 1. Physical boundary flux

Water that crosses an actual material/model-domain boundary.

Example:

```
q_ex = C Delta h
```

### 2. Water-balance remainder

Water left for the shared phreatic update after a column model has already
changed internal unsaturated storage.

This need not equal atmospheric recharge.

### 3. Storage response

How total physical storage changes when the shared head changes:

```
mu = dV/dh
```

### 4. Numerical tangent

How a residual or model response changes locally with the trial head:

```
J = dF/dh
```

A numerical tangent can have the same dimensions as a storage/time or a
conductance without being an additional physical reservoir or resistance.

## Why the dummy-SWAP testbank matters

Real Richards physics makes all four quantities change at once. A transparent
dummy lets us turn them on separately.

For each experiment we can therefore show:

```
physical equation
       |
       v
exact analytic answer
       |
       v
chosen model partition
       |
       v
MODFLOW matrix/API representation
       |
       v
numerical solution
       |
       v
independent water-balance check
```

A coupling concept is accepted only when all arrows are demonstrably
consistent.

## Current research result

DSW-01/02 established for a linear shared-storage system that:

- a total physical storage can be partitioned arbitrarily between MODFLOW STO
  and an algebraically consistent dummy-side term without changing the final
  head;
- assigning the same storage twice gives the exact predicted double-storage
  signature;
- the current positive `+u/dt` overlap probe is not equivalent to that
  consistent storage partition in the zero-resistance dummy;
- MODFLOW Newton saturation smoothing is a separately understood numerical
  regularization.

These are bounded research results. They do not by themselves establish a
general defect in the production SWAP5-MODFLOW6 coupling.

## References

- Van Walsum, P.E.V. and Veldhuizen, A.A. (2011). Integration of models using
  shared state variables: Implementation in the regional hydrologic modelling
  system SIMGRO. Journal of Hydrology 409, 363-370.
- Hughes, J.D. et al. (2022). The MODFLOW Application Programming Interface for
  simulation control and software interoperability. Environmental Modelling &
  Software 148, 105257.
- Twarakavi, N.K.C., Simunek, J. and Seo, S. (2008). Evaluating interactions
  between groundwater and vadose zone using the HYDRUS-based flow package for
  MODFLOW. Vadose Zone Journal 7.
- iMOD Coupler technical reference, MetaSWAP-MODFLOW6 coupling.
