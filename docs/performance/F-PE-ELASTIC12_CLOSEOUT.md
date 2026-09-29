# F-PE-ELASTIC12 — BOFEK/Staringreeks transfer closeout

Date: 2026-09-29

Status: QUALIFIED_RESEARCH_CLOSURE

Branch:
`research/f-pe-elastic12-bofek-transfer`

Current canonical reconciliation:
`integration/f-ci-canonical@e59f1b2ffd97fb210c9d682332e740a1552a9f46`.

The intervening canonical development does not intersect the ELASTIC12 source,
mechanical predictor or transfer dependency surface.

## Result

F-PE-ELASTIC12 establishes that the independently validated ELASTIC11 physical
predictor can be transferred, without refitting, to the complete BOFEK2020 /
Staringreeks layer representation.

The transfer is source-bound and complete:
- 368 / 368 BOFEK profiles map exactly to BRO normal soil profiles;
- 1568 / 1568 layers/horizons map exactly;
- profile IDs are identical;
- depth boundaries are identical;
- Staringreeks building-block identity is preserved;
- dry bulk density is source-bound from BRO `soilhorizon`;
- Staringreeks 2018 retention parameters supply only the declared moisture-state
  reconstruction.

## Source route

The final accepted source bridge is not the WUR coordinate API.

Direct API probes by:
- profile ID;
- soil-map-unit;
- bodemcode

did not establish a documented direct retrieval route.

Instead, the official PDOK BRO Bodemkaart ATOM download exposes a GeoPackage
whose relational tables provide the complete deterministic bridge:

`normalsoilprofiles`
+
`soilhorizon`
+
BOFEK `allprofiles368_2020.csv`.

This avoids coordinate sampling entirely.

## Physical transfer

The frozen ELASTIC11 M1 predictor remains unchanged.

BOFEK/BRO dry bulk density is combined with Staringreeks water retention at a
declared pressure-head state to reconstruct the two M1 source variables:

`rho_wet = rho_dry + theta(h)`

`waterContent[%] = 100 * theta(h) / rho_dry`.

The resulting pair is evaluated with the frozen ELASTIC11 coefficients.

No statistical fitting occurs in ELASTIC12.

## Domain qualification

The preregistered state grid was:

- -10 cm;
- -33 cm;
- -100 cm;
- -330 cm;
- -1000 cm.

Across all 1568 layers:
- every state has zero >3-sigma extrapolation;
- IN_DOMAIN+EDGE coverage is 100% at every state;
- IN_DOMAIN alone ranges from 92.4% to 99.7%.

Therefore the transfer-domain advancement gate passes.

Classification:

`BOFEK_LAYER_PRIOR_TRANSFER_FEASIBLE`.

## Magnitude

Median transferred skeleton specific storage ranges from approximately:

- `2.61e-6 cm^-1` at h=-10 cm;
- to `3.66e-6 cm^-1` at h=-1000 cm.

The layer distribution remains broad, with upper tails above
`1e-5 cm^-1`.

Most transferred BOFEK layer priors are above `2e-6 cm^-1` under the frozen
state grid.

Thus the transfer does not support using `1e-6 cm^-1` as a universal Dutch
layer value.

## State uncertainty

The transfer remains state-dependent.

For identical layers, the ratio

`Ss(-10 cm) / Ss(-1000 cm)`

has median approximately `0.666`.

Equivalently, moving from the wettest to driest frozen reference state
increases the predicted prior by about 1.5x at the median.

ELASTIC12 therefore deliberately does not choose one pressure head as the
production reference state.

## What is qualified

Qualified research claims:

1. direct Dutch BHR-GT mechanical evidence supports material-dependent ELAS;
2. a two-variable physical predictor survives independent holdout;
3. the required predictor variables can be reconstructed for every BOFEK2020
   layer from source-bound BRO dry density plus Staringreeks moisture state;
4. the complete 368-profile / 1568-layer transfer remains inside the validated
   predictor domain under the frozen state grid;
5. a BOFEK-layer physical ELAS prior is therefore technically and physically
   feasible.

## What is not qualified

ELASTIC12 does not establish:
- one universal production ELAS;
- one unique reference pressure head;
- exact layer values without uncertainty;
- a production auto-activation policy;
- a new parser/input contract;
- a replacement for user-supplied ELAS;
- stress-independent universal constitutive behavior.

The independently observed ELASTIC11 prediction uncertainty remains roughly a
factor 2.1 typical multiplicative error and must be carried forward.

## Production relationship

Production support remains separately admitted through:
- ELASTIC05: typed constitutive ELAS;
- ELASTIC08: runtime materialization;
- ELASTIC09: production application bootstrap.

ELASTIC12 changes no production source.

## Next work unit

The remaining question is operational parameter policy rather than data
availability:

`validated mechanical predictor + BOFEK layer transfer + state uncertainty
 -> explicit ELAS prior/value policy`.

A successor work unit should decide, before any production code change:
- whether ELAS is stored as one static layer prior or as state-aware metadata;
- what reference-state convention is scientifically defensible;
- how factor-2.1 predictor uncertainty is represented;
- whether the policy is appropriate for mineral and organic/peat layers alike;
- whether a conservative fallback or user override remains required.

No solver-performance objective may be used to choose that physical policy.

## Closure

F-PE-ELASTIC12 has reached qualified research closure.

The transfer-data problem is no longer a blocker.
