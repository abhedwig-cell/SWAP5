# F-PE-NLGLOB01 preregistration — route/mode state-scaling and Newton model-quality attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@2bfb2e310776e57d79882999d3cc35d3f20efcc9`

Parent authority:

- TIMEINT16: `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`.
- TIMEINT17 final status: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`.
- TIMEINT17G: full-column residual/Jacobian finite-difference consistent.
- TIMEINT17H: `TIMEINT17H_MIXED_MERIT_SIGNAL`.
- TIMEINT17I: `TIMEINT17I_MIXED_MODEL_QUALITY`.

## Purpose

NLGLOB01 determines whether the remaining Richards endpoint-globalization blocker is primarily associated with state/step scaling and whether the failure structure differs materially among dynamic-top route families.

This is observational attribution only.

It does not introduce a trust-region radius, Levenberg parameter, new line-search rule, variable transform, extra nonlinear iterations or changed convergence tolerances.

## Repository evidence motivating this work

TIMEINT17I audited 768 failing Newton iterations and 2078 tested backtracking candidates.

Aggregate observations:

- selected-step model quality `rho < 0.25`: about 43.62%;
- full Newton step `rho < 0`: about 49.74%;
- selected `rho < 0`: 0%;
- existing smaller tested factor improves selected rho by >=0.25: 0%;
- median selected rho: about 0.491.

Route/mode poor-rho fractions:

- FLUX/TG: about 0.531;
- FLUX/KLAG: about 0.516;
- HEAD/TG: about 0.406;
- HEAD/KLAG: about 0.406;
- RUNOFF/TG: about 0.406;
- RUNOFF/KLAG: about 0.352.

Thus the local Newton model frequently overpredicts useful progress, especially for FLUX, but the existing damping sequence does not provide a systematic rescue.

## Literature context

Globalized Newton methods are established for Richards/variably saturated flow, and published work notes both their robustness advantages and the importance of poorly scaled nonlinear systems and initial-state quality.

Relevant context includes:

- Jones and Woodward (2001), Advances in Water Resources 24(7), 763-774, DOI 10.1016/S0309-1708(00)00075-0: globalized Newton-Krylov methods for heterogeneous variably saturated flow.
- Farthing et al. (2003), Advances in Water Resources 26(8), 833-849: standard globalization can perform poorly for some Richards systems and poorly scaled nonlinear systems are explicitly identified as a challenge.
- Paniconi and Putti (1994), Water Resources Research 30: convergence depends on initial estimates, convergence norms, boundary conditions and hydraulic nonlinearities; nonlinear relaxation and mixed Picard/Newton strategies are among the robustness mechanisms considered.

These references motivate diagnostics only. They do not select the SWAP repair.

## Frozen bank

Reuse the exact TIMEINT17H/I endpoint-failure bank:

- materials: B01, B12, O05, O14;
- routes: FLUX, HEAD, RUNOFF;
- modes: TG and matched KLAG;
- dt: 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon: 0.001 d;
- unchanged A2 route-margin fixtures;
- MAXIT=8;
- MaxBackTr=8;
- unchanged residual and analytic Jacobian;
- unchanged dynamic-top provider;
- unchanged conductivity staging;
- unchanged convergence gates.

Only terminal endpoint-failure nonlinear iterations are included.

## P0 diagnostics

At every audited failing Newton iteration, record the undamped Newton correction `delta` and the accepted/current tested factor.

### Raw step measures

Record:

- `dh_inf = max_i |delta_i|`;
- `dh_l2 = sqrt(sum_i delta_i^2)`;
- node index of `dh_inf`;
- top-node absolute step;
- bottom-node absolute step.

### Pressure-relative scale

Define the preregistered dimensionless pressure scale per node:

`s_h,i = max(1 cm, |h_i|)`.

Then record:

`z_h_inf = max_i |delta_i| / s_h,i`

and its node index.

This scale is observational and derives directly from the same 1 cm split already used by the current SWAP head convergence contract. It is not a tunable new parameter.

### Retention sensitivity scale

Using the exact constitutive provider at the current iterate, record:

`dtheta_lin,i = C_i * delta_i`

and:

- `dtheta_inf = max_i |dtheta_lin,i|`;
- `z_theta_inf = max_i |dtheta_lin,i| / max(theta_s,i-theta_r,i, 1e-12)`.

The denominator is the material's physical available water-content range. The 1e-12 floor only prevents division by zero in diagnostics and is not a solver parameter.

### Model-quality joins

For every audited iteration join the above quantities to TIMEINT17I-style:

- selected `rho`;
- full-step `rho`;
- selected factor;
- route;
- mode;
- material;
- dt;
- dominant residual location;
- dominant convergence-contract component where available.

## Frozen questions

NLGLOB01 asks:

1. Is poor model quality strongly associated with large dimensionless pressure steps?
2. Is poor model quality more strongly associated with predicted moisture change than raw head change?
3. Does FLUX occupy a distinct scaling regime from HEAD/RUNOFF?
4. Are TG and KLAG statistically similar within each route?
5. Is the poor-model subset localized to top/bottom nodes or still predominantly interior?

## Frozen classifications

### STATE_SCALING_SIGNAL

`NLGLOB01_STATE_SCALING_SIGNAL`

if coverage passes and all hold:

1. median `z_h_inf` or median `z_theta_inf` in the poor-model subset (`selected rho < 0.25`) is at least 2x the corresponding median in the adequate-model subset (`selected rho >= 0.25`);
2. the same direction of separation holds in at least 4/6 route-mode families;
3. at least one dimensionless scale shows monotone deterioration across rho bins:
   - rho >= 0.75;
   - 0.25 <= rho < 0.75;
   - 0 <= rho < 0.25.

### ROUTE_SPECIFIC_SCALING_SIGNAL

`NLGLOB01_ROUTE_SPECIFIC_SCALING_SIGNAL`

if the aggregate 2x gate fails but FLUX satisfies it in both TG and KLAG while at least one of HEAD or RUNOFF does not.

### NO_SIMPLE_SCALING_SIGNAL

`NLGLOB01_NO_SIMPLE_SCALING_SIGNAL`

if poor/adequate median ratios remain below 1.5 for both dimensionless scales and no route family satisfies the route-specific rule.

### MIXED

Otherwise:

`NLGLOB01_MIXED_SCALING_SIGNAL`.

## Coverage gate

A conclusive result requires:

- all three route families;
- all four materials;
- all four dt levels;
- TG and KLAG;
- >=500 audited failing Newton iterations;
- >=100 poor-model iterations;
- finite scale diagnostics for >=99% of audited iterations.

Otherwise:

`BLOCKED_NLGLOB01_SCALING_COVERAGE`.

## Consequence rules

If `STATE_SCALING_SIGNAL`:

- open a separately preregistered scaled-variable or scaled-trust-region candidate;
- do not tune the scale after seeing candidate completion.

If `ROUTE_SPECIFIC_SCALING_SIGNAL`:

- do not apply a global scaling repair;
- open route-specific formulation/globalization attribution first.

If `NO_SIMPLE_SCALING_SIGNAL`:

- do not open state-scaling repair;
- move to alternative globalization families such as trust region based on model radius or pseudo-transient continuation only under separate preregistration.

If mixed:

- decompose the identified subfamilies before selecting a repair.

## Stop rules

NLGLOB01 does not:

- modify production `src/**`;
- change residual equations;
- change the Jacobian;
- change K staging;
- change dt;
- change MAXIT or MaxBackTr;
- change convergence tolerances;
- change dynamic-top route/event semantics;
- choose a trust-region radius;
- choose a damping/scaling constant;
- change accepted-state transaction semantics.

## Production boundary

Research diagnostics only.

`LEGACY_NUMERICS` remains production default.
