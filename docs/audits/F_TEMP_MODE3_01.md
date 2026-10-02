# F-TEMP-MODE3-01 — external full/half temporal acceptance gap

Date: 2026-10-03
Status: REPAIR_CANDIDATE_UNDER_QUALIFICATION

## Discovery

A28 Q4B exact-only threshold qualification exposed deterministic transaction failure for SWBOTB=3 / bottom_mode=3 under TX_TEMPORAL_EXTERNAL_FULL_HALF.

Bounded decomposition showed identical behavior with BASE and RFM optional-state layouts, for B01 and O05:
- admission rejections: 0;
- solver rejections: 0;
- mass rejections: 0;
- temporal rejections: 5;
- attempts: 5;
- retries: 4;
- canonical status: TRANSACTION_FAILED.

RFM is therefore not causal.

## Root cause

`fmr_serialized_temporal_identity` rejects every bottom mode except 7, -2, 5 and 2 before evaluating physical full/half state difference. For bottom_mode=3 it returns `huge()`. Under external full/half acceptance, `terr <= temporal_tolerance` can therefore never pass.

This is a runtime contract gap: the Reference solver executes, but the transaction layer makes mode 3 unconditionally non-admissible under this temporal mode.

## Minimal repair

Add bottom_mode=3 to the modes admitted to the existing physical temporal-error calculation. Do not alter:
- temporal tolerance;
- retry policy;
- solver tolerances;
- mass tolerance;
- Cauchy boundary semantics;
- exact/approximate RFM policy.

## Qualification

1. BASE mode-3 one-step B01/O05 must no longer be rejected solely because temporal error is `huge()`.
2. RFM exact mode-3 must have the same temporal admission semantics as BASE.
3. Existing admitted bottom modes retain behavior.
4. Q4B Stage A remains exact-only; approximate A28_V1 is not run until an executable threshold-crossing exact fixture is frozen.

No canonical admission is claimed by this record.
