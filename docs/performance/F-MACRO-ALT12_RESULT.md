# F-MACRO-ALT12 — default-MvG surface sorptivity research qualification

Date: 2026-10-01

Status: `QUALIFIED_STANDALONE_RESEARCH_RESULT / FORMULA_AND_INTERFACE_CLOSED / PRODUCTION_BINDING_OPEN`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Close the missing hydraulic input in the RFM-1B activation law:

```text
b50(tau) = K_surface + S_surface/(2*sqrt(tau))
```

without:

- reusing macropore-wall sorptivity semantics;
- introducing a free `b50`;
- introducing a characteristic time parameter;
- requiring an inverse retention function.

## Sorptivity identity used

A standard Parlange sorptivity definition can be written in moisture space as:

```text
S^2(theta_i)
= integral_theta_i^theta_s
  (theta_s + theta - 2 theta_i) D(theta) dtheta
```

with:

```text
D = K / C
C = dtheta/dh
```

Using:

```text
dtheta = C dh
```

gives the pressure-head-space identity:

```text
S_surface^2
= integral_h_i^0
  (theta_s + theta(h) - 2 theta_i) K(h) dh
```

This transformation is central to ALT12.

It means a surface-sorptivity evaluator only needs the already authoritative constitutive values:

- `theta(h)`;
- `K(h,theta)`.

It does **not** need:

- `prhead(theta)`;
- a separately coded diffusivity;
- a numerical `C(h)` division;
- any macropore-wall geometry.

## Architectural result

The future typed research service can therefore be expressed as:

```text
evaluate_surface_sorptivity(
    constitutive_provider,
    top_node,
    accepted_pressure_head
) -> S_surface
```

Internally it integrates over `h` from accepted `h_i` to saturation and requests `theta` and `K` from the same constitutive authority used by the soil-water solver.

That is preferable to embedding a second MvG implementation in a production macropore module.

## Wall versus surface sorptivity

ALT11 established that existing `SORPFACPARL` belongs to lateral macropore-wall exchange and can account for wall/aggregate-surface effects such as water repellency.

ALT12 therefore applies:

```text
S_surface = raw constitutive matrix sorptivity
```

unless a future explicit soil-surface correction is separately justified.

It does not apply:

```text
SORPFACPARL
```

by default.

## Standalone executable mirror

Persisted harness:

`tools/research/macropore_alt12_surface_sorptivity.py`

The script mirrors the documented B1.10 default-MvG `theta(h)` and `K(h)` branches solely for standalone research screening.

It is not the intended production implementation. Production binding should call the actual provider.

## Numerical screen

A representative default-MvG profile was used only as a consistency screen:

```text
theta_r-like row   0.08
theta_s            0.45
K ceiling          50
alpha              0.02
n-like             1.6
m-like             1 - 1/1.6
conductivity exp   0.5
```

Results:

```text
h =   -10 cm: K ~ 19.55, S_surface ~  2.23
h =   -50 cm: K ~  2.30, S_surface ~  9.47
h =  -100 cm: K ~  0.396, S_surface ~ 13.34
h =  -300 cm: K ~  0.0122, S_surface ~ 17.52
h = -1000 cm: K ~  0.00019, S_surface ~ 19.77
```

The important behavior is not the illustrative numbers themselves.

The screen demonstrates that:

- point conductivity falls strongly as the profile dries;
- capillary sorptivity increases toward a bounded dry-state value;
- both quantities can therefore compete naturally in dynamic `b50(tau)`.

This is exactly the crossover behavior required by ALT09/10.

## Quadrature qualification

The standalone helper uses midpoint integration in pressure-head space.

At `h_i=-100 cm`, increasing panels through:

```text
1000
2000
5000
10000
20000
```

produces a convergent sorptivity estimate.

The research implementation should use an adaptive quadrature or a bounded tabulated/integral accelerator if profiling later shows this evaluation material in runtime.

No performance claim is made here.

## Why this is better than using C or inverse theta

The transformed integral avoids two historically sensitive paths:

1. `prhead`, whose legacy implementation was not the true inverse of all modern retention functions;
2. explicit `D=K/C`, which can be numerically awkward close to saturation or where capacity has implementation floors.

The integrand:

```text
(theta_s + theta(h) - 2 theta_i) K(h)
```

is directly evaluable from the constitutive value provider.

## RFM-1B activation contract after ALT12

For an unponded liquid-input event:

```text
accepted top h, theta
      |
      +--> K_surface via constitutive provider
      |
      +--> S_surface via constitutive integral
      |
      v
b50(tau) = K_surface + S_surface/(2 sqrt(tau))
      |
      v
B ~ LogNormal(log b50, sigma_B)
      |
      +--> matrix intake
      +--> preferential input
```

For ponded conditions, the separate head-controlled preferential inflow branch from ALT11 remains.

## Parameter consequence

The leading activation option now needs no free:

- `b50`;
- characteristic infiltration time;
- fixed bypass fraction.

The new structural activation parameter remains:

```text
sigma_B
```

plus any future explicitly justified surface-interface correction.

## Qualification boundary

What is closed:

```text
surface sorptivity physical definition
h-space transformation
separation from wall sorptivity
default-MvG standalone numerical behavior
RFM activation interface
```

What remains open:

```text
typed implementation calling the actual provider
bit/numerical comparison of helper against an independent oracle
all-hydraulic-model support
actual Andelst top-state time series
direct reference activation replay
runtime optimization
```

## Decision

```text
ALT12_SURFACE_SORPTIVITY_FORMULA = QUALIFIED_RESEARCH_RESULT
ALT12_USE_OF_LEGACY_WALL_FACTOR = REJECTED
ALT12_PRODUCTION_BINDING = OPEN
RFM1B_ACTIVATION_HYDRAULIC_CLOSURE = SUFFICIENT_FOR_NEXT REFERENCE EXPERIMENT
```

## Next large block

F-MACRO-ALT13 should stop adding physics and build the first source-bound activation comparator:

```text
same top-state and atmospheric forcing

reference:
    A_mp * P
    + ponding inflow when active

RFM-1B:
    dynamic b50 partition
    + same ponding inflow contract initially
```

The comparator should report:

- preferential input amount;
- onset time;
- source-intensity response;
- antecedent-state response;
- mass receipts.

If the official case state time series cannot yet be reconstructed, ALT13 should first create the comparator interface and use retained case snapshots without claiming full-case equivalence.
