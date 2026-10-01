# F-MACRO-ALT15 — evidence acquisition and discrimination plan

Date: 2026-10-01

Status: `QUALIFIED_EVIDENCE_ACQUISITION_PLAN / EXTERNAL_DATA_IDENTIFIED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

ALT14 preregistered failure conditions for the Reduced Functional Macropore (RFM) hypothesis.

ALT15 identifies external evidence capable of actually testing those conditions.

The objective is explicitly not to find datasets that make RFM look good.

The objective is to find datasets that can distinguish:

```text
observations
vs
current SWAP direct-entry hypothesis
vs
RFM activation/connectivity hypothesis
```

without event-by-event parameter tuning.

## Evidence tier 1 — NEON preferential-flow event database

The strongest broad activation dataset identified is the recent NEON preferential-flow synthesis used by Li et al.

Its source observations include:

- precipitation aggregated to 10-min intervals;
- volumetric soil moisture at 1-min resolution;
- up to eight sensor depths from about 6 to 200 cm;
- five soil plots per site;
- multi-year records across 40 terrestrial sites;
- event delineation;
- antecedent soil moisture metrics;
- two preferential-flow detection methods:
  - non-sequential response;
  - velocity threshold.

The derived preferential-flow database and analysis code are publicly available, while the underlying precipitation and soil-moisture observations are available through NEON.

### Why this is high value

It can directly test the RFM claims that:

```text
PF occurrence should increase with source intensity
weak events can produce little/no preferential response
antecedent state modifies activation
deep response timing carries preferential-flow information
```

The published analysis reports a steep increase in PF likelihood over roughly the 5–12 mm/h rainfall-intensity range before a plateau at higher intensities.

That is strikingly close in form to the threshold-like-but-smooth behavior produced by the RFM activation function, but ALT15 does not count that resemblance as validation.

The actual event data should be used.

### Proposed use

Do not fit full SWAP first.

First construct event records:

```text
site/profile
rainfall intensity
rainfall duration/amount
antecedent theta statistics
sensor depths
response onset at each depth
NSR/VT PF classification
```

Then test whether one site/profile-specific `sigma_B` predicts the ordering of PF events without event-specific adjustment.

This is a direct F1/F2/F3/F4 screen.

## Evidence tier 1 — Griessfirn controlled irrigation-intensity experiment

Hartmann et al. applied the same irrigation amount:

```text
40 mm
```

at three intensities:

```text
20
40
60 mm/h
```

to subplots within the same experimental plots.

Five vertical profiles were excavated per subplot and dye patterns were analyzed.

This is exceptionally useful because amount and intensity are separated deliberately.

### Proposed use

For each soil/plot class compare:

```text
observed dye coverage vs depth
observed flow-path/finger counts
irrigation intensity
```

against:

```text
SWAP
RFM with one unchanged geometry/connectivity parameter set
```

Reject the continuous connectivity/activation combination if matching intensity response requires changing connectivity parameters between the 20, 40 and 60 mm/h treatments.

This is primarily F2 + F5.

## Evidence tier 2 — Hardie antecedent-moisture experiment

Hardie et al. provide a particularly sharp antecedent-state contrast in a texture-contrast soil.

A 25 mm Brilliant Blue application under contrasting initial wetness yielded reported average infiltration behavior approximately:

```text
low antecedent moisture:
    depth ~1.03 m
    wetting-front velocity ~1160 mm/h

high antecedent moisture:
    depth ~0.35 m
    velocity ~120 mm/h
```

This is scientifically important for the present RFM line because it shows that "wetter means more preferential flow" is not a universal rule.

The direction can reverse, consistent with the ALT09 decision not to hard-code a monotonic antecedent-moisture rule.

### Proposed use

Use this first as a qualitative/quantitative published benchmark.

If the detailed raw data can be acquired, promote it to a Tier-1 paired state test.

## Evidence tier 2 — Wüstebach multi-depth monitoring

The Wüstebach study classified preferential response from three depths:

```text
5
20
50 cm
```

across 101 locations over three years.

It combines precipitation characteristics with antecedent moisture.

The reported behavior includes strong event-amount control and a weaker/non-simple antecedent-wetness effect.

This is useful for robustness but is less clean than NEON for immediate implementation because the discovered public database entry does not yet establish that the full processed event table is directly downloadable.

## Evidence tier 3 — WUR rainfall-simulator/macropore experiments

The WUR rainfall-simulator work provides a direct experimental contrast between systems with and without artificial macropores and includes breakthrough/drainage information.

It is valuable for testing the fast-transfer signature and for maintaining a Wageningen-relevant experimental anchor.

It is not the first choice for F1-F4 because the experiment was not primarily designed as a systematic intensity x antecedent-state matrix.

## Evidence decision hierarchy

The next analysis sequence is fixed as:

```text
1. NEON event database
   -> activation occurrence/timing screen

2. Griessfirn controlled intensity series
   -> intensity/connectivity-depth transferability

3. Hardie antecedent-state contrast
   -> strong state-direction falsification

4. Wuestebach / WUR experiments
   -> robustness and additional signatures
```

## Parameter discipline

For these tests:

### Allowed

- estimate one structural `sigma_B` per materially distinct soil/profile class;
- estimate one RFM connectivity parameter set per structural soil/profile class;
- derive `K_surface` and `S_surface` from soil hydraulics/state.

### Not allowed

- event-specific `sigma_B`;
- rainfall-specific connectivity parameters;
- altering MB fraction merely to fit each event;
- changing the surface-sorptivity formula between wet and dry events;
- using current SWAP predictions as observational targets.

## First empirical success criterion

RFM does not need to reproduce every PF classification deterministically.

The first test is ordering/discrimination:

```text
Does predicted activation rank events from low to high PF tendency
better than or materially differently from a fixed direct-area fraction,
using unchanged structural parameters?
```

Only after that should detailed flux calibration be attempted.

## First empirical failure criterion

The activation route is in serious trouble if, within the same soil/profile:

- weak events repeatedly show immediate deep PF while RFM predicts negligible activation;
- strong events systematically fail to increase activation;
- observed antecedent-state ordering cannot be represented by state-derived `K` and `S`;
- one `sigma_B` cannot transfer across events.

## Artifact

Machine-readable evidence manifest:

`docs/performance/F-MACRO-ALT15_EVIDENCE_MANIFEST.json`

## Next workunit

F-MACRO-ALT16 should acquire the NEON-derived PF database/code and build the first event-level RFM activation discrimination analysis.

That workunit should remain statistical/empirical:

```text
no new RFM physics
no new free parameters
no production code
```

until the evidence says where the current hypothesis fails.
