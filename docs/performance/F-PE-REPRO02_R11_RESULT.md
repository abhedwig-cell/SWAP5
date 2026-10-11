# F-PE-REPRO02 R11 result — serialized corrector-backend lifetime

Date: 2026-09-26

Status: `BACKEND_LIFETIME_NOT_CAUSAL`

## Protocol

The normal FGC44 participant transaction route was compared across six difficult PROFILE06 origins at -0.001, 0 and +0.001 cm, three fresh-process repetitions per point.

Arms:

- BASE: existing long-lived corrector backend initialized during FGC44 initialization;
- FRESH_BACKEND: a newly initialized serialized Reference backend passed to the same participant `trial_from_origin` after predictor initialization and origin capture.

Both arms retained the same temporal committed state, participant checkpoint, forcing, canonical transaction policy, accepted-direction request and 48/16/1e-10 physical solver controls.

## Result

The arms were identical at every point.

BASE:

- 7/18 PASS;
- 1/12 nonzero PASS.

FRESH_BACKEND:

- 7/18 PASS;
- 1/12 nonzero PASS.

The only nonzero success remained B01-mid +0.001 cm.

All failing points reproduced identical solver status, nonlinear counts and backtracking counts between arms. Representative examples:

- B01 wet +0.001 cm: 48 nonlinear / 711 backtracking;
- B12 wet +0.001 cm: 48 / 697;
- O05 wet +0.001 cm: 48 / 670;
- O14 mid -0.001 cm: 48 / 654;
- O14 wet +0.001 cm: 48 / 649.

Successful zero-displacement controls and B01-mid +0.001 also matched exactly, including temporal-certificate availability.

## Conclusion

Serialized corrector-backend initialization timing, backend object lifetime and fresh solver workspace do not explain the R9 FLOOR versus TRANSACTION split.

Together R9-R11 now exclude:

- physical serialized backend inability;
- canonical attempt-context capture/restore;
- long-lived corrector backend/workspace history.

The major remaining structural difference is the state carrier and canonical state-cloning path:

- FLOOR uses a plain `fmr_b110_physical_state_t` committed state;
- the normal model-certificate transaction uses `fmr_b110_temporal_indicator_state_t` and clones that state through checkpoint/candidate transaction ownership.

## Next discriminator

R12 must isolate the temporal-indicator state carrier from canonical transaction orchestration while preserving the same inherited physical fields.

No production source change is authorized by R11.
