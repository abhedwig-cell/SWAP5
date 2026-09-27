# F-PE-DIR01 Repair02 result

Date: 2026-09-26

Status: `REJECTED_SEMANTICS`

Experiment:
remove the accepted-half attempt-context capture/restore round-trip from the external full-half transaction route.

## Local directional evidence

The specialized bottom-head directional fixture initially looked favorable.

Across 12 paired timings:
- mean candidate/base ratio: `0.977487704`;
- median ratio: `0.981339820`;
- mean speedup: `2.251230%`;
- median speedup: `1.866018%`;
- all observed pairs were faster.

Heap confirmation also matched the hypothesis:
- `-7 malloc` per interval;
- `-7 free` per interval;
- approximately `-1009 bytes` malloc traffic per interval.

The specialized fixture preserved:
- physical checksum;
- accepted bottom-exchange derivative;
- accepted-step count;
- accepted backsolve count;
- nonlinear and constitutive counts.

## Preservation failure

The production edit was then tested against the generic transaction preservation gate.

`tests/transaction/run_a23bl_gate.sh` failed with 16 failures, including:
- normal accepted route;
- normal two-half route;
- commit accounting;
- endpoint preservation;
- temporal-retry acceptance/accounting;
- rollback from committed checkpoint;
- solver-failure rollback;
- failed-trial leak isolation;
- noncalendar interval behavior;
- parallel worker independence.

This demonstrates that the accepted-half attempt-context restore is semantically required for generic transaction models, even though it appears redundant in the specialized bottom-head directional fixture.

## Decision

Repair02 is rejected.

The production edit has been fully reverted.

No part of the transaction-core change is retained.

The experiment remains valuable evidence: specialized-path equivalence is insufficient authority for removing generic transaction state restoration.

## Remaining direction

Repair01 remains qualified and retained.

Any next DIR01 repair must avoid weakening generic transaction rollback/commit semantics and should target directional-local ownership or calculation work instead.
