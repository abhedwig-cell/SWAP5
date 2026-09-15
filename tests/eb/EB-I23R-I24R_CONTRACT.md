# EB-I23R / EB-I24R — internal two-half fail-closed correction

## Purpose

This bounded remediation corrects one accepted-runtime authority condition shared by EB-I23 and EB-I24. It does not add an Energy Balance term or change hydrological, thermal, transaction, or timestep physics.

The serialized runtime exposes `output%accepted_substeps` from canonical committed-transaction diagnostics. A transaction accepted through `TX_ROUTE_TWO_HALF` can therefore have `accepted_substeps == 1` even though its accepted trajectory contains two internal half-step advances. In that case `backend%observation()` is the final half-step observation, not whole-interval evidence.

## Corrected authority rule

`backend%observation()` may be used as whole-interval sensible-boundary evidence only when both conditions hold:

1. `output%accepted_substeps == 1`; and
2. `numerical_config%transaction%temporal_mode == TX_TEMPORAL_MODEL_CERTIFICATE`.

For `TX_TEMPORAL_EXTERNAL_FULL_HALF`, EB-I23 and EB-I24 must fail closed rather than promote the final half-step observation as whole-interval top conductive or top advective energy.

## Preserved behavior

The already qualified EB-I24 model-certificate single-transaction inflow path remains unchanged and must still materialize the bounded I22 sensible boundary when its explicit top donor temperature is available. Missing top donor temperature remains unavailable, top outflow remains unqualified, and rejected transactions publish nothing.

Bottom sensible energy remains owned by the existing accepted receipt path. The correction does not change its accounting or provenance.

## Qualification requirements

The owner gate must prove at O0 and O2 that:

- the original model-certificate EB-I24 positive inflow route still passes;
- a physically accepted `TX_TEMPORAL_EXTERNAL_FULL_HALF` transaction can report `accepted_substeps == 1`;
- on that route top conductive, bottom conductive, and top advective materialization from `last_observation` all remain unavailable;
- the boundary remains incomplete and no runtime-complete claim is made;
- missing-donor, top-outflow and rejected-transaction behavior remain unchanged;
- O0 and O2 outputs are identical.

## Hard nonclaims

- This correction does not aggregate accepted two-half thermal observations. That remains EB-I25 work.
- It does not qualify top liquid outflow donor temperature semantics.
- It does not qualify snow or melt thermal provenance.
- It does not add radiation, latent heat, vapor energy, phase-change enthalpy or a whole-column sensible residual publication.
- It does not claim a complete SWAP5 Energy Balance.
- It is not canonical admission by itself.
