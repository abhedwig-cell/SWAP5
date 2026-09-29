# F-PE-ELASTIC12A5 — BOFEK/BRO relational transfer result

Date: 2026-09-29

Status: BOFEK_LAYER_PRIOR_TRANSFER_FEASIBLE

Preregistration:
`F-PE-ELASTIC12A5_RELATIONAL_BRIDGE_PREREGISTRATION.md`.

Workflow run:
`36551561152`

Job:
`109350703036`

Evidence artifact:
`11025251845`

Conclusion:
PASS.

## Exact source bridge

Frozen BOFEK/Staringreeks source artifact:
- run `36549054287`;
- artifact `11023058542`.

Frozen PDOK BRO Bodemkaart GeoPackage artifact:
- run `36550782840`;
- artifact `11024079961`.

The source identity gates passed exactly:

- BOFEK `allprofiles368_2020.csv`: 368 profiles;
- BRO `normalsoilprofiles`: same 368 profile IDs;
- matched profiles: 368 / 368;
- matched horizons/layers: 1568 / 1568;
- BOFEK and BRO profile-ID sets: identical;
- BOFEK layer sequence/depth and BRO horizon sequence/depth: identical;
- BOFEK Staringreeks layer coding and BRO `staringseriesblock`: identical;
- finite positive source `density`: complete.

No coordinate sampling or fuzzy profile matching was used.

The relational bridge is therefore:

`BOFEK iprofile`
-> `BRO normalsoilprofile_id`
-> `BRO soilhorizon {density, staringseriesblock, depth}`.

## Frozen physical transfer

For each of the 1568 exact source layers and every preregistered pressure-head
state, the transfer used:

`theta(h)` from exact Staringreeks 2018 retention parameters,

`rho_wet = rho_dry + theta(h)`,

`waterContent[%] = 100 * theta(h) / rho_dry`,

followed by the frozen independently validated ELASTIC11 M1 equation.

No M1 coefficient or normalization was changed.

## State-grid results

| h [cm] | median Ss [cm^-1] | p10 | p90 | min | max | IN_DOMAIN | EDGE | EXTRAPOLATION |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| -10 | 2.614e-6 | 1.889e-6 | 1.019e-5 | 1.637e-6 | 3.114e-5 | 99.745% | 0.255% | 0% |
| -33 | 2.754e-6 | 1.985e-6 | 1.070e-5 | 1.674e-6 | 3.164e-5 | 99.745% | 0.255% | 0% |
| -100 | 2.989e-6 | 2.294e-6 | 1.194e-5 | 1.760e-6 | 3.293e-5 | 98.214% | 1.786% | 0% |
| -330 | 3.357e-6 | 2.658e-6 | 1.377e-5 | 1.920e-6 | 3.513e-5 | 97.385% | 2.615% | 0% |
| -1000 | 3.664e-6 | 2.976e-6 | 1.582e-5 | 2.099e-6 | 3.713e-5 | 92.411% | 7.589% | 0% |

Every state satisfies the parent transfer-domain advancement condition:
at least 95% IN_DOMAIN+EDGE.

In fact every one of the 7840 layer/state evaluations is within 3 standard
deviations of both frozen ELASTIC11 predictors.

## Sensitivity to reference water state

For identical layers:

`Ss(h=-10) / Ss(h=-1000)`

has:
- minimum: `0.5366`;
- p10: `0.5840`;
- median: `0.6660`;
- p90: `0.8222`;
- maximum: `0.8871`.

Thus the static transferred ELAS prior remains meaningfully sensitive to the
reference moisture state.

Moving from near-wet `h=-10 cm` to dry `h=-1000 cm` increases the predicted
specific storage by roughly a factor 1.1 to 1.9 across layers, with a median
factor of about 1.50.

This state dependence is large enough that ELASTIC12 does not select one
pressure head post hoc.

## Relation to 1e-6 cm^-1

At `h=-10 cm`:
- below `0.5e-6`: 0%;
- near `1e-6` under the frozen 0.5e-6 to 2e-6 descriptive band: 16.0%;
- above `2e-6`: 84.0%.

At `h=-1000 cm`:
- near band: 0%;
- above `2e-6`: 100%.

Therefore `1e-6 cm^-1` remains physically plausible from the direct BHR-GT
mechanical evidence, but the BOFEK-layer transfer using the independently
validated M1 predictor places most layer priors above that value for every
tested reference state.

This is not evidence to tune the transfer toward a preferred magnitude.

## Interpretation

The central transfer question is answered positively:

the direct BHR-GT mechanical predictor can be mapped to the complete
BOFEK2020/Staringreeks layer representation without:
- statistical refitting;
- MvG parameters as predictors;
- coordinate sampling;
- solver-performance tuning;
- imputation of profile identity.

The Staringreeks relation is used only to reconstruct the moisture state needed
to express the already validated BHR-GT predictor variables.

## Remaining physical uncertainty

The transfer is not yet a production default.

Two uncertainty layers remain explicit:

1. independent ELASTIC11 predictor uncertainty, approximately factor 2.1
   typical multiplicative holdout error;
2. reference-state uncertainty because BHR-GT `veldvochtig` does not define
   one unique SWAP matric pressure head.

The pressure-head grid quantifies the second uncertainty rather than resolving it.

## Decision

Classification:

`BOFEK_LAYER_PRIOR_TRANSFER_FEASIBLE`.

A later work unit may now define how a transferred BOFEK/Staringreeks ELAS
prior is represented operationally, including uncertainty/state policy.

It may not claim that ELASTIC12 selected a unique production ELAS value or a
unique reference pressure head.
