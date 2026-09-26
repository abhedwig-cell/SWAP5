# F-PE-REPRO02 R9 result — serialized physical advance versus canonical transaction

Date: 2026-09-26

Status: `DIVERGENCE_ABOVE_BARE_SERIALIZED_PHYSICAL_ADVANCE`

## Protocol

Six difficult PROFILE06 origins were tested at -0.001, 0 and +0.001 cm with three fresh-process repetitions per arm.

Both arms used:

- the serialized Reference backend;
- the same committed physical origin;
- the same mode-5 prescribed-head forcing;
- max nonlinear iterations = 48;
- max backtracking = 16;
- minimum step duration = 1e-10 day;
- existing 1e-12 balance/head tolerances.

Arms:

- FLOOR: one admitted serialized reference-floor physical advance, bypassing normal canonical retry/temporal orchestration;
- TRANSACTION: the normal exact FGC44 participant through canonical whole-window transaction execution.

## Result

FLOOR:

- 18/18 points succeeded;
- every sample was valid;
- exactly one physical advance per point;
- mass accounting complete 18/18;
- mass residual = 0 on all reported points;
- nonzero offsets converged in 2 to 4 nonlinear iterations on the observed cases;
- no internal retry was required.

TRANSACTION:

- 7/18 points succeeded;
- all six zero-displacement controls succeeded;
- B01-mid +0.001 cm remained the only nonzero success;
- the other 11 signed nonzero points failed with participant status 6 / solver retry-advised;
- under the generous 48/16 controls, failures still exhausted the nonlinear path with roughly 649 to 738 backtracking attempts in representative cases.

Representative contrasts:

- B01 wet +0.001 cm: FLOOR 3 nonlinear / 4 backtracking, TRANSACTION 48 / 711 and fail;
- B12 wet +0.001 cm: FLOOR 2 / 2, TRANSACTION 48 / 697 and fail;
- O05 wet +0.001 cm: FLOOR 3 / 3, TRANSACTION 48 / 670 and fail;
- O14 mid -0.001 cm: FLOOR 4 / 4, TRANSACTION 48 / 654 and fail;
- O14 wet +0.001 cm: FLOOR 3 / 3, TRANSACTION 48 / 649 and fail.

Aggregate:

- FLOOR_OK = 18/18;
- TRANSACTION_OK = 7/18.

The signatures were deterministic across the three repetitions.

## Conclusion

The difficult-origin failure is not intrinsic to the serialized physical Reference solve.

The same serialized backend, state and forcing converge cheaply when executed as one reference-floor physical advance.

R9 therefore localizes the divergence above the bare serialized physical advance, but it does not yet identify the generic transaction lifecycle as the unique cause. The reference-floor contract also removes the Richards temporal-continuation carrier and disables model temporal-history handling. That axis remains confounded with canonical transaction execution.

The next discriminator must preserve canonical transaction execution while switching only the numerical-continuation/state topology between base physical state and Richards temporal-history state. Temporal acceptance is not the first observed rejection mechanism, but temporal-history-enabled model preparation may still alter the physical attempt before certification.

## Next discriminator

R10 should isolate Richards temporal-history continuation from the remaining canonical transaction machinery. Only if a no-history canonical transaction still fails should checkpoint/attempt-context lifecycle become the next primary suspect.

No production defect repair is authorized by R9 alone.
