# F-PE-ELASTIC01H — descriptor holdout falsification result

Date: 2026-09-29

Status: HOLDOUT_FALSIFICATION_PASSED_WITH_SCOPE_REFINEMENT

Workflow: `36518546175`
Job: `109246169453`
Conclusion: PASS

Frozen coefficient: `ELAS = 1e-6`.

## Results

### B12/POND

Prediction: converge, no O05-like dtmin failure, relatively smooth response.

Observed:
- converged;
- deterministic work `132 -> 128`, about 3.0% reduction;
- runoff delta `-2.2623e-4 cm`;
- storage delta `+2.2623e-4 cm`;
- ponding delta `-6.7193e-5 cm`;
- top-head delta `+7.4323e-2 cm`;
- mid-head delta `-8.9146e-6 cm`;
- bottom-head delta negligible.

Verdict: qualitative robustness prediction supported. The top-node response is larger than the phrase "small physical response" implied, so physical-impact prediction requires more than the near-saturation contrast alone.

### O14/MOIST

Prediction: converge; negligible response if h stays below zero.

Observed:
- converged;
- zero reported trajectory difference;
- work unchanged.

Verdict: supported.

### O14/WET

Prediction: converge; more physical sensitivity than B12; no O05-like failure.

Observed:
- converged;
- work unchanged at 292;
- runoff delta `-6.0532e-3 cm`;
- storage delta `+6.0532e-3 cm`;
- ponding delta `-7.0773e-3 cm`;
- top-head delta `-5.0559e-1 cm`;
- mid-head delta `-3.6179 cm`;
- bottom-head delta `-5.2222 cm`.

Verdict: convergence prediction supported, but physical sensitivity is substantially larger than a near-saturation contrast alone predicts. The amount and duration of saturated-profile activation are therefore required explanatory variables.

### O14/POND

Prediction: converge at 1e-6, material storage/runoff redistribution, no O05-like failure.

Observed:
- converged;
- deterministic work `258 -> 156`, about 39.53% reduction;
- runoff delta `-1.08552e-2 cm`;
- storage delta `+1.08552e-2 cm`;
- ponding delta `-2.9238e-3 cm`;
- top-head delta `-5.4831e-3 cm`;
- mid-head delta `-1.9346e-2 cm`;
- bottom-head delta `-2.5519e-2 cm`.

Verdict: supported.

## Falsification verdict

None of the preregistered hard falsification conditions occurred:

1. B12/POND did not fail;
2. O14/POND did not fail;
3. O14 did not show O05-like dtmin nonconvergence at 1e-6;
4. B12 did not show an abrupt solver-path failure.

Therefore the descriptor hypothesis survives this holdout.

## Scope refinement

The evidence now separates two prediction problems.

### Solver-path risk

The dimensionless contrast

`R = ELAS / C_native near saturation`

is a plausible mechanistic descriptor for the severity of the derivative jump at h=0 and hence for solver-path risk.

O05 has an extreme R and exhibited non-monotone convergence gaps.
B12 has very low R and remained smooth.
O14 has intermediate R and converged on all opened holdouts.

### Physical-impact magnitude

R alone is insufficient to predict total hydrological impact.

O14/WET demonstrates that a moderate derivative contrast can still produce large head changes when a substantial fraction of the profile enters and remains in the saturated ELAS-active domain.

A second state/exposure descriptor is therefore required, for example:

- fraction of active nodes with h >= 0;
- integrated saturated depth;
- time-integrated saturated-node fraction;
- or an equivalent accepted-state exposure metric.

## Consequence for soil-driven parameterization

A future ELAS mapping can remain a soil/material property, but qualification cannot be based on soil descriptors alone. The effect of that property is conditional on hydrological state.

Therefore distinguish:

1. **parameter generation**: soil properties -> ELAS;
2. **impact/risk qualification**: ELAS + near-saturation hydraulic shape + saturation exposure -> expected physical/numerical consequence.

No production mapping is admitted by this holdout.
