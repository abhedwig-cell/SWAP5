# F-ROM-LARE BC2-C6H adaptive/moving-partition reconciliation

## Decision

**Do not implement a generic moving partition as the next physical Layer-ROM family.**

Moving control volumes can be made exactly conservative. The blocker is not mass conservation but identifiability: the Richards equation determines water flux, not computational mesh velocity.

## Exact moving-volume balance

Let the retained layer boundaries move,

[
0=b_0<b_1(t)<\cdots<b_{N-1}(t)<b_N=H,
]

and define

[
S_i(t)=\int_{b_{i-1}(t)}^{b_i(t)}\theta(z,t)\,dz.
]

For

[
\partial_t\theta=-\partial_z q,
]

the Reynolds transport theorem gives

[
\dot S_i
=
q_{i-1/2}-q_{i+1/2}
+
\theta_i^R\dot b_i
-
\theta_i^L\dot b_{i-1}.
]

Equivalently, define flux relative to a moving interface,

[
F_j=q_j-\theta_j v_j,
\qquad v_j=\dot b_j.
]

Then

[
\dot S_i=F_{i-1/2}-F_{i+1/2}.
]

So exact conservation survives moving geometry.

## Why motion is not determined by Richards

The same continuum solution can be represented on many non-crossing moving meshes.

Changing (v_j) changes the computational coordinate but not the physical Darcy flux (q), provided the relative-flux terms are treated consistently.

Therefore (v_j) is an ALE coordinate freedom. Richards conservation and Darcy-Buckingham do not supply an evolution equation for it.

This creates two possibilities.

### Algebraic adaptation

The boundary positions are recomputed from a monitor or equidistribution principle. Then only the water inventories are physical dynamic states. The moving geometry is numerical resolution policy and carries no independent hydrological memory.

### Dynamic boundary positions

The (N-1) positions themselves are retained as memory states. Then an (N)-layer model has approximately (2N-1) dynamic degrees of freedom before other variables, and it needs (N-1) additional motion equations.

Those equations do not follow from bulk Richards physics.

## Monitor functions

Adaptive and moving-mesh methods commonly choose a monitor function that concentrates cells where the solution varies rapidly.

That can be an excellent numerical strategy. It can also be prospectively defined through an error estimator.

But Richards does not uniquely select whether the monitor should use water-content gradient, pressure gradient, conductivity variation, interpolation error, curvature or another quantity, nor does it supply smoothing/relaxation parameters.

So an adaptive mesh is not automatically a new hydrological closure.

Published Richards adaptivity work is consistent with this classification. Clément et al. (2021, DOI 10.1016/j.advwatres.2021.103897) use an a posteriori indicator to adapt resolution near wetting fronts. Hu and Zegeling (2011, DOI 10.1016/j.jcp.2011.01.031) use a selected moving-mesh monitor function.

## Lagrangian water-mass coordinate

There is one especially clean coordinate choice.

For a source-free interval, setting

[
v=q/\theta
]

at a moving boundary gives

[
F=q-\theta v=0.
]

The moving cell then retains constant water mass.

This is parameter-free and kinematically meaningful, but it is still one coordinate choice among many. It does not emerge as a unique layer law from the Eulerian Richards equation.

For broad SWAP use it also creates structural complications: moving computational cells cross fixed soil horizons and root/source fields, root uptake breaks constant-water-mass cells, external infiltration changes total mass, and using only mobile water above residual saturation introduces a different coordinate that becomes ill-conditioned near the residual state.

It remains an interesting numerical formulation, not current authority for a physical Layer-ROM state.

## Sharp-front exception

A moving wetting-front position can become a genuine physical state if the model explicitly adopts a sharp-front/free-boundary approximation and a front-speed law.

That is a distinct reduced hydrological model, not merely an adaptive coordinate representation of unchanged Richards physics. C6H does not select that model family.

## Consequence

C6H closes generic moving geometry as the answer to the present state-sufficiency problem.

Adaptive grids remain a legitimate separate numerical-acceleration workstream. They should not be presented as evidence that a smaller physical Layer-ROM state has been found.

## Next authority

C6I may examine the remaining route: whether the standard Richards energy-dissipation structure supplies an independently derived variational/stability principle that can select reduced dynamics or a unique physical branch.

That review must remain response-free and may not introduce an energy or regularizer designed from the five C6E failures.
