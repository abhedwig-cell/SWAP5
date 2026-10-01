# PPA-WU05-PERCH21 preregistration — FrReduQ transaction integration

Date: 2026-10-01

Status: `PREREGISTERED / CURRENT-CANONICAL_RECONSTRUCTION`

Baseline:
`integration/f-ci-canonical@4a9878b03791b7b9d43aa34aa70ed7ccdce13b08`

Owning qualified dependencies:

- A18 source-backed perched authority and active inner exchange research result;
- PERCH19 exact FrReduQ continuation semantics;
- PERCH20 qualified model-proposed retry-duration directive.

## Purpose

Reconstruct the perched production path from current canonical without merging the
historical pre-canonical perched ancestry wholesale.

PERCH21 owns the missing numerical lifecycle needed to make the exact SWAP 4.3.1
FrReduQ retry ladder transaction-safe and restartable.

## Phase 1 — generic transaction lifecycle

Current canonical has neither:

- model-proposed retry duration;
- post-accept numerical feedback.

PERCH21 first adds the smallest generic default-no-op contract.

### Solver-rejected full trial

A trial outcome may propose:

- next attempt duration;
- positive reason/provenance code.

Transaction ownership remains authoritative.

If no proposal exists, current fixed `retry_scale` behavior is preserved exactly.

If a valid proposal exists:

1. rejected physical state is discarded;
2. original physical checkpoint remains the retry origin;
3. post-failure trial-local attempt context may be recaptured;
4. next attempt uses the exact proposed duration;
5. max-retry bounds remain unchanged.

### Final accepted interval

After final physical acceptance and accepted-route context restoration, the model receives
exactly one default-no-op-capable callback:

`apply_accepted_feedback(accepted_dt,ok)`.

This callback is numerical continuation only. It may not alter accepted physical state.

### Isolation rules

- no retry feedback on mass rejection;
- no retry feedback on temporal rejection;
- no retry feedback from speculative half-step failures;
- accepted feedback exactly once for the finally accepted route;
- existing models with default hooks remain behaviorally unchanged.

## Phase 2 — PERCH19 numerical continuation binding

Carry forward the exact source-faithful pure state machine:

- reduction level 0..3;
- factors 1.0, 0.1, 0.01, 0.001;
- recovery counter;
- recovery dt;
- no recovery-counter reset on escalation;
- geometric-mean retry `sqrt(dtmin*dtmax)`;
- ten-step/larger-dt recovery.

The seven-field physical macropore state remains unchanged.

## Phase 3 — current-canonical perched reconstruction

Only after phases 1 and 2 qualify, selectively carry the minimum current-iterate
inner-callback dependencies needed by the A18 Andelst authority.

Do not import historical generic A11-A18 status/document paths.

## Required end-to-end gates

### G1 generic preservation

Existing transaction models with no new hooks reproduce current canonical behavior.

### G2 retry directive

A solver-rejected full trial may request an upward retry duration while physical rollback
and committed-state isolation remain exact.

### G3 accepted feedback

Accepted feedback fires once only after final accepted-route publication and survives as
numerical continuation.

### G4 speculative isolation

Mass/temporal rejected and speculative half-step routes cannot leak numerical continuation.

### G5 PERCH19 source state machine

Exact escalation/recovery semantics and O0/O2 identity.

### G6 numerical persistence

FrReduQ continuation persists/restores independently of the seven physical macropore
fields.

### G7 A18 active perched replay

On the source-backed Andelst fixture:

- factor 1.0 follows ordinary retry ordering;
- at the exact minimum-step condition the level escalates;
- geometric-mean retry is used;
- factor 0.1 converges;
- nonzero perched transfer is materialized once;
- internal and macropore mass closure pass;
- reject/replay/restart pass.

### G8 preservation

Default inner/outer route behavior and current canonical admitted macropore capability
remain unchanged when PERCH21 continuation is inactive.

## Non-scope

- no covering-layer extension;
- no dynamic crack feedback;
- no RossFast changes;
- no parallel MultiSWAP changes;
- no hardcoded permanent `flow_reduction=0.1`.

## Decision states

- `QUALIFIED_FREDUQ_TRANSACTION_INTEGRATION_PRODUCTION_ADMISSION_CANDIDATE`;
- `QUALIFIED_GENERIC_LIFECYCLE_PERCHED_BINDING_FOLLOWUP_REQUIRED`;
- `BLOCKED_TRANSACTION_LIFECYCLE`;
- or `FALSIFIED_FREDUQ_INTEGRATION_ROUTE`.
