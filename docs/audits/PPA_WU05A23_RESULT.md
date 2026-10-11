# PPA-WU05-A23 result — RFM whole-column candidate ledger

Date: 2026-10-01
Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE
Baseline: integration/f-ci-canonical@e9f210a41bca5bf9c6b9118f91a2be020e76b26f
Qualified postimage: 429da95848155a04812b04cb10f526d25d1e4c80
Qualification run: 36873846314 — SUCCESS

Focused gate:

    PPA_WU05A23_RFM_WHOLE_COLUMN_LEDGER=PASS

## Qualified ownership algebra

For one candidate interval:

    effective input = matrix input + IC input + MB input
    IC input + endpoint storage start
      = endpoint-to-matrix transfer + endpoint storage end
    MB input = MB wall-to-matrix transfer + MB deep receipt

Therefore:

    effective input + endpoint storage start
      = matrix input
      + IC endpoint-to-matrix transfer
      + MB wall-to-matrix transfer
      + MB deep receipt
      + endpoint storage end

All identities close within 1e-12 cm in the focused oracle.

## Leading MB semantics
A22B resolves the leading persistent MB input completely within the interval to wall exchange or deep receipt. Therefore A23 requires leading MB storage end = 0. A19's MB storage field remains a generic carrier but is not populated by this leading composition.

## Ownership
IC/MB wall transfers are internal whole-column transfers. MB deep receipt is external/deep RFM output. Matrix surface input remains owned by the existing Richards route. No term is counted twice.

## Decision

    A21_FAST_DOMAIN_FATE_BLOCKER = RESOLVED
    WHOLE_COLUMN_CANDIDATE_OWNERSHIP = QUALIFIED
    LIVE_RUNTIME_GUARD_REMOVAL = NOT YET AUTHORIZED
    NEXT = A24 transaction composition around real Richards trial
