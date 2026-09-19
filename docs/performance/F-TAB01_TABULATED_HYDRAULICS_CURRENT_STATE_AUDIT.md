# F-TAB01 — Tabulated soil hydraulics current-state audit

**Status:** AUDIT_OPEN  
**Canonical start:** `integration/f-ci-canonical@f5988c04ee93d92d54876696b5414bd326360ad9`  
**Scope:** correctness and scientific/numerical qualification only. No performance claim and no production admission.

## Question

Does the historical SWAP tabulated soil-hydraulics route provide a sufficiently correct and internally consistent representation of the currently admitted SWAP5 constitutive hydraulics to justify a later performance investigation?

The performance hypothesis is deliberately deferred until the correctness gate is closed.

## Current SWAP5 finding

The current SWAP5 production constitutive authority is the analytical default-MvG provider in
`src/solver/mod_b110_default_mvg_provider.f90`.

The admitted F-SI09 profile is bounded to `SWSOPHY=0`, `SWKIMPL=0` and excludes tabulated hydraulics. The provider supplies `theta(h)`, `C(h)` and `K(h,theta)`. Its common-interface `dconductivity_dhead` output is a reservation value in the admitted route, not an admitted `SWKIMPL=1` constitutive derivative.

Therefore tabulated hydraulics are **not currently a reachable or admitted SWAP5 production capability**. This is a capability gap, not evidence that the historical interpolation mathematics is defective.

The migration map already classifies legacy `sptabulated.f90` as `RETAIN_NUMERICS_EXTRACT`, with the intended target being an explicit immutable constitutive/numerical utility.

## Upstream modernization finding

The public `SWAP-model/SWAP` modernization line independently reached the same operational state.

At commit `26fa1c0439b099678ef90fd0274e27da013b7792` on 2026-05-24 the historical `swsophy=1` implementation was moved to a dormant source location. The stated reason was absence of live dispatch and regression coverage after the TOML migration. The TSPACK body was excluded from the build and the former calls from `watcon`, `moiscap`, `dhconduc`, `hconduc` and `prhead` were replaced by fail-fast guards.

This is evidence of **lack of maintained execution coverage**, not a demonstrated scientific failure of the table route.

## Historical interpolation semantics

The preserved legacy route stores, per table/material:

1. pressure head `h`;
2. water content `theta`;
3. hydraulic conductivity `K`;
4. spline derivative associated with `theta`;
5. spline derivative associated with `K`;
6. tension factors for the `theta(h)` interpolation;
7. tension factors for the `K(h)` interpolation.

The historical implementation uses Renka TSPACK tension splines.

With the historical logarithmic transform enabled:

```text
x = -log(1 - h)       for h <= 0
yK = log(K)
```

The interpolation is then performed in transformed coordinates. Importantly, `C=dtheta/dh` and `dK/dh` are not independent table columns used blindly as separate constitutive functions. They are evaluated as derivatives of the same splines used for `theta` and `K`, followed by the corresponding chain-rule back transformation.

That construction is internally preferable to independently interpolating values and derivatives because value/derivative consistency is retained within the spline representation.

## Static correctness concerns found before execution qualification

### 1. Conductivity positivity is under-validated for log(K)

The historical reader accepts tabulated conductivity values down to zero, while the enabled interpolation path applies `log(K)`.

Therefore `K=0` is accepted by the input range check but is outside the finite logarithmic transform domain. A reactivated provider must require finite `K > 0` whenever log-conductivity interpolation is selected.

### 2. Pressure-head transform domain is under-specified

The historical reader accepts a broad numerical pressure-head range, while the active transform assumes the usual unsaturated table domain and the runtime path is formulated around `h <= 0`.

A reactivated route must explicitly validate the table pressure-head domain and require a saturation endpoint at `h=0`. Positive-head table entries must not be accepted implicitly.

### 3. Endpoint derivative assumptions are part of the numerical model

The preprocessing route imposes endpoint behaviour when constructing the tension splines. This means a coarse or poorly distributed table can satisfy monotonic raw input checks yet still differ materially from the analytical constitutive response between knots.

Table density and knot placement are therefore part of the qualification envelope, not merely an input-format detail.

### 4. Near-saturation capacity in SWAP5 is timestep dependent

The admitted SWAP5 analytical provider applies the B1.10 timestep-dependent capacity floor:

```text
h >= 0      -> C = dt * 1e-7
h > -1 cm   -> C = max(C, dt * 1e-7)
```

A static table of `C` cannot reproduce this exactly for arbitrary `dt`.

For equivalence, the candidate table provider should derive the raw capacity from the `theta` interpolant and apply the same timestep-dependent floor after interpolation. The floor must not be baked into an immutable material table.

## Initial qualification boundary

F-TAB01 starts only inside the already admitted analytical denominator:

- default unimodal MvG constitutive family;
- `SWKIMPL=0`;
- no hysteresis;
- no frost;
- no macropore conductivity modification;
- no alternative/PDI/bimodal hydraulic model;
- no claim about inverse pressure-head use;
- no production admission;
- no speedup claim.

Broader combinations require separately named successor slices after this denominator is qualified.

## Correctness experiment

Construct tabulated candidates from the **same admitted SWAP5 analytical provider** and compare them on independent evaluation points not used to build the tables.

### Constitutive gate

For representative soil parameter sets and multiple timestep durations, compare:

- `theta(h)`;
- raw spline-derived `C(h)`;
- final `C(h)` after the SWAP5 timestep-dependent floor;
- `K(h)`.

Evaluate across a dense pressure-head domain, with additional points concentrated around every analytical branch or guard surface relevant to the admitted provider.

Required explicit probes include:

- `h=0`;
- the near-saturation continuation around `Hcrit=-1e-2 cm`;
- `h=-1 cm`, where the capacity-floor condition changes;
- very dry heads;
- the lower end of the candidate table;
- conductivity approach to saturation.

Report absolute and relative error separately. Do not use one global relative metric near values that approach zero.

### Structural consistency gate

For every table:

- pressure head strictly increasing;
- `theta` strictly nondecreasing;
- `K` strictly positive and nondecreasing;
- finite transformed coordinates;
- exact or explicitly bounded saturation endpoint;
- no interpolation overshoot that violates physical bounds;
- numerical derivative of interpolated `theta` consistent with returned raw `C`;
- interpolation is continuous at internal knots to the continuity order claimed by the provider.

### Solver-level A/B gate

Only after the constitutive gate passes, run identical Richards cases with:

A. admitted analytical default-MvG provider;  
B. candidate tabulated provider.

Compare at minimum:

- accepted pressure-head trajectory;
- water-content trajectory;
- bottom and internal fluxes;
- groundwater level where present;
- cumulative water balance;
- accepted timestep sequence;
- retry/convergence counts.

A table that gives small pointwise constitutive errors but materially changes solver acceptance/retry behaviour is not yet qualified.

## Performance gate

Performance measurement is explicitly downstream of correctness.

Do not assume the historical TSPACK implementation is faster than the analytical provider. Its interval lookup, local array assembly, tension-spline evaluation and exponential/logarithmic back transformations may offset the saved MvG algebra.

Once correctness is closed, benchmark at least:

1. admitted analytical provider;
2. preserved TSPACK-equivalent table provider;
3. only if justified, a simpler immutable lookup/interpolation kernel under the same accuracy envelope.

This separates the scientific question “does table hydraulics work?” from the engineering question “which interpolation implementation is actually faster?”

## Provisional disposition

**CURRENT_SW5_STATUS = NOT_REACHABLE_NOT_ADMITTED**

**HISTORICAL_ALGORITHM_STATUS = PLAUSIBLE_BUT_UNQUALIFIED**

**NEXT_GATE = EXECUTABLE_CONSTITUTIVE_EQUIVALENCE**

No conclusion about speedup is authorized before that gate is closed.
