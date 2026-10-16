# F-ROMV terminal canonical reconciliation

**Workstream:** F-ROM  
**Status:** CLOSED NO-GO UNDER CURRENT PROPOSITION  
**Canonical preimage:** `d5587a650007e96e9f6008a179ac4bdf0cf77218`  
**Canonical scope:** evidence and research authority only

## Why this reconciliation exists

F-ROMV first closed its computational-value exploration conditionally: there was no authority for a general or cross-material SWAP5 ROM, but one narrow B01/template-local many-query experiment was permitted. That decision was persisted on research head `f662451bcc825dc4b4933c1a947e2d6227f66b9e` and PR #403.

The permitted experiment was then preregistered and executed on branch `work/f-romv-mde-b01`. Its terminal research head is `c4626211a20a6e00bd0b09a0e84253b8d848405d`, PR #409.

This page reconciles both stages to the current canonical line without importing research execution code into production.

## Scientific result

The terminal decision is:

**`STOP_SIMPLE_TEMPLATE_LOCAL_ROM`**

The tested nine-state B01 representation retained structural water accounting, but the frozen low-capacity dynamics and validity detector did not survive held-out hydraulic transitions.

The decisive failures are independent of a generic RMSE criterion:

- H02 produced incorrect bottom-flux direction on transitions classified as inside the reduced domain;
- the second H02 bottom-flux reversal occurred at reduced step 38 instead of full-order step 57, nineteen 0.0008-day observation steps too early;
- H03 produced physically inadmissible reconstructed moisture states on eight transitions still classified as inside the reduced domain;
- H04 was safely rejected because its combined forcing tuple was outside the discovery forcing set, but this required full-order fallback on all 63 evaluated transitions;
- across all held-out histories, the hybrid route used full-order fallback on 78 of 252 transitions, about 30.95%.

The structural water ledger itself passed. This is therefore a dynamics and validity-domain failure, not a bookkeeping failure concealed by a mass correction.

## Relation to ROM-1

The result does not overturn the terminal ROM-1 conclusion `MATERIAL_SPECIFIC_ONLY`.

ROM-1 showed that the B01 `Z8_PLUS_G8` representation separated the tested B01 states within its frozen state-sufficiency experiment. F-ROMV now establishes a different point: state separation is not sufficient evidence that a simple low-dimensional propagation law is safe.

B14 cross-material transfer remains unadmitted and ROM-2 remains unauthorized.

## Postimage reconciliation

Canonical advanced by 37 commits after the original F-ROMV branch point. The intervening delta includes production application work and a changed serialized Reference backend. It does not change the admitted F-ROSS24 screening authority, the MP performance evidence boundary, or the terminal ROM-1 evidence used in the F-ROMV decision.

Stage 1 is not re-executed against the changed backend. Its data authority is the immutable qualified ROM1AR2 artifact from workflow run `35379176697`, artifact `10561841507`, digest `sha256:2b04e188b7ce1593e073031fc43580550513e857dfb74b9993844a3230a1a67f`. The accepted trajectory payload used in the analysis has SHA-256 `f1ea53496cd08cbadf1ceaad46c78d83a0767957fd9de676c88c51162346a1e0`.

Changing the current Reference implementation therefore cannot retrospectively alter the preregistered experiment. A future new experiment against newer Reference authority would be a new work unit.

## Why the direct performance stage stops here

The parent MDE required scientific validity before computational value. The frozen Stage-1 kill rules were triggered before the RossFast and spatially coarsened Richards cost-error comparison.

That comparison is deliberately not run. A speed advantage cannot admit a reduced dynamics law that publishes the wrong flux direction or an invalid physical state.

Likewise, ridge regularization, a different OOD distance, more local regimes, recurrent memory or a neural operator are not introduced after seeing the failure. Those could define a different scientific proposition, but they cannot repair this frozen experiment after the fact.

## Canonical admission boundary

This reconciliation imports:

- the original F-ROMV computational-value audit;
- the frozen minimal-experiment design;
- the Stage-1 preregistration;
- the Stage-1 result and status;
- the terminal scientific interpretation.

It imports no research execution harness, no `src/**`, no `reference/**`, no production solver and no new numerical or hydrological policy.

## Decision

F-ROMV is **closed under the current proposition**.

There is no current authority for:

- a production SWAP5 ROM;
- a cross-material ROM;
- ROM-2 closure development;
- post-result OOD or regularization retuning;
- automatic escalation to a neural surrogate.

A future reopening requires a separately governed proposition, justified by genuinely new computational-bottleneck evidence or a materially different scientific question. The negative F-ROMV result remains part of the evidence and may not be reclassified away.
