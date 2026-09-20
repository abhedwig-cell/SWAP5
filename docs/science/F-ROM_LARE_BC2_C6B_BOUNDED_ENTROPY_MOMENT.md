# F-ROM-LARE BC2-C6B bounded entropy-moment reconstruction

## Decision

**BEMR selected for response-free mathematical qualification.**

C6B selects a new *mathematical representation family*, not a hydrological model response. No Reference Richards, RossFast, groundwater coupling or production physics is changed.

## Why the first moment is retained

C5Y derived the centered first water-content moment

\[
M_i=\int_{z_-}^{z_+}(z-z_{c,i})\,\theta(z)\,dz
\]

as the smallest additional scalar shape state with an exact projected balance from continuity.

C5Z did not invalidate that state. It showed that a cubic polynomial written **directly in water content** can leave the frozen constitutive interval even when the prescribed storage and first moment themselves are physically realizable.

C6A then showed that explicit interface heads and fluxes without new subgrid information collapse to already-tested two-point, DSE2P or P0 routes.

The remaining question is therefore whether the same conservation-derived (S_i,M_i) state can be mapped to a hydraulic profile in a representation that is realizable by construction.

## Bounded entropy-dual coordinate

For C6C use the already-frozen constitutive qualification interval

\[
L=0.02,\qquad U=0.995
\]

in effective saturation.

Define

\[
y=\frac{S_e-L}{U-L}\in[0,1].
\]

Use the strictly convex binary information-entropy generator

\[
\eta(y)=y\ln y+(1-y)\ln(1-y),
\]

whose dual variable is

\[
v=\eta'(y)=\ln\frac{y}{1-y}.
\]

The inverse is the logistic map

\[
y=\sigma(v)=\frac{1}{1+e^{-v}}.
\]

Hence

\[
S_e(\xi)=L+(U-L)\sigma(v(\xi)).
\]

Every finite coefficient vector therefore gives a profile inside the frozen constitutive interval. There is no clipping or post-solution limiter.

This is an information-theoretic realizability device. It is **not** claimed to be the thermodynamic entropy of soil water.

## Minimum dual profile space

Represent the dual variable in the complete cubic polynomial space,

\[
v_i(\xi)=b_{0,i}+b_{1,i}P_1(\xi)+b_{2,i}P_2(\xi)+b_{3,i}P_3(\xi).
\]

The choice of degree three is fixed by degree count, not response fitting.

For (N) all-moment-enriched layers there are (4N) coefficients. The frozen constraints are:

- (N) storage constraints;
- (N) first-moment constraints;
- (N-1) pressure-continuity constraints;
- (N-1) Darcy-flux-continuity constraints;
- two external hydraulic boundary conditions.

Total: (4N) equations.

Any polynomial basis spans the same four-dimensional space. Legendre coordinates are therefore a numerical basis choice, not an additional scientific shape parameter.

## Maximum-entropy connection

If only mean bounded occupancy and first spatial moment are constrained, the binary maximum-entropy solution has an **affine entropy-dual variable**, (v=a_0+a_1\xi). That is the reason for selecting the logistic dual coordinate.

C6B does not claim that the added (P_2,P_3) modes are extra entropy moments. They are the minimum algebraic degrees needed to enforce the already-frozen hydraulic interface and boundary constraints while keeping the whole profile inside the same bounded dual manifold.

Entropy-based finite-moment reconstruction is established in moment-closure theory, including Levermore (1996, DOI 10.1007/BF02179552). Cernohorsky and Bludman (1994) give the bounded-occupancy maximum-entropy/logistic form in another physical setting. Their radiation physics is not imported here; only the mathematical bounded-realizability construction is relevant. Recent Richards work also treats water-content bound preservation as a structural numerical property rather than harmless post-processing (Wu, Cheng & Shu, 2026, DOI 10.1016/j.advwatres.2026.105324).

## Realizability bound for the frozen interval

For a layer mean (ar S_e) and width (d), the exact first-moment bound under (L\le S_e\le U) is

\[
|M|
\le
\frac{1}{2}\Delta\theta\,d^2
\frac{(\bar S_e-L)(U-\bar S_e)}{U-L}.
\]

C6C must evaluate the unchanged C5Z state/moment domain against this *stricter* bound before attempting the nonlinear solve. The old moment domain is not narrowed if any case is inconvenient.

## Difference from C5Z

BEMR is not a coefficient retune of the failed C5Z polynomial.

C5Z used

\[
\theta=a_0+a_1P_1+a_2P_2+a_3P_3,
\]

which is not realizability preserving.

BEMR uses

\[
S_e=L+(U-L)\sigma(b_0+b_1P_1+b_2P_2+b_3P_3).
\]

No C5Z polynomial order, moment amplitude, constitutive bound, solver tolerance or exposed hydrological residual is adjusted to make this happen. C6C will use the complete unchanged C5Z synthetic domain.

## C6C authorization

C6C may perform only response-free algebraic qualification.

It must test:

1. stricter state/moment realizability;
2. convergence from fixed preregistered starts;
3. numerical branch agreement;
4. realizability by construction;
5. pressure and Darcy-flux continuity;
6. storage and moment recovery;
7. fixed-quadrature consistency;
8. absence of hydrological response data.

If the family fails, it stops. No order increase, bound relaxation, moment narrowing, start/tolerance retuning or localization is allowed after the result.
