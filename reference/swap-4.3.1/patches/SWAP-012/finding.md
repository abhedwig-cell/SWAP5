# SWAP-012 finding — `prhead` is not the inverse of the selected retention model

## Classification

Implementation/algorithm bug. The defect is not a model-development choice.

`watcon` dispatches hydraulic models separately. In contrast, B0 `prhead` only treats model 2 separately and then uses the default unimodal Mualem-Van Genuchten analytical inverse for all other parametric models. That inverse is not valid for bimodal MvG, scaled/extended MvG, PDI or RIA retention.

The required contract is model-selection consistency:

```text
for a valid unsaturated state:
prhead(watcon(h)) ~= h
```

within the qualified inverse tolerance and model domain.

## Affected hydraulic models

Affected: 3 and 5 through 12. Model 4 is the standard MvG analytical control and must remain unchanged. Model 2 retains its separate exponential inverse.

## Qualified repair

For models without the matching default analytical inverse, invert the actual selected retention relation using a bounded bisection search. The stored patch uses:

- the explicit bimodal retention expression for model 3;
- `functionvalue_04_11(iType=1,...)` for models 5–11;
- `WCRIA` for model 12;
- the model-specific dry bound `-h0` where the scaled model defines one, otherwise `-1e12 cm`;
- at most 100 bisection iterations with an absolute/relative bracket-width stop.

The analytical default-MvG path remains the model 1/4 path.

## Separation from SWAP-011

The historical combined audit patch also changed `dhconduc` for SWAP-011 in the same `MOD_MvG_functions.f90` file. That older numerical-derivative SWAP-011 implementation is deliberately excluded here. SWAP-012 admission changes only imports/local variables required by `prhead` and the `prhead` dispatch/inversion branch.

This separation is essential because SWAP-011 has a different final qualified implementation whose exact E7 patch payload is still pending recovery.
