# F-PE-REPRO02 R10 result — attempt-context involvement

Date: 2026-09-26

Status: `ATTEMPT_CONTEXT_NOT_CAUSAL`

## Protocol

The normal FGC44 transaction route was compared in two test-only arms across the six difficult PROFILE06 origins at -0.001, 0 and +0.001 cm, three fresh-process repetitions per point.

- BASE: normal serialized canonical transaction behavior.
- NO_CONTEXT: identical accepted-direction and physical requests, but the test-copy serialized model reported `attempt_context_required = .false.`, disabling canonical attempt-context capture/restore.

Both arms used 48 nonlinear iterations, 16 backtracking and minimum step 1e-10 day.

## Result

The arms were identical at every point.

BASE:

- 7/18 PASS;
- 1/12 nonzero PASS.

NO_CONTEXT:

- 7/18 PASS;
- 1/12 nonzero PASS.

The only nonzero success in both arms remained B01-mid +0.001 cm.

Every failing point had identical solver status, nonlinear count and backtracking count between BASE and NO_CONTEXT. Representative examples:

- B01 wet +0.001 cm: 48 nonlinear / 711 backtracking in both arms;
- B12 wet +0.001 cm: 48 / 697;
- O05 wet +0.001 cm: 48 / 670;
- O14 mid -0.001 cm: 48 / 654;
- O14 wet +0.001 cm: 48 / 649.

## Conclusion

Canonical attempt-context capture/restore is not the cause of the R9 FLOOR versus TRANSACTION split.

R9 remains authoritative that the physical serialized backend succeeds 18/18 outside normal transaction orchestration, while the transaction route succeeds only 7/18.

The remaining causal surface is therefore narrower: checkpoint/candidate state cloning or another canonical pre-advance lifecycle operation that differs from reference-floor sampling.

## Next discriminator

R11 should compare the exact physical state presented to the serialized model after:

1. reference-floor state materialization;
2. canonical checkpoint clone and candidate clone immediately before the first `model%advance`.

The comparison must be bit-level for all state fields that can influence the Reference solve, and should include dynamic type / temporal-history payload where present.

No production source change is authorized by R10.
