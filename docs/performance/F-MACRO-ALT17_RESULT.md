# F-MACRO-ALT17 — Griessfirn controlled-intensity external discrimination

Date: 2026-10-01

Status: `QUALIFIED_EXTERNAL_EVIDENCE_RESULT / INTENSITY_EFFECT_CONTEXT_DEPENDENT / SURFACE_LIMITATION_REQUIRED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Use the controlled Griessfirn Brilliant Blue experiment to test RFM falsification rules F2 and F5:

- source-intensity response;
- transferability of one structural connectivity parameterization.

No RFM equations are changed in this workunit.

## External experiment

Hartmann et al. (2022) used four calcareous moraine age classes:

```text
110 y
160 y
4.9 ka
13.5 ka
```

Each plot was split into adjacent subplots receiving the same total irrigation:

```text
40 mm
```

at three intensities:

```text
20
40
60 mm/h
```

The adjacent-subplot design was chosen specifically to minimize differences in initial and boundary conditions among intensity treatments.

Initial soil moisture during the campaign was consistently high; tensiometers at 10, 30 and 50 cm did not fall below field capacity at the instrumented older moraines.

Five vertical profiles per subplot were excavated and dye patterns were classified by depth, stained-path width, volume density, surface area density and flow type.

## Main empirical result

The intensity response is **not universal across structural soil classes**.

### Old moraines

At 4.9 ka and 13.5 ka:

- dye coverage tends to increase with irrigation intensity;
- surface area density / number of active flow paths increases with intensity;
- the 13.5 ka moraine shows significantly increasing infiltration depth with intensity;
- at both old moraines, higher intensity activates more finger-shaped pathways and more soil volume for water transport.

This is compatible with the central RFM activation idea:

```text
larger source flux
-> larger fraction exceeding distributed matrix intake
-> more preferential pathways activated
```

provided structural parameters are kept fixed within a plot/profile class.

### Young moraines

At 110 y and 160 y, the response differs:

- dye coverage often decreases with increasing intensity;
- surface area density / number of individual flow paths decreases or tends to decrease;
- deeper active paths tend to widen/merge;
- substantial surface runoff was visually observed, particularly on sparse/bare young plots;
- runoff appeared to increase with irrigation intensity.

Thus a model that maps source intensity monotonically into ever-increasing infiltrating preferential supply without a surface limitation would fail for these conditions.

## Consequence for ALT14 F2

The preregistered rule:

```text
preferential activation should increase with source intensity
```

was too broad if interpreted as *atmospheric source intensity* alone.

External evidence requires the more precise formulation:

```text
preferential activation should increase with effective infiltrating source
after surface runoff/sealing limitations are applied
```

This does not rescue RFM by retuning.

It identifies the correct boundary variable.

## Surface-regime implication

ALT11 already required a transition from unponded infiltrability partitioning to a ponding/head-controlled route.

Griessfirn strengthens that boundary:

```text
atmospheric source P
    |
    v
surface boundary owner
    |
    +--> runoff / non-infiltrating excess
    +--> matrix-available infiltrating source
    +--> preferential-available infiltrating source
```

The RFM activation law must operate on physically available infiltration supply, not blindly on total applied rainfall when surface sealing/runoff limits entry.

## No new empirical sealing parameter is authorized yet

The Griessfirn result does **not** justify immediately adding:

```text
new sealing coefficient
new runoff calibration factor
event-specific intensity cap
```

Preferred order:

1. use the existing SWAP top-boundary/ponding/runoff owner where possible;
2. determine whether its accepted surface state already supplies the required effective infiltrating source;
3. only introduce explicit sealing evolution if data show the existing boundary representation is structurally insufficient.

## F5 — geometry transferability

The data support a key distinction already made in RFM:

```text
structural geometry parameters may differ between materially different soil/profile classes
but must remain fixed across forcing events within that class
```

The strong differences among moraine ages are associated with:

- texture and layering;
- organic matter;
- vegetation/root structure;
- hydraulic properties.

This is not evidence for event-dependent connectivity parameters.

Within the two old structural classes, increasing intensity changes the *number and width of active pathways* while the soil structure itself is unchanged.

That is exactly the role intended for RFM activation acting on fixed connectivity.

## Important nuance in flow-type classification

The published flow-type class itself is not a simple monotonic PF metric.

At 13.5 ka, increasing intensity can broaden pathways enough that classification shifts toward more matrix-like flow even while:

- dye coverage increases;
- infiltration depth increases;
- number of paths increases.

Therefore the preferred observables for RFM comparison are not a single categorical 'preferential flow fraction'.

Use jointly:

- infiltration depth;
- dye coverage versus depth;
- surface area density / number of paths;
- path-width distribution;
- runoff occurrence/amount.

## Data availability improvement

A 2024 GFZ dataset is now identified:

```text
DOI 10.5880/GFZ.4.4.2024.001
```

It contains:

- soil-moisture response time series;
- stable isotope profiles;
- 333 trinary Brilliant Blue images/files across the siliceous and calcareous forefields.

The file inventory explicitly includes calcareous Griessfirn soil-moisture files for:

```text
160
4900
13500 year moraines
```

and trinary flow-path images.

This is a much better next empirical source than requesting images manually from the 2022 paper.

## ALT17 decisions

```text
F2_SIMPLE_MONOTONIC_ATMOSPHERIC_INTENSITY = REFINED / TOO BROAD

F2_EFFECTIVE_INFILTRATING_INTENSITY_RESPONSE =
    SUPPORTED AT OLD STRUCTURAL CLASSES

UNBOUNDED_RFM_SOURCE_ACTIVATION =
    EXTERNALLY CONTRADICTED WHERE RUNOFF/SEALING LIMITS ENTRY

SURFACE_BOUNDARY_OWNER =
    REQUIRED

F5_FIXED_GEOMETRY_WITHIN_STRUCTURAL_CLASS =
    NOT FALSIFIED

EVENT_SPECIFIC_CONNECTIVITY =
    NOT JUSTIFIED
```

## Next workunit

F-MACRO-ALT18 should acquire and parse the 2024 GFZ dataset.

Priority:

1. Griessfirn 160, 4900 and 13500 y soil-moisture time series;
2. irrigation timing/intensity reconstruction;
3. response onset at 10, 30 and 50 cm;
4. trinary dye profiles by intensity and depth;
5. derive compact observables that can be compared with RFM without fitting each event.

No new physical parameter is authorized before this data-level test.
