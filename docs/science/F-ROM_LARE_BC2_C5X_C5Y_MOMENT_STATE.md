# F-ROM-LARE C5X-C5Y — minimum subgrid shape state

## Why storage-only reconstruction stops

C5V showed that layer-integrated storage alone does not uniquely select a transient within-layer hydraulic profile. C5W then tested the least-assumptive storage-only candidate, P0 uniform storage tendency, prospectively and without hydrological response. The P0 map was conditionally unique where it existed, but it was not broadly admissible over the frozen B14 synthetic domain.

The two remaining storage-only profile families — quadratic native pressure/suction and transformed hydraulic potential — are feasible ansatz families, but neither follows uniquely from the retained storage state or from conservation. C5X therefore stops storage-only ansatz shopping and reopens state sufficiency read-only.

This does not invalidate C4K. C4K only found that its bounded direction/history ambiguity test did not demonstrate missing state. It explicitly did not prove universal memoryless sufficiency.

## First centered water-content moment

For a retained layer with width d and centroid zc, define total storage

S = integral theta(z) dz

and the centered first moment

M = integral (z-zc) theta(z) dz.

M measures whether retained water is top-heavy or bottom-heavy inside the layer at identical total storage.

With depth and flux positive downward, local continuity is

d theta / dt = - d q / dz.

The projected balances are exact:

dS/dt = q_top - q_bottom

and

dM/dt = integral q(z) dz - d/2 * (q_top + q_bottom).

No empirical coefficient enters this moment balance.

## Conservation-native theta hierarchy

Use xi in [-1,1], with z-zc = d xi / 2, and the Legendre basis

P0 = 1,
P1 = xi,
P2 = (3 xi^2 - 1)/2,
P3 = (5 xi^3 - 3 xi)/2.

For a moment-enriched layer,

theta(xi) = a0 + a1 P1 + a2 P2 + a3 P3.

Storage and moment fix the first two coefficients analytically:

a0 = S/d,
a1 = 6 M / d^2.

Only a2 and a3 remain algebraic shape unknowns. Pressure and conductivity are then obtained from the frozen constitutive maps psi(theta) and K(theta), and Darcy flux uses the reconstructed theta gradient.

For N all-moment-enriched layers there are 2N higher-mode unknowns. There are also exactly 2N hydraulic constraints: pressure and flux continuity at N-1 internal interfaces plus two external boundary conditions.

More generally, if only m of N layers are moment-enriched, storage-only layers use quadratic theta profiles and enriched layers cubic profiles. The unknown and constraint counts are both 3N+m.

This degree count removes the C5V algebraic underdetermination. It does not prove existence, uniqueness or admissibility.

## Exact physical moment limit

If theta_r <= theta <= theta_s and the layer mean effective saturation is Se, then the maximum centered moment magnitude allowed by the box constraint is

|M| <= 0.5 * (theta_s-theta_r) * d^2 * Se * (1-Se).

The extremum places all excess water at one layer edge. C5Z uses a normalized moment coordinate inside this exact bound; no exposed hydrological trajectory defines its synthetic moment states.

## C5Z qualification boundary

C5Z enriches every retained layer with a moment state so localization is not yet a design variable. It asks only whether the resulting theta-polynomial algebraic hydraulic map is admissible and numerically single-branch over a prospectively frozen B14 synthetic state/moment domain.

No hydrological response, moment localization rule, performance claim or production-ROM route is authorized by C5Y or C5Z.
