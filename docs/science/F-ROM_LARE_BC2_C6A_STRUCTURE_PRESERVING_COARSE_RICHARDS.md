# F-ROM-LARE BC2-C6A structure-preserving coarse Richards derivation

## Status

**CLOSED: explicit interface unknowns alone do not define a new physical Layer-ROM closure.**

C6A is a response-free theory reconciliation. No hydrological trajectory was generated, no model code was changed, and no Reference, RossFast or groundwater-coupling behavior was altered.

## Question

Can the post-C5Z representation problem be closed by keeping one conserved layer storage state per coarse layer while making interface hydraulic potential and interface flux explicit algebraic unknowns?

The intended construction was attractive because it would preserve one shared conservative flux at every interface and would avoid immediately prescribing a complete within-layer moisture profile.

The derivation shows that this is not enough.

## Conserved state and interface variables

Use the existing reduced convention

[
\frac{dS_i}{dt}=q_{i-1/2}-q_{i+1/2},
]

with (S_i) the integrated water storage in layer (i) and one shared downward-positive flux (q_j) at every face.

Introduce at every face an algebraic hydraulic trace (lambda_j) and flux (q_j). For (N) layers this gives (2(N+1)) face unknowns. Two one-sided hydraulic relations per layer plus two external boundary relations make the algebraic count square.

That degree count does **not** close the physics. It closes only after a local center-to-face hydraulic relation has been chosen.

## Static-condensation result

### Lowest-order Darcy half-cells

Let the retained storage determine the representative layer state and use a one-sided Darcy drop over each half-layer. Eliminating the shared interface trace gives, up to the frozen sign convention,

[
q_{i+1/2}
=
\frac{\Delta H}
{d_i/(2K_i)+d_{i+1}/(2K_{i+1})}.
]

The explicit interface pressure has disappeared. What remains is the familiar conservative two-point resistance operator.

Therefore an algebraic face potential is a useful numerical variable, but it is not additional hydrological memory. This construction remains in the existing-state coarse Darcy/two-point family already interrogated by CURRENT_LAYER_FACE, C4H-C4O and the same-partition CoRichards work.

### Exact nonlinear steady half-cells

Replacing each half-cell Darcy drop by its exact nonlinear steady integral does not solve the problem either. The shared interface flux then connects the two representative layer states by one constant center-to-center steady Darcian flux. After condensation this is the DSE2P closure object.

C5T already rejected that preregistered route during response-free numerical qualification. C6A does not reopen it.

### Affine transient flux inside a layer

Allowing unequal top and bottom fluxes by taking (q(z)) affine makes

[
\partial\theta/\partial t=-\partial q/\partial z
]

constant inside the layer. That is exactly the P0 uniform-storage-tendency choice derived in C5V.

C5W prospectively rejected P0 on its frozen existence/admissibility contract before hydrological response. Interface traces do not make it a different closure.

## Why higher order does not come for free

If (q(z)) is allowed to have curvature, or if the storage tendency varies inside a layer, then total layer storage fixes only the integral tendency. It does not determine its spatial distribution.

A further subgrid principle or additional state is therefore required. This is the same underdetermination established in C5V and reopened in C5X.

C5Y then identified the centered first water-content moment as the smallest additional conservation-derived shape state. C5Z rejected the **all-layer cubic-theta reconstruction**, not the physical meaning or exact balance of that moment.

## Dissipation does not remove the missing closure

A shared face flux gives exact layer-by-layer conservation. A mixed or hybrid formulation can also express Darcy dissipation cleanly.

But if a minimum-resistance or steady dissipation principle is imposed between fixed representative hydraulic states, the construction returns to a steady Darcian center-to-center problem and therefore to the DSE2P class.

Dissipation plus conservation does not independently specify the transient within-layer storage tendency from (S_i) alone.

## Relation to mixed-hybrid Richards methods

Mixed and mixed-hybrid Richards discretizations are valuable precisely because flux can be represented explicitly and local mass conservation can be enforced. Lowest-order Raviart-Thomas and mixed-hybrid formulations are established examples.

That literature supports the numerical architecture considered here, but it also sharpens the distinction C6A needs: flux and trace degrees of freedom in a mixed discretization are not automatically new dynamic hydrological state.

Relevant theory context includes:

- Radu, Pop & Knabner (2004), *SIAM Journal on Numerical Analysis*, DOI 10.1137/S0036142902405229.
- Belfort et al. (2009), *Vadose Zone Journal*, DOI 10.2136/vzj2008.0108.
- Younes/Belfort et al. (2009), *Environmental Modelling & Software*, DOI 10.1016/j.envsoft.2009.02.010.

This also means that rewriting coarse Richards in hybrid form does not bypass the LARE-CORICHARDS-Q1 result.

## C6A adjudication

C6A establishes four things.

1. A single shared interface flux is sufficient for exact coarse water conservation.
2. Algebraic interface potential and flux variables alone contain no new transient subgrid information.
3. The obvious lowest-order closures collapse to already-tested families: ordinary two-point Darcy, DSE2P, or P0.
4. A genuinely new route must therefore introduce a new physically justified transient subgrid state/closure principle, not merely different algebraic variable placement.

No C6A implementation or hydrological response is authorized.

## Next scientific boundary

The next family is deliberately left unselected. A future read-only choice may consider:

- a realizability-preserving use of conservation-derived shape moments without reopening the rejected C5Z cubic-theta profile;
- a genuinely conserved interface-local or dual-control-volume state, provided it is shown not to be simple layer refinement in disguise;
- a separately justified adaptive/moving-partition representation.

Dynamic flux inertia is not admissible as a Richards-derived shortcut because Richards-Darcy contains no independent flux evolution equation.

The next family must again be derived and preregistered before any hydrological response is observed. No application, performance, speed or production-ROM claim follows from C6A.
