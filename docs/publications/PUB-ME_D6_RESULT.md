# PUB-ME D6 result

Status: **QUALIFIED_PRIMARY_RESULT_PENDING_POSTIMAGE_ADMISSION**

Publication owner: `PUB-ME`

Experiment family: `D6 — rejected-trial external side effect survives`

## Design authority

- D1-D6 preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- D6 execution checkpoint: `docs/publications/PUB-ME_D6_EXECUTION_CHECKPOINT.md`
- execution base: `integration/f-ci-canonical@d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0`

The D6 publication surface, clean controls, qualification-only mutation, B1/B2 timing and classification rules were frozen before scientific execution.

## Frozen publication surface

D6 used the admitted accepted-trajectory directional publication stack:

- candidate/job-local trajectory scratch: `accepted_trajectory_direction_t`;
- lower-level public materializer: `publish_accepted_trajectory_direction`;
- transaction-authority binder: `bind_accepted_trajectory_to_transaction`;
- immutable result: `accepted_trajectory_direction_result_t`.

The normal binder requires an accepted outer transaction with exactly one commit before an accepted trajectory result can be returned.

D6 did not modify this production path.

## Pre-execution runner corrections

Two initial workflow attempts failed before D6 scientific execution.

1. The runner initially treated pre-existing exact REAL comparisons in unchanged `mod_transaction_reference.f90` as errors under `-Werror=compare-reals`.
2. After isolating that canonical dependency, the same pre-existing warning class was encountered in unchanged `mod_accepted_trajectory_directional_sensitivity.f90`.

The runner was corrected so these two unchanged canonical dependencies compile with `-Wno-error=compare-reals`, while D6-owned test code remains under strict `-Werror`.

No publication surface, mutant, transaction context, observer logic, comparator or classification rule changed.

## Qualified primary execution

Exact executable head before this result record:

- `49528ff65acab55614321d035da0d7852c119185`

Evidence:

- workflow: `PUB-ME D6 rejected publication`
- run: `35288979539`
- job: `105427474311`
- conclusion: **SUCCESS**
- O0: PASS
- O2: PASS
- O0/O2 semantic identity: PASS
- O0/O2 SHA-256: `9563ed157258f1993a826a9ef498498cafa45254266818d877db73bb28c88643`

## Clean accepted control

A valid candidate-side directional trajectory was bound to an outer transaction with:

- status `TX_STATUS_ACCEPTED`;
- commits = 1;
- requested interval `[0,1]`;
- accepted end = 1.

The authoritative transaction binding returned one available immutable publication and the external observer received exactly one record.

Observed provenance:

- worker = 61;
- generation = 6001;
- control coordinate = bottom flux;
- accepted steps = 1;
- origin t0 = 0;
- accepted t1 = 1.

Marker:

`PUB_ME_D6_ACCEPTED_CONTROL=PASS`

## Clean rejected control

The same locally available trajectory scratch was bound through the authoritative transaction binding to an outer transaction with:

- status `TX_STATUS_RETRY_EXHAUSTED`;
- commits = 0;
- requested interval `[0,1]`;
- accepted end = 0.

The transaction binding returned an unavailable result with rejected-transaction semantics and the observer received zero records.

Marker:

`PUB_ME_D6_REJECTED_CONTROL_ZERO_PUBLICATION=PASS`

The clean controls therefore establish that the publication fixture itself is valid and that the production transaction-authority path does not emit accepted output for the rejected context.

## Qualification-only D6 mutation

The faulty integration route deliberately bypassed the transaction-authority binding:

1. numerically complete trajectory scratch was available;
2. `publish_accepted_trajectory_direction` was called directly;
3. the lower-level public publisher returned an available immutable result;
4. that result was emitted to the external observer;
5. the outer transaction remained `TX_STATUS_RETRY_EXHAUSTED` with zero commits.

No private field was accessed or forged.

The directly published rejected-work result carried:

- worker = 61;
- generation = 6001;
- accepted steps = 1;
- origin t0 = 0;
- accepted t1 = 1;
- accepted bottom exchange derivative = 0.625.

Markers:

- `PUB_ME_D6_DIRECT_PUBLICATION_AVAILABLE=YES`
- `PUB_ME_D6_MUTANT_OBSERVER_COUNT=1`

This establishes that an integration layer can construct the seeded D6 fault by using the lower-level public publisher outside its accepted transaction authority.

## Physical-state control

The bounded D6 fixture does not mutate physical model state.

A physical-state sentinel remained bit-identical across accepted control, rejected control and faulty publication route.

Marker:

`PUB_ME_D6_PHYSICAL_STATE_UNCHANGED=PASS`

This is important for interpretation: D6 is an external-history/publication contamination defect rather than another physical-state leakage defect.

## B2 transition-authority result

Before any observer emission, B2 evaluates the outer transaction authority:

- transaction status must be `TX_STATUS_ACCEPTED`;
- transaction commits must equal 1.

The rejected D6 context fails that authority gate before publication is emitted.

Marker:

`PUB_ME_D6_B2_PREEMISSION_AUTHORITY=DETECTED`

B2 therefore detects the defect before external accepted history is contaminated.

## B1 strong conventional result

B1 includes external accepted-output regression. After the rejected operation it requires the external accepted-publication count to be zero.

The qualification-only mutant left one externally visible immutable publication, so B1 detects the fault immediately after the rejected operation.

Marker:

`PUB_ME_D6_B1_POSTOP_PUBLICATION_REGRESSION=DETECTED`

D6 therefore does not establish unique detection by B2.

## Primary classification

**D6 = EARLIER_DETECTION**

This is exactly one of the preregistered classes.

It is not `STRUCTURAL_PREVENTION` because the lower-level public publisher can materialize the locally available trajectory scratch without receiving an outer transaction result.

It is not `UNIQUE_DETECTION` because strong B1 detects the externally visible rejected-work publication after the operation.

The incremental B2 value is temporal/localization value: the transaction-authority contract rejects publication before the irreversible observer side effect is emitted.

## Current D1-D6 classifications

The complete first-pass prospective defect-family set now yields:

- D1: `STRUCTURAL_PREVENTION`;
- D2: `EARLIER_DETECTION`;
- D3: `STRUCTURAL_PREVENTION`;
- D4: `EARLIER_DETECTION`;
- D5: `EARLIER_DETECTION`;
- D6: `EARLIER_DETECTION`.

These six labels must **not** be interpreted as six statistically independent positive results.

Cross-defect independence, common-mechanism overlap, physical-regime replication and literature novelty remain mandatory before a standalone PUB-ME publication decision.

## Interpretation boundary

D6 establishes only the bounded result above.

D6 does **not** establish:

- an existing SWAP5 production publication defect;
- novelty of observer/callback lifecycle design;
- novelty of transaction gating;
- that conventional scientific-software testing is inadequate;
- unique detection by B2;
- sensitivity/coupling accuracy;
- a recommendation that every lower-level publisher must be private;
- hydrologic-regime generality;
- publication readiness of PUB-ME.

The current production trajectory executor already uses the accepted transaction binding after transaction execution. The seeded fault represents a plausible integration misuse of a lower-level public publication surface.

## Next permitted action

1. replay D6, documentation and full canonical qualification on the result-bearing head;
2. reconcile live canonical delta;
3. if green and dependency-stable, admit/close D6;
4. perform the preregistered cross-defect independence and PUB-ME publication go/no-go analysis;
5. do **not** start publication-primary RQ1b selective requalification until that cross-defect decision is frozen.
