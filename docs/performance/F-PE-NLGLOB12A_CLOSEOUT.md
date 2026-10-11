# F-PE-NLGLOB12A closeout — aggregate storage-representation floor attribution

Date: 2026-09-29

Final status:

`NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@4e07091a5dec6e21ece2d7a57f62444a4c25834d`

Qualification authority:

- run `36552997339`;
- job `109355404628`;
- conclusion: SUCCESS.

## Closure

NLGLOB12A closes positively.

All eight preregistered above-floor stagnation cases are already within the arithmetic storage-representation floor at terminal failure:

- 8/8 satisfy `R_total_ulp <= 1`;
- 8/8 satisfy `R_local_ulp <= 1`;
- maximum aggregate ratio: `0.210625`;
- maximum local ratio: `0.7088`;
- existing head and ponding guards pass;
- no process failure occurred.

## Scientific conclusion

These terminal residuals cannot be reduced meaningfully within the stored moisture representation.

The relevant distinction is therefore not “loosen the balance tolerance”, but “recognize when the residual is already beneath the state representation resolution”.

That is a numerically grounded convergence-certificate concept and is consistent with the earlier BALTOL/storage-floor authority.

## Direct successor

Open:

`F-PE-NLGLOB12C — representation-aware endpoint convergence replay`.

The replay must remain test-only and preregistered before result exposure.

A candidate may terminate an endpoint solve only when:

1. every local residual is within its node-specific storage representation scale;
2. the total residual is within the aggregate storage representation scale;
3. existing head and ponding guards pass unchanged;
4. state is finite and route-consistent;
5. unchanged physical interval and cumulative mass gates pass after acceptance.

The certificate must be evaluated against the full 96-case replay bank, not only the eight positive cases.

No empirical multiplicative factor above 1 may be introduced in NLGLOB12C.

## Relation to NLGLOB12B

NLGLOB12B remains valid and separate.

The six still-descending cases are not covered by this certificate unless they independently reach the same representation-aware conditions.

A global MAXIT increase remains unsupported.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB12A

BASELINE: `4e07091a5dec6e21ece2d7a57f62444a4c25834d`

BRANCH: `research/f-pe-nlglob12a-stagnation-subset`

STATUS: closed positive

IMPLEMENTATION STATUS: observational aggregate-floor attribution persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`

NEXT SAFE STEP: preregister NLGLOB12C representation-aware endpoint replay

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
