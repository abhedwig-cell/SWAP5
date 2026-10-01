# F-MACRO-ALT11 — source-bound hydraulic activation interface result

Date: 2026-10-01

Status: `QUALIFIED_RESEARCH_INTERFACE_RESULT / K_BOUND / SURFACE_SORPTIVITY_SEMANTICS_OPEN`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Bind the RFM-1B activation law to actual SWAP hydraulic ownership instead of treating `K_matrix` and `S_matrix` as free external inputs.

Leading activation law:

```text
b50(tau) = K_surface + S_surface / (2*sqrt(tau))
B ~ LogNormal(log(b50), sigma_B)
q_matrix = E[min(R, B)]
q_pref   = R - q_matrix
```

with one structural heterogeneity parameter `sigma_B`.

## K_surface binding

Current SWAP5 already exposes the required accepted matrix state through:

```text
process_hydraulic_view_t:
    pressure_head(:)
    water_content(:)
    ponding_depth
    groundwater_level
```

and the admitted B1.10 default MvG constitutive provider exposes:

```text
evaluate_point_conductivity(node_index, pressure_head, water_content)
```

or equivalently the qualified `b110_hconduc` route.

Therefore the clean RFM activation binding is:

```text
accepted surface h, theta
        |
        v
qualified constitutive provider
        |
        v
K_surface
```

No new conductivity equation and no duplicated MvG implementation are required.

### Decision

```text
ALT11_K_SURFACE_BINDING = CLOSED_FOR_DEFAULT_MVG_RESEARCH_PROFILE
```

The production profile remains bounded by the provider's admitted constitutive scope.

## S_surface binding — important semantic distinction

The current macropore module already supports sorptivity calculated from hydraulic functions according to Parlange when `SWSORP=1`.

However, that sorptivity is used for **lateral absorption from a wetted macropore wall into matrix aggregates**.

The official Andelst case uses:

```text
SORPFACPARL = 0.33  top layers
SORPFACPARL = 0.50  deeper layers
```

and the manual explicitly explains that this correction can represent water-repellent coatings on aggregate/macropore-wall surfaces.

That makes the legacy quantity conceptually:

```text
S_wall
```

not automatically:

```text
S_surface
```

for rainfall infiltration through the soil surface.

Reusing `SorpDmCp` or `SORPFACPARL` directly in RFM activation would therefore conflate two different interfaces.

### Required RFM distinction

```text
S_surface = constitutive matrix intake sorptivity at the soil surface

S_wall    = macropore-wall lateral-exchange sorptivity
```

They may use the same underlying hydraulic functions, but they are not assumed to share interface correction factors.

### Decision

```text
ALT11_REUSE_EXISTING_WALL_SORPTIVITY_AS_SURFACE_SORPTIVITY = REJECTED
ALT11_SURFACE_SORPTIVITY_FROM_SHARED_HYDRAULICS = CONTINUES
```

## Preferred S_surface implementation direction

The preferred research interface is a pure constitutive helper:

```text
evaluate_surface_sorptivity(
    accepted top-node hydraulic parameters,
    accepted top-node theta/h
) -> S_surface
```

using the same authoritative hydraulic relations as SWAP.

It must:

- carry no persistent state;
- own no event history;
- introduce no macropore geometry dependency;
- avoid `prhead` shortcuts that are not exact inverses for the active hydraulic model;
- be separately qualified against the selected constitutive relation.

For the initial default-MvG research profile, this can be built against the same B1.10 parameter authority as the admitted conductivity provider.

A general production version covering all SWAP hydraulic models is a later scope.

## Current reference surface activation

The official SWAP macropore theory currently has two surface-entry routes.

### 1. Direct atmospheric partition

```text
I_pr = A_mp * P
```

where `A_mp` is the total macropore area/volume fraction at the soil surface.

For the current Andelst example:

```text
VLMPSTSS = 0.04
PPICSS   = 0.5
```

so the static macropore surface fraction alone is 0.04, with MB and IC each receiving half of the corresponding surface macropore fraction. Dynamic shrinkage volume can modify total surface macropore area.

This route has a source-proportional direct component even at weak source intensity whenever surface macropore area is present.

### 2. Ponding inflow

When the matrix top boundary is ponded, additional inflow is:

```text
I_ru = h0 / gamma_Iru
```

with a macropore inflow resistance derived from surface macropore geometry.

In the Andelst case:

```text
PNDMXMP = 0
```

so there is no positive ponding-height threshold before this route becomes available.

## Revised RFM-1B surface contract

The activation replacement should not collapse both reference mechanisms into one formula.

### Regime A — unponded/source-controlled

Use the matrix-infiltrability distribution:

```text
b50(tau) = K_surface + S_surface/(2*sqrt(tau))
q_matrix = E[min(R, B)]
q_pref   = R - q_matrix
```

This replaces the legacy direct surface-area-proportional partition as an alternative physical hypothesis.

### Regime B — ponded/head-controlled

Once an accepted/candidate surface state is ponded, use an explicit head-controlled macropore overflow/inflow contract.

The leading conservative option for research is to preserve the current SWAP-style `I_ru` resistance mechanism initially, rather than invent a second new law in the same experiment.

This gives:

```text
unponded:
    R -> infiltrability partition

ponded:
    matrix top-boundary solve
    + explicit macropore ponding inflow
```

with exact mass ownership so atmospheric input is not double counted.

## Event-age semantics

`tau` belongs to the **surface source event**, not to the Philip wall-exchange event.

These histories must remain separate:

```text
tau_surface_activation
tau_wall_exchange(z)
```

Recommended first event rule:

- start/reset `tau_surface_activation=0` when positive atmospheric liquid input begins after a zero-input interval;
- advance during continuous positive source;
- freeze/reset when source ceases according to a preregistered gap rule;
- do not reuse wall-contact age.

The gap/reset sensitivity should be tested rather than hidden in code.

## State impact

The dynamic activation does not require a per-node persistent hydraulic field.

Required activation state is at most:

```text
surface source-event age tau_surface
```

plus immutable `sigma_B`.

`K_surface` and `S_surface` are derived from accepted hydraulic state.

This preserves the compact-state objective.

## First direct reference comparison that is now possible

Even before exact full case replay, the source-level structural contrast is clear:

Current direct route:

```text
q_pref_direct / P = A_mp
```

for the direct atmospheric component.

RFM unponded route:

```text
q_pref / P = F(P, K_surface, S_surface, tau, sigma_B)
```

Therefore the new route intentionally predicts near-zero preferential activation when a weak source can be accommodated by matrix infiltrability, even if structural macropores are present.

That is a changed physical hypothesis, not a refactoring.

## What remains blocked for quantitative Andelst replay

A quantitative time-series comparison still needs, at each atmospheric interval:

- top-node accepted `h` and `theta`;
- authoritative `K_surface`;
- an authoritative `S_surface` evaluator;
- total current surface macropore area for the reference `A_mp P` route;
- ponding/head history.

The repository has the constitutive conductivity authority, but the exact B1.11 macropore source postimage and a qualified surface-sorptivity service are not yet present.

Therefore:

```text
ALT11_REFERENCE_STRUCTURAL_COMPARISON = CLOSED
ALT11_FULL_ANDELST_DYNAMIC_PARTITION_REPLAY = OPEN
```

## Next workunit

F-MACRO-ALT12 should implement and qualify the pure `S_surface` constitutive helper for the default-MvG research profile.

After ALT12, RFM-1B activation can be driven entirely by actual SWAP5 accepted top-node hydraulic state:

```text
h_1, theta_1
    -> K_surface
    -> S_surface
    -> b50(tau)
    -> q_pref
```

without free `b50` or characteristic-time parameters.
