# F-PE-NLGLOB01 result — route/mode state-scaling attribution

Date: 2026-09-29

Status:

`NLGLOB01_NO_SIMPLE_SCALING_SIGNAL`

Canonical base:

`integration/f-ci-canonical@2bfb2e310776e57d79882999d3cc35d3f20efcc9`

Qualification authority:

- workflow run: `36536875535`;
- job: `109302838794`;
- conclusion: SUCCESS.

## Frozen question

NLGLOB01 asked whether the TIMEINT17 endpoint-globalization failures are primarily associated with excessively large unscaled Newton steps in pressure head or constitutively implied water-content change.

No solver behavior was changed.

## Coverage

Coverage gate:

PASS.

- audited failing Newton iterations: `768`;
- poor-model iterations, selected rho < 0.25: `335`;
- finite scale diagnostics: `1.0`;
- routes: FLUX, HEAD, RUNOFF;
- materials: B01, B12, O05, O14;
- modes: TG and KLAG;
- all four frozen dt levels;
- process failures: 0.

## Aggregate scaling result

Poor-model / adequate-model median ratios:

- dimensionless head-step scale `z_h`: `1.179e-7`;
- dimensionless constitutive moisture-step scale `z_theta`: `1.435e-7`.

The preregistered state-scaling signal required a ratio >=2 for at least one scale, with consistent route/mode direction and monotone deterioration across rho bins.

The observed direction is the opposite by roughly seven orders of magnitude.

Direction counts where poor-model median exceeds adequate-model median:

- `z_h`: 0/6 route-mode families;
- `z_theta`: 0/6 route-mode families.

Monotone deterioration toward poor rho:

- `z_h`: false;
- `z_theta`: false.

Frozen classification:

`NLGLOB01_NO_SIMPLE_SCALING_SIGNAL`.

## Rho-bin structure

Median dimensionless scales:

### rho >= 0.75

- n = 331;
- z_h about `2.02e-6`;
- z_theta about `8.37e-8`.

### 0.25 <= rho < 0.75

- n = 102;
- z_h about `2.69e-14`;
- z_theta about `2.01e-16`.

### 0 <= rho < 0.25

- n = 335;
- z_h about `1.16e-14`;
- z_theta about `1.33e-16`.

Thus poor local-model quality is not caused by a large Newton correction under either preregistered state scale.

The poor-model subset occurs after the correction has already collapsed to extremely small magnitude.

## Route/mode result

Every route/mode family shows poor/adequate ratios far below one for both scales.

Examples:

- FLUX/TG z_h ratio about `4.58e-8`;
- FLUX/KLAG z_h ratio about `7.69e-8`;
- HEAD/TG z_h ratio about `2.00e-7`;
- RUNOFF/KLAG z_h ratio about `7.39e-7`.

No FLUX-specific >=2 scaling signal exists.

Therefore:

- no global state-scaling repair is supported;
- no route-specific scaling repair is supported.

## Localization

Node carrying the maximum raw Newton correction:

- TOP: 159;
- INTERIOR: 365;
- BOTTOM: 244.

Node carrying the maximum residual:

- TOP: 157;
- INTERIOR: 372;
- BOTTOM: 239.

Raw maximum-step / maximum-residual node colocation:

`0.98698`.

This confirms that the step direction remains strongly spatially aligned with the dominant residual, despite the poor rho subset.

The remaining problem is therefore not an obvious wrong-node or gross step-scaling defect.

## Convergence-contract context

Dominant convergence-contract component at the selected factor:

- compartment balance: 202;
- total balance: 485;
- head update: 81.

Total balance remains the most frequent limiting component.

Combined with the extremely small Newton corrections in the poor-rho subset, this is consistent with a late-iteration stagnation / cancellation / attainable-residual-floor question rather than an oversized-step question.

That interpretation is a hypothesis for the next workunit, not yet a qualified conclusion.

## Consequence

Per preregistration:

- do not open a state-scaling repair;
- do not tune a scaling constant;
- do not introduce a scaled-variable transform;
- do not infer that a smaller trust-region radius will help, because the poor-model subset already occurs at very small corrections.

Before selecting another globalization algorithm, reconcile the result with existing SWAP5 authority on:

- Reference balance floors;
- numerical cancellation limits;
- attainable residual precision;
- convergence-contract scaling.

A separately preregistered successor may then test whether the endpoint blocker is primarily a late-iteration numerical floor rather than a globalization-step-size problem.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance or iteration-limit change.

No timestep or K-staging change.

No dynamic-top event change.

`LEGACY_NUMERICS` remains production default.
