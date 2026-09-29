# F-PE-ELASTIC10E-R1 — settlement-determination identity reconciliation result

Date: 2026-09-29

Status: QUALIFIED_PROVENANCE_RECONCILIATION

Workflow:
`F-PE-ELASTIC10E-R1 determination identity reconciliation`

Run:
`36532519843`

Job:
`109289164067`

Qualified head:
`8d540320d392dd83349b472d34a2b17d76e0123e`

Conclusion:
PASS.

## Identity reconciliation

The historical ELASTIC10D classifier matched both the wrapper
`settlementCharacteristicsDetermination` and the physical inner
`SettlementCharacteristicsDetermination`.

The frozen reconciliation reduces:

- historical classifier records: `100`;
- physical settlement determinations: `50`;
- physical route authority: `29 R2 + 21 R3`.

Every historical pair is exact after removal of classifier-local index metadata.

The reconciled determination authority is persisted as:

`docs/performance/evidence/F-PE-ELASTIC10E_DETERMINATION_AUTHORITY.json`.

## Extractor authority binding

The ELASTIC10E extractor now accepts an explicit determination-authority input.

For every physical settlement determination:

- BRO object identity must exist in the frozen authority;
- physical determination count must match;
- physical indices must be contiguous;
- observed structural route must agree with frozen R2/R3 authority;
- target records carry both object readiness and determination-level authority.

The extractor may no longer silently choose a route when the frozen
determination authority is supplied.

## Numerical target preservation

The corrected extraction was compared against the pre-reconciliation green
artifact from run `36531232195`.

The complete frozen numerical target tuple set is unchanged for:

- BRO-ID;
- physical determination index;
- route;
- step index;
- stress endpoints;
- strain endpoints;
- signed stress/strain deltas;
- constrained compressibility `mv`;
- `Ssk_m_inv`;
- `Ssk_cm_inv`.

Markers:

- `F_PE_ELASTIC10E_R1_VALID_TARGETS=47`;
- `F_PE_ELASTIC10E_R1_VALID_ROUTES=R2:29,R3:18`;
- `F_PE_ELASTIC10E_R1_REJECTIONS=3`;
- `F_PE_ELASTIC10E_R1_NUMERICAL_POSTIMAGE=PASS`;
- `F_PE_ELASTIC10E_R1=PASS`.

Thus the reconciliation is provenance-only.

No mechanical target value changed.

## Rejection preservation

The same three pre-existing R3 candidates remain rejected for
`NONPOSITIVE_OR_ZERO_SECANT`.

No extraction rule was relaxed.

## Decision

F-PE-ELASTIC10E-R1 closes the settlement-determination identity ambiguity.

The 47-target ELASTIC10E corpus remains the numerical mechanical target
authority, now with exact physical-determination provenance.

Downstream predictor work may use this reconciled corpus but must preserve
object-grouped calibration/holdout ownership.
