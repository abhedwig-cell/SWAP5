# F-PE-REPRO02 R12 result — temporal state-carrier discriminator

Date: 2026-09-26

Status: `TEMPORAL_STATE_CARRIER_NOT_CAUSAL`

## Protocol

A single serialized reference-floor physical advance was run for the six difficult PROFILE06 origins at -0.001, 0 and +0.001 cm, three fresh-process repetitions per point.

Arms:

- PLAIN_FLOOR: committed state carried as `fmr_b110_physical_state_t`;
- TEMPORAL_FLOOR: the same inherited physical state carried as `fmr_b110_temporal_indicator_state_t`, seeded with the same zero initial right derivative used by the FGC44 fixture.

A test-only backend copy admitted the temporal carrier to the floor diagnostic while temporal certification remained disabled. Production source was unchanged.

Both arms used the same mode-5 forcing and 48/16/1e-10 physical controls.

## Result

Both arms passed every point:

- PLAIN_FLOOR: 18/18 PASS;
- TEMPORAL_FLOOR: 18/18 PASS.

The arms were identical point by point for:

- nonlinear iteration count;
- backtracking count;
- mass completeness;
- mass residual;
- bottom exchange.

Representative nonzero examples:

- B01 wet +0.001 cm: 3 nonlinear / 4 backtracking in both arms;
- B12 wet +0.001 cm: 2 / 2 in both arms;
- O05 wet +0.001 cm: 3 / 3 in both arms;
- O14 mid -0.001 cm: 4 / 4 in both arms;
- O14 wet +0.001 cm: 3 / 3 in both arms.

All reported mass residuals were zero.

## Conclusion

The dynamic temporal-indicator state carrier and presence of the seeded temporal-history payload do not by themselves alter physical Richards convergence.

Together R9-R12 exclude:

- intrinsic serialized physical-backend failure;
- attempt-context capture/restore;
- corrector-backend/workspace lifetime;
- temporal-indicator state type/history presence.

The R9 FLOOR versus TRANSACTION split must therefore be explained by canonical transaction execution itself.

Aggregate transaction diagnostics already contain both temporal and solver rejections. Because the final physical observation only describes the last retry, it does not establish which rejection occurred first.

## Next discriminator

R13 must trace the ordered retry sequence attempt by attempt, including duration, solver result, mass result and temporal certificate outcome.

No production source change is authorized by R12.
