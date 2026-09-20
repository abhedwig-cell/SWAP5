# F-ROM-LARE BC2-C6I Free-Energy Moment-Onsager derivation

## Decision

**A distinct response-free family is identified: Free-Energy Moment-Onsager (FEMO).**

FEMO is not a BEMR repair. It keeps the conservation-derived storage and first moment, but replaces the static global profile root by the energy-dissipation structure already present in Richards physics.

No hydrological response is used in C6I.

## Richards energy-dissipation structure

Use the current Layer-ROM convention:

- depth (z) positive downward;
- suction (psi=-h);
- water flux (q) positive downward.

Then

[
q=K(\theta)\left(1+\partial_z\psi\right).
]

Choose a capillary free-energy density (F) satisfying

[
F'(\theta)=-\psi(\theta).
]

Define

[
\mathcal E[\theta]
=
\int\left(F(\theta)-z\theta\right)dz.
]

Its variational derivative is

[
\mu=\frac{\delta\mathcal E}{\delta\theta}
=-\psi-z.
]

Therefore

[
q=-K(\theta)\partial_z\mu,
]

and continuity gives

[
\partial_t\theta=-\partial_z q.
]

For an isolated column,

[
\frac{d\mathcal E}{dt}
=
-\int \frac{q^2}{K(\theta)}dz
\le 0.
]

Prescribed heads or fluxes add boundary power but do not change the bulk dissipation structure.

This generalized gradient-flow interpretation of Richards-type porous-media equations is independently established in the literature; see Cancès (2018, DOI 10.2516/ogst/2018067) and the thermodynamic Richards formulation of Kou and Wang (2024, DOI 10.46690/capi.2024.06.01).

## Unique local profile from S and M

For one retained layer (I_i), keep

[
S_i=\int_{I_i}\theta dz,
\qquad
M_i=\int_{I_i}(z-z_c)\theta dz.
]

Define the unresolved profile by the constrained physical-energy problem

[
\theta_i^*(S_i,M_i)
=
\arg\min
\int_{I_i}F(\theta)dz
]

subject to the two moment constraints and the frozen constitutive water-content bounds.

The gravitational energy does not affect this local profile choice because

[
\int_{I_i}z\theta dz=z_cS_i+M_i,
]

which is already fixed by the retained states.

On the monotone retention branch,

[
F''(\theta)=-\frac{d\psi}{d\theta}>0.
]

Thus the functional is strictly convex. For every feasible bounded moment pair there is at most one minimizer; on the closed feasible set a minimizer exists.

Where no bound is active, the KKT equation is

[
F'(\theta)+\lambda_0+\lambda_1(z-z_c)=0,
]

or

[
\psi(z)=\lambda_0+\lambda_1(z-z_c).
]

So the physical quasi-equilibrium profile is affine in suction.

This result is not chosen from C6D or C6E error. It follows from the Richards capillary energy and the already-derived (S,M) state.

## Why this is not BEMR

BEMR reconstructs effective saturation with a cubic polynomial in an information-entropy dual coordinate and solves storage, moment, pressure-continuity, flux-continuity and boundary constraints in one static nonlinear algebraic problem.

FEMO does none of those things.

Its local profile has only the physical moment constraints. Propagation is determined dynamically from the Richards dissipation principle.

Therefore the C6E bad solver attractors are not selected, rejected or regularized. Their algebraic problem is absent.

## Onsager projection onto the moment manifold

Collect the reduced state as

[
a=(S_1,M_1,\ldots,S_N,M_N).
]

The local energy minimizers define a global reduced manifold

[
\theta^*(z;a).
]

For a rate (dot a),

[
\partial_t\theta^*
=
\sum_k
\frac{\partial\theta^*}{\partial a_k}\dot a_k.
]

Continuity determines the spatial derivative of the global flux:

[
\partial_z q=-\partial_t\theta^*.
]

With the appropriate external boundary datum, this gives one globally conservative flux field. Internal interfaces do not receive independent left and right flux branches.

Define hydraulic dissipation

[
\Phi
=
\frac12\int\frac{q^2}{K(\theta^*)}dz.
]

The reduced Rayleighian is

[
\mathcal R_r(\dot a)
=
\Phi
+
\nabla_a\mathcal E_r\cdot\dot a
-
\text{boundary power}.
]

Stationarity with respect to (dot a) produces

[
G(a)\dot a
=
f(a,\text{boundary}),
]

where (G) is the resistance Gram matrix induced by (1/K) and the moment tangent modes.

If (K>0) and the constrained tangent modes are independent, (G) is positive definite on the admissible rate subspace, giving a unique instantaneous reduced evolution.

The C5Y storage and first-moment balances are then not additional closures: they follow exactly by integrating continuity.

## Scientific significance

This is the first post-C5R candidate in which:

1. the extra memory state is conservation-derived;
2. profile realizability is selected by the physical capillary energy;
3. propagation is selected by the physical hydraulic dissipation;
4. prescribed flux does not require the failed C6E static BEMR profile root;
5. no response-fitted coefficient or relaxation time is introduced.

Structure-preserving ROMs for gradient systems are an established general numerical idea (Akman Yildiz, Uzunca & Karasözen, 2019, DOI 10.1016/j.amc.2018.11.008), but that literature does not establish FEMO hydrological fidelity. That remains to be tested prospectively.

## What remains unproven

C6I does not yet prove that the numerical moment map is well-conditioned on the frozen B14 domain, that active bounds are harmless, that the reduced resistance matrix remains positive definite throughout the domain, or that both prescribed-head and prescribed-flux boundary operators are well posed.

Those are C6J questions.

## Next authority

C6J may perform response-free mathematical qualification on the unchanged C6C/C6E state domains.

No hydrological trajectory, free-running FEMO implementation, performance comparison or production claim is authorized before those gates close.
