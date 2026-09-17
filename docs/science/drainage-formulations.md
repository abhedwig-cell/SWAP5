# Drainage-v1 formulations

This page gives the reviewer-facing equations and branch rules for the seven Drainage-v1 families that are not the simple single-level linear response. The simple linear response remains documented in [Drainage](drainage.md).

The governing denominator is fixed by the branch-pinned F-PM19 completion authority. Equations below are published only where the corresponding scientific qualification and frozen production source agree. Symbols use the owning process contract units; this page does not invent a new universal drainage unit system.

## Sign and accounting convention

Process modules generally expose a soil-to-drain transfer. A positive drainage-side transfer is water leaving the SWAP soil-column accounting domain. At the normalized verification layer, outward water is therefore translated to a negative external-accounting amount.

A reported aggregate, node partition or diagnostic view of one scalar transfer is not a second water transfer.

## 1. Restricted positive single-level DIVDRA spatial distribution

The DIVDRA process does not create an independent scalar drainage law. It spatially distributes an already authoritative positive single-level drainage transfer over active soil compartments.

Let the authoritative scalar transfer be

```text
Q >= 0
```

and let each active saturated compartment have vertical saturated conductivity `Kver_i` and horizontal anisotropy factor `A_i`, so that

```text
Khor_i = Kver_i * A_i
```

The current frozen implementation identifies the water-table compartment using the historical level-to-compartment seam, determines the saturated part of that top compartment, and forms depth-integrated horizontal and vertical conductivity measures over the saturated profile.

For saturated thickness `Dsat`,

```text
Khor_avg = integral(Khor dz) / Dsat
Kver_avg = Dsat / integral(dz / Kver)
A_profile = sqrt(Kver_avg / Khor_avg)
```

The maximum discharge depth is bounded by

```text
Dmax = water_table_depth + 0.25 * drain_spacing * A_profile
```

and by the bottom of the represented profile.

Within the admitted discharge layer, each compartment receives a preliminary fraction proportional to its horizontal transmissivity:

```text
q_i,raw = Q * (saturated_thickness_i * Khor_i) / T_drain
```

where

```text
T_drain = sum(saturated_thickness_i * Khor_i)
```

over the admitted discharge layer.

The bottom participating compartment is finally assigned

```text
q_bottom = Q - sum(q_previous)
```

rather than an independently rounded proportional value. This closure correction makes the node partition sum exactly to the authoritative scalar transfer subject to the represented arithmetic.

### Explicit bounds

The frozen route is positive single-level distribution only. Zero scalar transfer yields an all-zero node partition. A strictly positive transfer at or below the retained legacy active-magnitude seam (`1e-10` in the frozen implementation) is rejected rather than silently reinterpreted. Reverse exchange is not admitted by this route.

The scalar transfer remains authoritative; the node vector is a derived spatial partition.

## 2. DRAMET=1 tabulated drainage response

The tabulated response maps groundwater depth to a signed soil-to-drain exchange by linear interpolation between ordered table points.

Let

```text
D = abs(h_gw)
```

and let table points be

```text
(D_1, q_1), ..., (D_n, q_n)
```

with strictly increasing depths `D_i`.

For an interior segment `D_i < D < D_(i+1)`,

```text
m_i = (q_(i+1) - q_i) / (D_(i+1) - D_i)
q(D) = q_i + (D - D_i) * m_i
```

The table is clamped outside its depth range:

```text
D < D_1  -> q = q_1
D > D_n  -> q = q_n
```

For the interior smooth branch, because `D = abs(h_gw)`,

```text
dq/dh_gw =  m_i   when h_gw > 0
dq/dh_gw = -m_i   when h_gw < 0
```

At an exact table knot the flux is defined but the local derivative is deliberately not claimed. A one-point table with a strictly positive depth is a constant response. The historical one-point zero-depth representation is explicitly fail-closed because its legacy observable behaviour depends on representation padding rather than a normalized physical response law.

F-VQ40 independently qualified this remediated normalized-domain behaviour.

## 3. DRAMET=2 Hooghoudt family

F-VQ38 qualifies the restricted Hooghoudt/Ernst scalar response family for `IPOS=1..5` within its normalized mathematically valid domain. The Hooghoudt family covers `IPOS=1..3`.

### Common activation quantity

For the response families, define

```text
d = (h_gw - h_drain_bottom) / f_shape
```

where `f_shape > 0` is the admitted shape factor.

The frozen B1.10 compatibility cutoff is

```text
epsilon_B110 = 1e-10
```

For

```text
d < epsilon_B110
```

the admitted response is zero with zero stable-side derivative. At exact equality the active flux formula is evaluated, but a derivative is not asserted across the branch boundary.

### IPOS=1

For the active branch, define horizontal resistance

```text
R_h = L^2 / (4 * K_h,top * abs(d))
```

and total resistance

```text
R = R_h + R_entry
```

with positive drain spacing `L`, positive horizontal conductivity `K_h,top`, and nonnegative entry resistance.

The soil-to-drain response is

```text
q = d / R
```

On the stable active branch,

```text
dd/dh_gw = 1 / f_shape
```

and the frozen implementation evaluates

```text
dq/dh_gw = (dd/dh_gw) * (1 + R_h/R) / R
```

### Equivalent depth for IPOS=2 and IPOS=3

First define the effective impermeable-base level

```text
z_base,eff = max(z_base, z_drain - 0.25 * L)
```

and

```text
D_b = z_drain - z_base,eff
x   = 2*pi*D_b / L
```

The raw equivalent depth `d_e,raw` uses three explicit branches.

For `x < 1e-6`:

```text
d_e,raw = D_b
```

For `1e-6 <= x <= 0.5`:

```text
f(x) = pi^2/(4*x) + ln(x/(2*pi))
B    = ln(L/P_wet) + f(x)
d_e,raw = pi*L / (8*B)
```

For `x > 0.5`:

```text
f(x) = sum over i = 1,3,5 of 4*exp(-2*i*x) / (i * (1-exp(-2*i*x)))
B    = ln(L/P_wet) + f(x)
d_e,raw = pi*L / (8*B)
```

The prepared equivalent depth is clipped to the physical depth below the drain:

```text
d_e = min(d_e,raw, D_b)
```

The exact branch boundaries remain explicit; they are not smoothed by the process.

### IPOS=2 and IPOS=3 response

Define

```text
C = 8 * K_eq * d_e + 4 * K_h,top * abs(d)
R_h = L^2 / C
R   = R_h + R_entry
q   = d / R
```

For IPOS=2:

```text
K_eq = K_h,top
```

For IPOS=3:

```text
K_eq = K_h,bottom
```

On the stable active branch the source evaluates

```text
dC/dh_gw = 4 * K_h,top / f_shape
dR_h/dh_gw = -R_h * (dC/dh_gw) / C

dq/dh_gw = (1/f_shape)/R - d * (dR_h/dh_gw) / R^2
```

F-VQ38 independently checked all equivalent-depth branches, cutoff sidedness, fluxes and stable response tangents.

## 4. DRAMET=2 Ernst family

The Ernst family covers `IPOS=4` and `IPOS=5`. It separates geometry-dependent fixed resistance from groundwater-level-dependent vertical resistance.

### IPOS=4 prepared resistance

Define

```text
z_base,eff = max(z_base, z_drain - 0.25*L)
D_b        = z_drain - z_base,eff
```

The frozen preparation computes

```text
R_h   = L^2 / (8 * K_h,bottom * D_b)
R_rad = L / (pi * sqrt(K_h,bottom*K_v,bottom)) * ln(D_b/P_wet)
R_fixed = R_h + R_rad + R_entry
```

The qualification explicitly includes cases where `R_rad < 0`, provided the resulting total response resistance remains mathematically valid and positive where required.

For groundwater level above the material interface,

```text
R_v = (h_gw - z_interface)/K_v,top
    + (z_interface - z_drain)/K_v,bottom
```

with

```text
dR_v/dh_gw = 1/K_v,top
```

At or below the interface,

```text
R_v = (h_gw - z_drain)/K_v,bottom
dR_v/dh_gw = 1/K_v,bottom
```

The response is

```text
R = R_fixed + R_v
q = d / R
```

and, on a smooth branch,

```text
dq/dh_gw = (1/f_shape)/R - d * (dR_v/dh_gw) / R^2
```

At the exact interface, when top and bottom vertical conductivities differ, the flux remains defined but the derivative is not claimed because the branch slope changes.

### IPOS=5 prepared resistance

The horizontal-resistance denominator is

```text
C_h = 8*K_h,top*(z_drain-z_interface)
    + 8*K_h,bottom*(z_interface-z_base,eff)
```

and

```text
R_h = L^2 / C_h
```

The radial term uses

```text
A = geometry_factor * (z_drain-z_interface) / P_wet
R_rad = L / (pi*sqrt(K_h,top*K_v,top)) * ln(A)
R_fixed = R_h + R_rad + R_entry
```

The level-dependent vertical term is

```text
R_v = (h_gw - z_drain) / K_v,top
```

so again

```text
R = R_fixed + R_v
q = d / R
```

with the same smooth-branch derivative form.

F-VQ38 independently qualified IPOS4 and IPOS5 response values, stable tangents, interface derivative semantics and valid negative-radial-resistance cases.

## 5. Empirical interflow drainage-side response

Let

```text
delta = h_gw - h_drain
```

with coefficient `c` and exponent `p`. In the frozen normalized route,

```text
0.01 <= c <= 10
0.1  <= p <= 1
```

For `delta < 0`, the drainage-side contribution is inactive:

```text
q = 0
dq/dh_gw = 0
```

For `delta > 0`,

```text
q = c * delta^p
```

and on the stable branch

```text
dq/dh_gw = c * p * delta^(p-1)
```

At `delta = 0`, the response flux is zero. For `p < 1` the positive-side tangent is singular and is explicitly reported as such. For `p = 1`, the drainage-side limiting tangent equals `c`, but the activation point remains a named branch boundary rather than being silently smoothed.

F-VQ42 qualifies only this drainage-side empirical interflow contribution. The negative-side DRAMET3 infiltration physics is explicitly outside that qualification and is not introduced by this documentation.

## 6. Multi-level drainage exchange aggregation

For ordered drainage levels `j = 1..N`, each constituent provides a signed scalar exchange `q_j` and, where mathematically available, a local sensitivity `dq_j/dh_gw`.

The aggregate transfer is the deterministic legacy-order sum

```text
Q = sum_j q_j
```

The aggregate derivative is defined only when every participating level has a finite, defined, nonsingular derivative:

```text
dQ/dh_gw = sum_j dq_j/dh_gw
```

If any constituent derivative is unavailable, singular or nonfinite, the aggregate flux `Q` remains valid but the aggregate derivative is marked unavailable. Derivative failure therefore does not erase or change the physical mass transfer.

F-VQ43 qualified exact legacy-order aggregation for level counts `1..25`, including mixed-sign cases and conservative sensitivity composition. The production representation can scale beyond that range; F-VQ43 explicitly does not label the dynamic scalability extension as historical legacy equivalence.

## 7. Restricted fixed-weir transactional surface-water runtime

The fixed-weir family contains actual persistent surface-water storage, unlike the stateless scalar response families above. Its state therefore participates explicitly in transactional acceptance, rollback and restart.

### Level-storage mapping

The admitted parameterization contains 22 strictly ordered level/storage knot pairs. Between knots, storage `S(H)` and the inverse level mapping `H(S)` are piecewise linear. Exact stored knot pairs are authoritative coordinates and use exact-knot handling rather than a tolerance-based clamp.

### Weir rating law

For water level `H`, weir head `H_w`, positive rating coefficient `C_w` and admitted exponent `p_w`,

```text
q_rating(H) = C_w * max(0, H-H_w)^p_w
```

### Supply control

Let `S0` be accepted starting storage, `dt` the interval duration and `q_secondary` the nonnegative secondary drainage input to the surface-water store.

First project storage without external supply or weir discharge:

```text
S_projected = S0 + dt*q_secondary
```

The supply target is the storage corresponding to

```text
H_supply = H_w - supply_dip
```

If `S_projected` is below that target, required supply is

```text
q_supply,required = max(0, (S_supply_target-S_projected)/dt)
```

and accepted candidate supply is bounded by the forcing capacity:

```text
q_supply = min(q_supply_capacity, q_supply,required)
```

### No-discharge branch

If the resulting projected storage does not exceed storage at the weir head, the candidate state is simply that projected storage and

```text
q_discharge = 0
```

with exact candidate mass identity

```text
S1 - S0 = dt * (q_secondary + q_supply - q_discharge)
```

### Discharge branch

When projected storage exceeds the weir-head storage, the process solves for a candidate level `H` satisfying

```text
S(H) + dt*q_rating(H) = S_projected
```

within the admitted level domain using bounded bisection and explicit absolute/relative storage tolerances.

After a numerically acceptable level has been found, the authoritative accepted discharge is derived from the exact storage mass equation:

```text
q_discharge = (S_projected - S1) / dt
```

The difference

```text
q_discharge - q_rating(H)
```

is retained separately as a rating-storage numerical residual. It is not allowed to become a water-balance concession.

F-VQ59 independently qualified transaction mass/rollback, external supply input accounting, discharge output accounting, restart behaviour, per-column optional-state ownership and serialized MultiSWAP isolation for the restricted fixed-weir runtime. F-PM19 records its later completion/preservation chain through F-CI52/F-CI52P and current-postimage replay.

## What these formulations do not establish

These equations do not admit:

- drainage options outside the frozen eight-variant Drainage-v1 denominator;
- unrestricted drain-to-soil reverse exchange;
- negative-side empirical DRAMET3 infiltration physics;
- a universal implicit Jacobian coupling of drainage into the Richards solve;
- arbitrary surface-water control structures beyond the restricted fixed-weir contract;
- a universal raw-code sign convention across all modules;
- automatic preservation after future changes on the protected drainage dependency surface.

## Authority map

The documentation-control map for this page is `integration/f-doc/F-DOC22_AUTHORITY_MATRIX.md`.

The key immutable scientific authorities are F-VQ38, F-VQ40, F-VQ42 and F-VQ43, with F-CI32/F-CI33/F-CI36 for restricted DIVDRA and F-VQ59/F-CI52/F-CI52P for the restricted fixed-weir runtime. The eight-variant completion denominator is branch-pinned by F-PM19 rather than mirrored in the current canonical `integration/f-pm` directory.

See also [Drainage](drainage.md), [Water balance, signs and units](water-balance-and-conventions.md), and [Status-A traceability](../status-a/TRACEABILITY.md).
