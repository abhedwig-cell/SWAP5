# Soil-hydraulic constitutive relations

This page documents the bounded constitutive-hydraulics formulation used by the frozen Status-A reference Richards route. It is intentionally narrower than the hydraulic-model catalogue in historical SWAP manuals.

The controlling production implementation is the frozen `mod_b110_default_mvg_provider.f90` at scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`. F-SI09 qualified the default analytical provider against the corrected B1.10 oracle. The admitted F-SI09 profile is `SWSOPHY=0`, `SWKIMPL=0`, without hysteresis, tabulated hydraulics, elasticity, frost, macropores, conductivity power-tail or saturated extrapolation.

## What the provider supplies

For each active soil node and pressure head `h`, the value-provider supplies:

- volumetric water content `theta(h)`;
- differential water capacity `C(h)`;
- hydraulic conductivity `K(h,theta)`.

The provider also implements a common-interface output named `dconductivity_dhead`, but in the admitted `SWKIMPL=0` route it is deliberately returned as zero because the production `SWKIMPL=1` derivative path is **not** admitted by F-SI09. That zero is an interface/reservation value, not a claim that the physical derivative `dK/dh` is zero.

The constitutive provider owns neither committed model state nor transaction semantics. It is calculation support for the Richards solver.

## Notation and parameter discipline

Let

```text
c_k = cofgen(k)
```

for the parameter vector of one node. Index notation is used deliberately. The accepted authorities establish the executable mapping and branch behaviour, but do not justify silently replacing every `cofgen` row by a familiar textbook parameter name.

The implementation itself names `c_4` as `alpha`; that code-local name is used below. Other indices remain index-based unless their role follows directly from the executable branch, for example `c_2` as the returned saturated water-content value and `c_3` as the conductivity ceiling used by this provider.

The provider derives additional rows `c_25` through `c_42` during initialisation. Important quantities used below include

```text
c_25 = c_2 - c_1
Hcrit = -1.0e-2 cm
c_26 = c_1 + c_25 / (1 + |c_4 Hcrit|^c_6)^c_7
c_27 = (c_2 - c_26) / (-Hcrit)
c_28 = (1 + |c_4 c_9|^c_6)^(-c_7)
c_29 = c_6 c_7 c_4
c_30 = c_6 - 1
c_31 = c_7 + 1
c_32 = 1 / c_7
```

For the modified branch with `c_9 < 0`, `c_41` and `c_42` are derived from a transition construction around

```text
h105 = 1.05 c_9
```

so the near-entry branch is not replaced here by a generic textbook expression.

## Water retention `theta(h)`

The frozen provider first separates saturated from unsaturated head:

```text
h >= 0  ->  theta = c_2
```

For `h < 0`, two executable branch families exist.

### Branch A — `c_9 > Hcrit`

Close to saturation, for

```text
Hcrit < h < 0
```

the provider uses a linear continuation:

```text
theta_raw = c_26 + c_27 (h - Hcrit)
theta     = min(theta_raw, c_2)
```

At and below `Hcrit`, it uses

```text
u     = |c_4 h|
theta = c_1 + c_25 / (1 + u^c_6)^c_7
```

The explicit linear near-saturation branch is part of the qualified implementation. Describing the whole domain as one unmodified Van Genuchten equation would therefore be inaccurate.

### Branch B — `c_9 <= Hcrit`

Define

```text
h105 = 1.05 c_9
```

For

```text
h >= h105
```

the provider uses the rational transition

```text
theta = c_2 + c_42 h / (1 + c_41 h)
```

while below `h105` it uses the scaled analytical relation

```text
u     = |c_4 h|
theta = c_1 + c_25 / [(1 + u^c_6)^c_7 c_28]
```

This branch preserves the B1.10 transition semantics around the `c_9` threshold instead of imposing a single global retention expression.

## Differential water capacity `C(h)`

The production provider evaluates water capacity separately rather than numerically differentiating `theta` at run time.

At saturation:

```text
h >= 0  ->  C = dt * 1.0e-7
```

where `dt` is the bound step duration.

For Branch A (`c_9 > Hcrit`):

```text
Hcrit < h < 0:
    C = c_27

h <= Hcrit:
    u = |c_4 h|
    C = c_29 * [c_25 / (1 + u^c_6)^c_31] * u^c_30
```

For Branch B (`c_9 <= Hcrit`):

```text
h >= h105:
    C = c_42 / (1 + c_41 h)^2

h < h105:
    u = |c_4 h|
    C = c_29 * [c_25 / (1 + u^c_6)^c_31] * u^c_30 / c_28
```

Finally, for heads close to saturation,

```text
h > -1 cm
```

the implementation enforces

```text
C >= dt * 1.0e-7
```

This is an implementation-level, timestep-dependent capacity floor in the qualified B1.10 provider. It must not be silently omitted when explaining the exact numerical constitutive route.

## Hydraulic conductivity `K(h,theta)`

The conductivity calculation first forms

```text
Se_local = (theta - c_1) / c_25
```

The name here describes the local executable ratio only; it does not introduce a broader parameter convention.

### Branch A — `c_9 > Hcrit`

The implementation applies two explicit guards:

```text
h < -1.0e14 cm                 -> K = 1.0e-10
Se_local > 1 - 1.0e-6          -> K = c_3
```

Otherwise

```text
A = (1 - Se_local^(1/c_7))^c_7
K = c_3 * Se_local^c_5 * (1 - A)^2
```

### Branch B — `c_9 <= Hcrit`

Again,

```text
h < -1.0e14 cm  -> K = 1.0e-10
```

For heads at or above `c_9`:

```text
h >= c_9  -> K = c_3
```

Below `c_9`, define

```text
Se = (1 + |c_4 h|^c_6)^(-c_7) / c_28
A  = [1 - (Se c_28)^(1/c_7)]^c_7
B  = [1 - c_28^(1/c_7)]^c_7
```

then

```text
K = c_3 * Se^c_5 * [(1 - A)/(1 - B)]^2
```

After either branch, conductivity is capped:

```text
K = min(K, c_3)
```

The exact dry and saturation guards are therefore part of the frozen constitutive semantics.

## Ordinary value-provider versus constitutive derivative capability

Two different contracts must not be merged.

### F-SI09 value-provider

F-SI09 qualified the ordinary default-MvG provider by executable bit identity against corrected B1.10 for:

- derived `cofgen(25:42)` rows;
- `theta(h)`;
- `C(h)` including the timestep-dependent near-saturation minimum;
- `K(h,theta)`.

It explicitly did **not** qualify the production `SWKIMPL=1` `dK/dh` route.

### F-SI37 smooth directional derivative

F-SI37 later qualified a separate sibling capability used to propagate one accepted-step direction through the already selected smooth constitutive branch. It analytically forms `dtheta/dh` and `dK/dh` for that fixed smooth branch and multiplies them by the supplied pressure-head direction.

That capability deliberately reports sensitivity unavailable at constitutive switches rather than differentiating through a branch change. Examples include exact surfaces at:

- `h = 0`;
- `h = Hcrit` where applicable;
- `h = 1.05 c_9` in the modified retention branch;
- `h = -1.0e14 cm` for the extreme-dry conductivity guard;
- the Branch-A saturation-conductivity switch `Se_local = 1 - 1.0e-6`;
- `h = c_9` in the Branch-B conductivity switch.

F-SI37 is an owner qualification for a fixed-smooth-route derivative primitive. It does not convert the ordinary F-SI09 provider into an admitted `SWKIMPL=1` route, does not differentiate through timestep/retry/regime changes and does not broaden the frozen Status-A physical denominator.

## Relation to Richards numerics

The constitutive layer provides state-dependent material response to the reference Richards solve. The nonlinear solver remains responsible for residual/Jacobian construction, linear solution and convergence, while the transaction layer remains responsible for acceptance, retry, rollback and commit.

Read [Vertical soil-water flow](soil-water-flow.md) for the physical balance and [Richards discretisation and nonlinear solve](../numerics/richards-solver.md) for the numerical owner boundaries.

## What this page does not claim

This reference does not admit or imply:

- `SWKIMPL=1` production `dK/dh`;
- exponential, bimodal or other hydraulic model families outside the F-SI09 default profile;
- hysteresis, tabulated hydraulic functions, elasticity, frost or macropores;
- conductivity power tails or saturated extrapolation;
- inverse pressure-head functionality;
- differentiability through branch or regime switches;
- a universal semantic renaming of all `cofgen` rows;
- any change to production physics, reference source, solver policy or mass-acceptance semantics.
