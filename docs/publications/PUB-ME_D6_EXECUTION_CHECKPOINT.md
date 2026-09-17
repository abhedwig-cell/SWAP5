# PUB-ME D6 execution checkpoint

Status: **PREREGISTERED_EXECUTION_DESIGN_BEFORE_D6_RUN**

Publication owner: `PUB-ME`

Experiment family: `D6 — rejected-trial external side effect survives`

## Immutable scientific design authority

- D1-D6 preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- execution base: `integration/f-ci-canonical@d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0`

At this base:
- D1 = STRUCTURAL_PREVENTION;
- D2 = EARLIER_DETECTION;
- D3 = STRUCTURAL_PREVENTION;
- D4 = EARLIER_DETECTION;
- D5 = EARLIER_DETECTION.

D6 is a distinct side-effect/publication defect family. It must not be interpreted as another physical-state or accounting mutation.

## Frozen publication surface

D6 uses the existing typed accepted-trajectory publication stack:

- mutable worker/job-local source: `accepted_trajectory_direction_t`;
- lower-level public materializer: `publish_accepted_trajectory_direction`;
- transaction-authority binding: `bind_accepted_trajectory_to_transaction`;
- immutable external result: `accepted_trajectory_direction_result_t`.

This surface is downstream-relevant because it represents a published accepted whole-trajectory directional response used by later coupling logic.

The production transaction binding explicitly requires:

- `transaction_result%status == TX_STATUS_ACCEPTED`;
- exactly one transaction commit;
- publication interval/provenance consistent with the accepted transaction.

D6 does not use surface-evaporation publication as the primary surface because that API is already atomically fused to the physical commit and would primarily re-test structural prevention. D6 instead tests an integration-level misuse that is constructible because the lower-level trajectory publisher is itself public.

## Frozen candidate scratch

Before any D6 result is observed, construct one valid available trajectory scratch object through the existing public trajectory API:

1. configure directional tracking;
2. begin trajectory for `[0,1]`;
3. build one step request for `[0,1]`;
4. stage a finite, available directional result;
5. accept that *internal trajectory step*;
6. finalize the trajectory scratch as available.

The trajectory state is intentionally capable of producing an immutable publication if materialized directly. This represents numerically complete candidate-side scratch, not authority for outer transaction acceptance.

The exact directional values are deterministic test data and are not physical model results. D6 studies publication lifecycle semantics, not sensitivity accuracy.

## Outer transaction contexts

Two outer transaction records are frozen.

### Accepted control

- status = `TX_STATUS_ACCEPTED`;
- commits = 1;
- requested interval = `[0,1]`;
- accepted end = 1.

Normal transaction binding must return one available publication with matching interval/provenance.

### Rejected control/fault context

- status = `TX_STATUS_RETRY_EXHAUSTED`;
- commits = 0;
- requested interval = `[0,1]`;
- accepted end = 0.

Normal transaction binding must return an unavailable result with route `transaction-not-accepted`.

No physical committed state is changed in either rejected-control or mutant route. A scalar accepted-state sentinel is frozen at its initial value and must remain bit-identical.

## External observer

A qualification-only downstream observer records only immutable `accepted_trajectory_direction_result_t` objects that are presented as externally visible accepted publications.

Observer fields:

- emission count;
- last publication availability;
- worker/generation/control identity;
- origin and accepted end time;
- accepted-step count;
- accepted bottom exchange derivative.

The observer itself is not the novelty claim; it represents an external consumer that cannot retract a record after the producing call has returned.

## Clean controls

### C-C accepted publication control

Normal `bind_accepted_trajectory_to_transaction` on the accepted transaction must:

- return available publication;
- emit exactly one observer record;
- preserve expected interval/provenance;
- leave physical sentinel unchanged.

### C-B rejected publication control

Normal binding on the rejected transaction must:

- return unavailable publication;
- emit zero observer records;
- leave physical sentinel unchanged.

Any observer emission in the clean rejected control is a B2 false positive / production-lifecycle failure and D6 must not proceed to a positive mutant interpretation.

## Qualification-only mutant

The exact seeded mutation is an integration error:

1. numerically complete trajectory scratch exists;
2. before consulting or binding the outer rejected transaction result, the faulty integrator calls `publish_accepted_trajectory_direction` directly;
3. because the scratch is locally available, an immutable publication is produced;
4. the faulty integrator emits it to the external observer;
5. only afterwards is the outer transaction known/processed as rejected.

No production/reference source is changed. No private state is accessed. No transaction status is forged. The mutation is exactly premature use of the public lower-level publisher.

## B1 strong conventional comparator

B1 does not ignore external output.

For the rejected transaction, conventional post-operation/integration validation checks:

- committed physical sentinel unchanged;
- transaction status rejected;
- transaction commits = 0;
- no accepted mass/state mutation is present in this bounded fixture;
- external accepted-publication count must be zero for a rejected transaction;
- no accepted publication interval/provenance may remain externally visible.

B1 detection occurs when the observer already contains the premature accepted publication after the rejected operation.

The study must not claim UNIQUE_DETECTION if this check detects the fault.

## B2 transition-authority oracle

B2 contains B1 plus the pre-emission rule:

> no externally visible accepted publication may be emitted unless the outer transaction has accepted the same interval and owns exactly one commit.

Immediately before any observer emission:

- check `transaction_result%status == TX_STATUS_ACCEPTED`;
- check `transaction_result%commits == 1`;
- require publication to be obtained through the transaction binding for accepted output.

For the rejected context, B2 detects the authority violation before the observer is called.

## Frozen classifications

- lower-level direct publication cannot produce an available external result without using the transaction-authority binding or another private bypass -> `STRUCTURAL_PREVENTION`;
- B1 and B2 both prevent/detect before observer emission -> `NO_INCREMENTAL_VALUE`;
- B2 detects before emission while B1 first detects after observer contamination -> `EARLIER_DETECTION`;
- bounded B1 stays green after observer contamination while B2 detects -> `UNIQUE_DETECTION`;
- rejected transaction produces an external accepted publication and neither B1 nor B2 detects -> `D6_AUTHORITY_FAILURE`;
- clean controls fail -> `INCONCLUSIVE_CLEAN_CONTROL_FAILURE`.

Classification rules must not change after output is observed.

## Required observations

Record:

- accepted-control binding availability and observer count;
- rejected-control binding availability/route and observer count;
- direct lower-level publication availability before outer rejection check;
- B2 pre-emission detection;
- mutant observer count after premature emission;
- B1 post-operation detection;
- physical sentinel bit identity;
- published origin/end time, generation, accepted-step count and derivative;
- O0/O2 semantic identity.

## Interpretation boundary

D6 tests a plausible **integration misuse of a real public publication surface**.

A positive result does not establish:

- an existing SWAP5 production defect;
- novelty of callback/observer lifecycle design;
- novelty of accepted/rejected transactions;
- that the lower-level publisher should necessarily be made private;
- UNIQUE_DETECTION unless B1 remains green;
- hydrologic-regime generality.

The current production executor already uses the transaction-authority binding after transaction execution. D6 asks whether that explicit authority boundary provides measurable qualification value when an integration layer bypasses it.

## Hard exclusions

- no `src/**` or `reference/**` mutation;
- no private-field mutation;
- no forged accepted transaction;
- no D1-D5 reinterpretation;
- no coupling-accuracy or sensitivity-accuracy claim;
- no post-result switch to a different publication surface;
- no physical-parameter tuning to create a side effect.

## Next permitted action

Implement exactly this D6 harness, runner and CI gate. Preserve a null, blocked or no-incremental-value result if observed. After D6 is frozen and admitted/closed, perform the preregistered cross-defect independence and PUB-ME publication go/no-go analysis before starting RQ1b.
