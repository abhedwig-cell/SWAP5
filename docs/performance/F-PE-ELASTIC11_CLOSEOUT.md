# F-PE-ELASTIC11 — physical ELAS predictor closeout

Date: 2026-09-29

Status: QUALIFIED_RESEARCH_CLOSURE

Branch:
`research/f-pe-elastic11-predictor-model`

Current canonical reconciliation:
`integration/f-ci-canonical@30e507fc8bdf7f7c37f327ab378e5c4a8ae39b94`.

The canonical delta since initial ELASTIC11 work does not intersect this
research work unit's mechanical-target, descriptor, model or evidence
dependency surface.

## Result

F-PE-ELASTIC11 establishes a first independently validated physical predictor
for unload skeleton specific storage from direct BHR-GT specimen properties.

The selected predictor uses only:
- target-bound wet volumetric mass density;
- target-bound water content.

It does not use:
- MvG hydraulic parameters;
- solver performance;
- runtime;
- timestep behavior;
- numerical convergence;
- BOFEK class;
- Staringreeks class;
- inferred dry density.

## Calibration selection

Calibration-only evidence:
- 77 valid unload targets;
- 33 independent BRO objects;
- leave-one-object-out validation;
- object-balanced training and scoring.

Selected model:
M1 field-minimal.

Calibration object-balanced MAE:
`0.25614 log10`.

Frozen calibration equation:

`log10(Ss_skeleton [cm^-1]) =
 -5.144312248981006
 -0.25581251314464676 * z(volumetricMassDensity)
 +0.15229775506831100 * z(waterContent)`.

The depth-augmented model did not improve enough to pass the preregistered
complexity threshold.

The laboratory stress-change/method benchmark produced essentially no
additional predictive gain in this bounded representation.

## Independent holdout qualification

One-shot holdout:
- 18 exact preregistered BHR-GT objects fetched;
- 13 yielded valid unload targets;
- 45 valid unload targets;
- 100% M1 predictor coverage.

Frozen M0 holdout MAE:
`0.40893 log10`.

Frozen M1 holdout MAE:
`0.32715 log10`.

Improvement:
`0.08178 log10`.

Median-object improvement:
`0.10600 log10`.

Objects improved:
`69.23%`.

All preregistered qualification gates pass.

Classification:

`INDEPENDENT_HOLDOUT_QUALIFIED_PHYSICAL_PREDICTOR`.

## Interpretation

This result is strong enough to reject the working strategy of one universal
ELAS value as the preferred physical parameterization route.

A measured-property-informed prior is better supported by the current direct
mechanical evidence.

However, the predictor remains moderately uncertain.

The independent holdout object-balanced MAE corresponds to about a factor
`2.12` multiplicative error, and substantial object-specific deviations remain.

Therefore M1 should be treated as:
- a physically informed prior;
- a first layer-scale parameter estimator;
- a starting point for transfer research;

not as:
- an exact constitutive law;
- a universal Dutch ELAS relation;
- an automatically deployable production default.

## Relationship to Pim Dik 1e-6 cm^-1 proposal

The earlier ELASTIC10 evidence established that `1e-6 cm^-1` lies inside the
observed mechanical range but near the stiff/lower side of the unload
distribution.

ELASTIC11 adds that specimen properties contain reproducible predictive
information beyond a single global constant.

Thus the evidence supports:
- `1e-6 cm^-1` as a physically plausible value for some materials/states;

but does not support:
- `1e-6 cm^-1` as the preferred universal parameterization.

## Production boundary

Production support for explicit ELAS is already admitted separately through:
- ELASTIC05 constitutive semantics;
- ELASTIC08 runtime materialization;
- ELASTIC09 production application bootstrap.

ELASTIC11 changes no production source.

It does not automatically connect BHR-GT measurements to SWAP input.

## Next required research boundary

The next question is transfer:

`BHR-GT specimen predictor -> field/soil-layer descriptors -> BOFEK/Staringreeks/SWAP layer ELAS prior`.

That is a different work unit.

A successor should explicitly address:
- whether WUR/LHM/BOFEK input contains compatible wet volumetric density and
  water-content descriptors;
- how reference water state is defined;
- whether a mechanical predictor measured under geotechnical specimen
  conditions transfers to agricultural/root-zone soils;
- how uncertainty is propagated;
- whether stress/state dependence must become explicit rather than absorbed in
  a static layer parameter.

No production auto-parameterization should be implemented before that transfer
question is qualified.

## Closure

F-PE-ELASTIC11 has reached qualified research closure.

There is no remaining calibration or independent-holdout action in this work
unit.
