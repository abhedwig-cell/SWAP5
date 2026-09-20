# F-ROM-LARE BC2-C6F conservative sublayer-memory reconciliation

## Decision

**Do not implement fixed upper/lower half-layer inventories as a new ROM family.**

The two-inventory idea is physically clean, exactly conservative and directly realizable. But the read-only derivation shows that its natural Darcy implementation is exactly an ordinary two-times-finer finite-volume column. If the internal transfer is changed to make the model distinct from simple refinement, that transfer becomes a new closure that conservation does not determine.

C6F therefore closes before any hydrological response.

## Candidate state

For macro-layer (i), with midpoint (z_m), define

[
U_i=\int_{z_-}^{z_m}\theta(z)\,dz,
\qquad
L_i=\int_{z_m}^{z_+}\theta(z)\,dz.
]

These are actual water inventories, not fitted profile coefficients.

Total storage and vertical imbalance are

[
S_i=U_i+L_i,
\qquad
D_i=L_i-U_i.
]

For fixed half-control volumes, Richards continuity gives exactly

[
\dot U_i=q_{top,i}-q_{mid,i},
]

[
\dot L_i=q_{mid,i}-q_{bottom,i}.
]

Hence

[
\dot S_i=q_{top,i}-q_{bottom,i},
]

and

[
\dot D_i=2q_{mid,i}-q_{top,i}-q_{bottom,i}.
]

The state therefore carries genuine redistribution memory. The unresolved quantity is immediately visible: the internal midpoint flux (q_{mid,i}).

## Realizability

If the physical constitutive interval is

[
\theta_{min}\leq\theta\leq\theta_{max},
]

then

[
\frac{d_i}{2}\theta_{min}\leq U_i,L_i
\leq\frac{d_i}{2}\theta_{max}.
]

Thus the dynamic state has direct box realizability. No cubic profile inversion, branch selection or post-solution clipping is needed merely to make the inventories physical.

This is a genuine advantage over the failed algebraic profile routes.

## Relation to the first moment

The C5Y state

[
M_i=\int (z-z_c)\theta(z)\,dz
]

and the half-inventory imbalance (D_i) are not the same projection for an arbitrary profile.

If the state is assumed piecewise uniform in the upper and lower halves, however,

[
M_i=\frac{d_i}{4}(L_i-U_i)
=\frac{d_i}{4}D_i.
]

So the proposed state is closely related to the physical asymmetry information that helped in C6D, but it is a new projection unless the piecewise-uniform two-cell ansatz is already imposed.

## The refinement identity

Now assign each half-inventory its mean water content,

[
\bar\theta_U=\frac{2U_i}{d_i},
\qquad
\bar\theta_L=\frac{2L_i}{d_i}.
]

Map those means through the frozen retention and conductivity laws and calculate:

- (q_{mid,i}) by ordinary two-point Darcy flux between the upper- and lower-half centroids;
- macro-interface flux by ordinary two-point Darcy flux between the lower half of layer (i) and the upper half of layer (i+1).

The centroid separation within a macro-layer is (d_i/2). Across macro-layers it is (d_i/4+d_{i+1}/4).

These are exactly the control volumes, state variables, distances, storage balances and interface fluxes obtained by splitting every original macro-layer into two ordinary finite-volume cells.

Therefore the model is not a new sublayer-memory closure. It is a (2N)-cell grid written with macro-layer grouping.

That may be a legitimate resolution choice in another experiment, but current representation-selection authority explicitly distinguishes ordinary layer refinement from a new propagation/state family.

## Why conservation does not close the alternative

To make the family genuinely different from fixed refinement, (q_{mid,i}) must not simply be the ordinary half-cell Darcy flux.

But the two exact conservation equations do not determine (q_{mid,i}). They only show how a chosen internal transfer redistributes the two inventories.

Using an exact steady Darcian transfer between representative upper/lower states reduces to the same steady-equivalent logic already closed through DSE2P.

Using any other transient internal transfer requires an independently justified physical principle, extra state or memory law.

So the proposed two-inventory construction moves the unresolved propagation closure to the midpoint unless it accepts ordinary refinement.

## Scientific interpretation

C6F does **not** invalidate the idea that vertical redistribution memory matters.

On the contrary:

- C5Y provides an exact conservation-derived first-moment balance;
- C6D shows that added vertical asymmetry information can materially improve prescribed-head frozen-state propagation;
- C6E shows that forcing the entire subgrid state onto one instantaneous global algebraic BEMR manifold is not robust under prescribed flux.

C6F adds a new distinction: replacing an algebraic profile by two conserved sub-control-volume inventories removes the realizability problem, but without a new transfer principle the natural implementation is just a finer grid.

## Architecture boundary

A fixed half-layer state would double persistent water-state dimension. Under SWAP5 invariants, such an increase requires a demonstrated representation benefit and must not be relabeled as a novel closure merely because the cells are grouped into macro-layers.

Reference Richards, RossFast and production groundwater coupling remain untouched.

## Next boundary

C6F leaves three defensible read-only directions:

1. a genuinely interface-local conserved state whose control volume is not equivalent to uniformly splitting every layer;
2. an adaptive or moving partition with prospectively derived conservative remapping and a response-independent adaptation rule;
3. an independently derived variational or stability principle that uniquely selects a branch of a BEMR-like family without being constructed from the C6E failures.

No D24/free-running experiment, internal-transfer tuning, performance claim or production-ROM implementation is authorized by C6F.
