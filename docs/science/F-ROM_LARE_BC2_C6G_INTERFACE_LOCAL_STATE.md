# F-ROM-LARE BC2-C6G interface-local conserved-state reconciliation

## Decision

**Do not implement an interface-local water-storage state as a new ROM family under unchanged Richards physics.**

C6G generalizes the C6F refinement identity. Moving the extra conserved storage from the interior of a layer to a layer interface does not create new hydrological information unless the interface is given new physical storage capacity.

## General weighted state

For any interface-local weighted water state

[
X_w=\int_a^b w(z)\theta(z)\,dz
]

and Richards continuity

[
\partial_t\theta=-\partial_z q,
]

integration by parts gives

[
\frac{dX_w}{dt}
=
-[wq]_a^b
+
\int_a^b w'(z)q(z)\,dz.
]

This equation cleanly separates the possibilities.

A general smooth or overlapping interface weight does **not** have a pure inflow-minus-outflow conservation law. Its evolution requires an unresolved distributed flux moment.

The only ordinary bulk-water case in which the extra integral reduces to boundary fluxes is a characteristic/indicator weight of an actual physical interval.

## Positive-measure interface control volume

Suppose interface (j) receives an interval

[
I_j=[z_j-epsilon_-,z_j+epsilon_+]
]

and water state

[
W_j=\int_{I_j}\theta dz.
]

If (W_j) is to be a genuine independent physical inventory, the neighboring bulk inventories must exclude the same water. The control volumes must therefore form a non-overlapping partition.

Then (I_j) is simply another finite-volume cell.

Its exact balance is valuable, but structurally this is local grid refinement/repartitioning. A vertex-centered or dual-grid presentation does not change that identity.

## Overlapping interface state

If the original macro-layer totals are retained unchanged and (W_j) overlaps them, the same water appears in more than one integral.

Those quantities may still be used as a redundant moment basis, but they are no longer independent physical inventories. The weighted-state balance above then exposes the unresolved internal flux moment that must be closed.

That returns to the moment/state-closure problem rather than producing a new conserved interface state.

## Zero-thickness interface

For bounded water content,

[
\lim_{epsilon\to0}\int_{z_j-epsilon}^{z_j+epsilon}\theta dz=0.
]

So an ordinary zero-thickness interface has no finite independent water inventory in the bulk Richards equation.

A nonzero lower-dimensional storage law such as

[
W_j=C_j(\lambda_j)
]

would be additional membrane, fracture, contact or interface-capacitance physics. Such physics may be meaningful in another model, but it is not a reduced representation of the unchanged SWAP/Richards soil column.

## Relation to numerical literature

Finite-volume and dual-control-volume Richards methods enforce local conservation by integrating the governing equation over positive-measure control volumes. Farthing and Ogden (2017, DOI 10.2136/sssaj2017.02.0058) review this distinction between cell-centered and dual/vertex-centered conservation.

For ordinary layered unsaturated soils, interface treatments such as Romano, Brunone and Santini (1998, DOI 10.1016/S0309-1708(96)00059-0) enforce hydraulic/flux interface conditions rather than introducing an independent singular water-storage state.

These methods support the structural distinction used here: an interface **control volume** is a discretization volume; an interface **capacity** would be additional physics.

## Consequence

C6F and C6G together now close the fixed conserved-subcell idea quite generally:

- fixed half-layer storage is ordinary refinement;
- fixed interface-centered storage is ordinary refinement/dual repartition;
- overlapping interface moments need another closure;
- zero-measure finite storage is new physics.

No response experiment is needed to establish this identity.

## Next authority

The next read-only direction is C6H: adaptive or moving partitions.

That direction can potentially change *where* a fixed number of states carry information rather than simply adding fixed cells. C6H must first derive exact moving-control-volume conservation and then determine whether any adaptation law is independently justified rather than chosen from exposed LARE errors.

No hydrological response, speed claim or production implementation is authorized by C6G.
