# F-ROM-LARE representation-selection closeout

## Current decision

**STOP_C6A_INTERFACE_VARIABLE_ROUTE_AT_STRUCTURAL_EQUIVALENCE_BOUNDARY**

Current repository authority is the machine-readable
`integration/f-rom/LARE_REPRESENTATION_SELECTION_CLOSEOUT.json`.
This page is the human-readable synthesis through C6A.

No production ROM is selected. Fine Reference Richards remains the scientific reference. No Reference Richards, RossFast or production groundwater-coupling change follows from this workstream.

## What is now established

The representation campaign has separated three issues that were initially entangled.

First, vertical placement matters. C5P showed a causal benefit from moving retained support toward the lower boundary at fixed dimension.

Second, simply adding more ordinary layer states is no longer the active axis once the lower support is held fixed. C5R restored four vertically distributed states above the same B2P5 lower support and obtained essentially the same groundwater response for D8 and D12. The remaining high-resolution discrepancy is therefore much more strongly associated with inter-layer propagation than with missing ordinary state breadth.

Third, the propagation problem has not yet yielded a qualified replacement closure. Several prospectively defined routes have failed before free-running adoption:

- C5T: the zero-parameter DSE2P steady-equivalent interface closure failed its mandatory response-free numerical qualification.
- C5W: the P0 uniform-storage-tendency SCAFP route failed the frozen existence/admissibility contract.
- C5Z: the conservation-derived first-moment state remained numerically well behaved, but its all-layer cubic-theta reconstruction violated the frozen upper constitutive admissibility domain in 14 of 168 cases.
- C6A: explicit algebraic interface head and flux unknowns were shown not to constitute a new physical family by themselves.

## C6A structural-equivalence result

C6A tested the theory behind a structure-preserving coarse Richards formulation with one dynamic integrated storage state per layer and explicit algebraic hydraulic traces and fluxes at the interfaces.

A single shared face flux is sufficient for exact layer-by-layer conservation. The algebraic degree count can also be made square.

The important result is that the count closes only after a local center-to-face hydraulic law has been chosen. The interface variables themselves contain no new transient subgrid information.

For the natural lowest-order choices:

1. linear or frozen-(K) half-cell Darcy relations statically condense to a conventional conservative two-point resistance operator;
2. exact nonlinear steady half-cell relations condense to the DSE2P steady-equivalent closure already closed by C5T;
3. affine within-layer flux implies uniform storage tendency and is therefore the P0 route already closed by C5W.

Allowing a non-affine internal flux reintroduces the unresolved within-layer storage-tendency distribution. That requires either an additional physically justified state or a new subgrid closure principle.

Thus mixed/hybrid variable placement is a useful numerical architecture, but it is not by itself the missing Layer-ROM physics.

## Relation to CoRichards

Same-partition CoRichards remains a numerical comparator-availability result. R3 through R12 did not provide a qualified non-equilibrium dynamic common cohort under the frozen strict authority, whereas the fine R16 control recovered viability.

C6A does not overturn that result. Rewriting coarse Richards in mixed or mixed-hybrid form changes the algebraic formulation and conservation representation, not automatically the reduced physical information content.

## Status of the first moment

C5Z does **not** establish that the centered first water-content moment is a bad physical state.

C5Y's exact projected balance remains valid. What failed was the chosen all-layer cubic-(	heta) hydraulic reconstruction over the frozen synthetic domain. The moment range, polynomial order, constitutive admissibility limits, numerical starts and tolerances were not retuned after exposure.

The first moment may therefore appear in a future physically distinct family only if the new construction is derived independently and does not reopen the rejected C5Z cubic-theta route under modified tuning.

## Current scientific choice boundary

The next family is deliberately unselected.

A future read-only derivation may consider, without using exposed response residuals to choose among them:

- a realizability-preserving conservation-derived moment/state closure that is genuinely distinct from the C5Z cubic-theta reconstruction;
- a conserved interface-local or dual-control-volume state with its own balance law, provided it is shown not to be ordinary layer refinement in disguise;
- an independently justified adaptive or moving-partition representation.

A dynamic interface flux cannot simply be declared as a new state. Richards-Darcy supplies no independent flux-inertia evolution equation, so such a route would need separate physical authority.

## Application and value boundary

Comparator crossing is not application acceptance. C4U remains the purpose-dependent groundwater application-acceptance authority and its external fidelity requirements are still unresolved.

No performance comparison, portable speedup, computational-value claim or production-ROM admission is authorized at this boundary.
