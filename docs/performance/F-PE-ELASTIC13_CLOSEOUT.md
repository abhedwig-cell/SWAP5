# F-PE-ELASTIC13 — physical ELAS parameter-policy closeout

Date: 2026-09-29

Status: QUALIFIED_RESEARCH_CLOSURE

Branch:
`research/f-pe-elastic13-parameter-policy`

Current canonical reconciliation:
`integration/f-ci-canonical@4e07091a5dec6e21ece2d7a57f62444a4c25834d`.

The intervening canonical delta contains only unrelated numerical-global
qualification work and does not intersect the ELASTIC13 dependency surface.

## Result

F-PE-ELASTIC13 qualifies a bounded operational physical-prior policy for
**mineral** BOFEK/Staringreeks layers.

Qualified policy:

`MINERAL -> AUTO_STATIC_PRIOR_AT_H_MINUS100`

with:
- exact frozen ELASTIC11 M1 coefficients;
- exact source-bound BOFEK/BRO layer identity;
- dry bulk density from BRO;
- Staringreeks 2018 moisture reconstruction at `h=-100 cm`;
- frozen multiplicative uncertainty factor
  `2.123968031921196`;
- predictor-domain provenance;
- user-supplied explicit ELAS preserved as a distinct route.

## Mineral evidence

Population:
- 1356 mineral layers;
- 357 profiles.

At `h=-100 cm`:
- median ELAS `2.839e-6 cm^-1`;
- p10 `2.268e-6`;
- p90 `4.165e-6`;
- minimum `1.760e-6`;
- maximum `2.527e-5`;
- 99.85% IN_DOMAIN;
- 0.15% EDGE;
- 0% EXTRAPOLATION.

## Reference-state convention

The operational reference is frozen at:

`h_ref = -100 cm`.

This is a reproducible Dutch field-capacity convention, not a claim that every
soil layer is uniquely at field capacity at that head.

Sensitivity was frozen independently at:

`h=-200 cm`.

For the same mineral layers:

`Ss(-200)/Ss(-100)`

has:
- median `1.075`;
- minimum `1.022`;
- maximum `1.148`.

All preregistered robustness gates pass.

Therefore local uncertainty in the field-capacity convention is materially
smaller than the independently observed ELASTIC11 predictor uncertainty.

## Uncertainty policy

Every generated prior must carry:

- `ELAS_prior`;
- `ELAS_lower = ELAS_prior / 2.123968031921196`;
- `ELAS_upper = ELAS_prior * 2.123968031921196`;
- `reference_head_cm = -100`;
- profile/layer provenance;
- regime;
- predictor-domain class.

The factor band is descriptive model uncertainty, not a confidence interval.

Production code must not silently discard the distinction between predicted
physical prior and measured/user-supplied parameter.

## Organic and peat policy

### ORGANIC_RICH_NONPEAT

8 source-bound layers.

Policy:

`RESEARCH_ONLY_NOT_AUTO_ASSIGNED`.

### PEAT

204 source-bound layers across 108 profiles.

At -100 cm the frozen M1 transfer yields median approximately
`1.885e-5 cm^-1`, but peat remains:

`RESEARCH_ONLY_NOT_AUTO_ASSIGNED`.

The reason is constitutive rather than numerical: prior evidence indicates
stronger deformation and history dependence for peat, for which one scalar
linear ELAS may be only a first-order approximation.

### UNKNOWN

Observed:
0 layers.

Policy remains:
`NO_AUTO_ASSIGNMENT`.

## Relationship to Pim Dik 1e-6 cm^-1 proposal

The evidence now supports a stronger statement than the original scalar
proposal.

For mineral BOFEK layers:
- essentially all generated priors exceed `2e-6 cm^-1` at the frozen -100 cm
  reference state;
- median is approximately `2.84e-6 cm^-1`;
- the independent mechanical evidence already showed that `1e-6 cm^-1` is
  physically possible but near the stiff/lower part of the observed range.

Therefore `1e-6 cm^-1` should not be adopted as the universal automatic
mineral default.

It remains a plausible explicit value for individual materials where justified.

## Production boundary

F-PE-ELASTIC13 changes no production source.

Existing admitted production support remains:
- ELASTIC05 constitutive semantics;
- ELASTIC08 runtime materialization;
- ELASTIC09 production application bootstrap.

A later production work unit may materialize the exact qualified mineral prior
policy.

It may not:
- auto-assign peat;
- auto-assign high-organic non-peat;
- alter the -100 cm reference after observing solver behavior;
- tune physical ELAS for runtime;
- remove user-supplied explicit ELAS;
- silently make generated ELAS universal or mandatory.

## Next work unit

Natural successor:

`F-PE-ELASTIC14 — production-shaped mineral ELAS prior materialization`.

Its job is not to re-open physical inference.

It should:
1. define the explicit data/input contract for generated mineral priors;
2. preserve provenance and uncertainty metadata outside the constitutive scalar;
3. materialize the chosen `ELAS_prior` into the already admitted per-layer
   ELAS path;
4. fail closed for PEAT, ORGANIC_RICH_NONPEAT and UNKNOWN;
5. preserve explicit user-supplied ELAS and default-off behavior;
6. qualify mass and default-off identity through existing ELASTIC production
   gates.

## Closure

F-PE-ELASTIC13 has reached qualified research closure.

The physical policy question for automatic **mineral** BOFEK-layer prior
generation is closed.
