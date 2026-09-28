# F-PE-TIMEARCH05 closeout — retry ownership reconciliation

Date: 2026-09-28

Final status:

`QUALIFIED_RETRY_OWNERSHIP_HIERARCHY`

## Main finding

Current retry layers are nested rather than semantically duplicate.

They own different decisions:

- internal solver recovery;
- transaction rejection/retry;
- temporal rejection/retry;
- whole coupling-window retry.

But nested recovery can create substantial discarded work.

In the executable solver-escalation case:

- total work = 58;
- accepted work = 16;
- discarded work = 42.

This confirms that retry ownership must be explicit in the redesigned timestep architecture.

## Qualified target rule

Rejected trials do not update the accepted-step proposal controller.

The future hierarchy is:

1. local TrialExecutor recovery;
2. transaction RetryController;
3. coupling WindowController;
4. StepProposalController only after commit.

## Required successor

`F-PE-TIMEARCH06 — production decision-service extraction with exact legacy preservation`

TIMEARCH06 should move the already-qualified proposal/retry decision formulas into explicit production-owned services while preserving current behavior exactly.

The first production migration must not introduce a new adaptive algorithm.

It should:

- extract accepted-step proposal from monolithic TimeControl;
- extract retry decision from monolithic TimeControl where feasible;
- preserve hard event clipping;
- preserve legacy compatibility;
- prove exact trajectory/diagnostic identity on current Reference banks;
- add typed decision provenance without changing dt.

Only after this structural extraction should SWAP5 replace the legacy controller algorithm or reconsider normal-user DTMIN/DTMAX.

## Production boundary

No production source changes in TIMEARCH05.
