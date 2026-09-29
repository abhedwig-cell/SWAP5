# F-PE-TIMEINT17I preregistration — trust-region model-quality attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17G: `TIMEINT17G_FULL_JACOBIAN_CONSISTENT_GLOBALIZATION_BLOCKER`;
- TIMEINT17H: `TIMEINT17H_MIXED_MERIT_SIGNAL`.

Canonical authority at preregistration:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Question

On the endpoint failures reproduced by TIMEINT17, does the local Newton linear model lose predictive quality far enough from the solution that a trust-region style globalization is better motivated than another line-search merit rescaling?

This is observational attribution only.

No trust-region radius is introduced.

No solver decision is changed.

## Mathematical audit

The existing HeadCalc Newton solve computes a correction `delta` from:

`J delta = F`

and tests damped updates:

`h_trial = h_origin - alpha delta`

with the existing factor sequence.

For the local linear model:

`F_model(alpha) = F_origin - alpha J delta = (1-alpha) F_origin`.

Using the existing raw residual merit:

`phi = 0.5 ||F||_2^2`

the predicted trial merit is:

`phi_model(alpha) = (1-alpha)^2 phi_origin`.

The predicted reduction is:

`pred = phi_origin - phi_model(alpha)
      = phi_origin (2 alpha - alpha^2)`.

The actual reduction is:

`ared = phi_origin - phi_trial`.

Define model-quality ratio:

`rho = ared / pred`

for every tested factor with positive finite `pred`.

Interpretation:

- `rho < 0`: model predicts decrease but actual residual merit increases;
- `rho ~= 1`: local linear model accurately predicts the achieved reduction;
- small positive `rho`: model direction is locally useful but overpredicts progress.

## Frozen bank

Use the exact TIMEINT17H bank and unchanged observational instrumentation:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- TG and KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- unchanged residual/Jacobian;
- unchanged factor sequence;
- unchanged current factor selection;
- unchanged convergence gates.

Only terminal endpoint-failure nonlinear iterations are included.

## Frozen outputs

Per audited Newton iteration:

- route;
- material;
- dt;
- mode;
- current selected factor;
- `rho_selected`;
- best available tested `rho` among factors with actual reduction;
- whether the full Newton step has `rho < 0`;
- whether any smaller tested factor converts negative/poor model quality into `rho >= 0.25`.

Aggregate:

- fraction selected `rho < 0`;
- fraction selected `rho < 0.25`;
- fraction full-step `rho < 0`;
- fraction where a smaller tested factor improves `rho` by >=0.25;
- route/mode decomposition;
- median selected rho for finite values.

The `0.25` threshold is used as a conventional trust-region model-quality boundary for this research classification. It is not a production parameter.

## Coverage gate

Conclusive I requires:

- all FLUX, HEAD, RUNOFF routes;
- >=3 materials;
- >=3 dt levels;
- TG and KLAG;
- >=100 audited Newton iterations;
- >=300 tested candidates.

Otherwise:

`BLOCKED_TIMEINT17I_MODEL_QUALITY_COVERAGE`.

## Frozen classifications

### TRUST_REGION_SIGNAL

`TIMEINT17I_TRUST_REGION_SIGNAL`

if coverage passes and:

1. >=25% of selected factors have `rho < 0.25`;
2. >=25% of audited iterations have a smaller tested factor whose rho exceeds the selected rho by >=0.25 and has positive actual reduction.

### LOCAL_MODEL_ADEQUATE

`TIMEINT17I_LOCAL_MODEL_ADEQUATE_OTHER_GLOBALIZATION_BLOCKER`

if <=10% of selected factors have `rho < 0.25`.

### MIXED_MODEL_QUALITY

Otherwise:

`TIMEINT17I_MIXED_MODEL_QUALITY`.

## Consequence

If `TRUST_REGION_SIGNAL`:

- a separately preregistered research-only trust-region candidate may be opened;
- the initial candidate must preserve the same residual, Jacobian, physical equations and convergence gates;
- trust-region scaling must be explicit and must not be tuned post hoc.

If `LOCAL_MODEL_ADEQUATE`:

- do not open trust-region repair;
- investigate convergence-contract/state-variable formulation instead.

If mixed:

- decompose by route/mode before selecting a repair.

## Stop rules

TIMEINT17I does not:

- alter Newton steps;
- alter factor choices;
- alter tolerances;
- alter iteration limits;
- alter dt;
- alter K staging;
- alter physical equations;
- alter dynamic-top route semantics;
- change production `src/**`.

## Production boundary

Research diagnostics only.

`LEGACY_NUMERICS` remains production default.
