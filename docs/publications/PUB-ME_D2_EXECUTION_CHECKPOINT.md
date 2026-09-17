# PUB-ME D2 execution checkpoint

Status: **PREREGISTERED_EXECUTION_DESIGN_BEFORE_D2_FAULT_RUN**

Publication owner: `PUB-ME`

Experiment family: `D2 — retry double-counts scientific exchange/accounting`

## Immutable scientific design authority

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- original D2 defect semantics: rejected work contributes to accepted accounting and is counted again after a successful retry.

No D2 outcome may change the B0/B1/B2 hierarchy or the publication falsification rule.

## Execution authority

- execution base: `integration/f-ci-canonical@dba238b4b20551dcc36e9121ffe25f19a5b1ac0e`
- retry authority: current-canonical FCI14 Reference temporal-policy route
- source precedent: `tests/fci/test_fci14_reference_temporal_policy.f90`

FCI14 already establishes, before this publication experiment:

- one real Reference candidate transaction;
- one temporal rejection;
- one rollback/retry;
- acceptance on the retry;
- accepted retry endpoint at `t=10.5` for request `[10,11]`;
- hard mass-residual checks.

The D2 workunit does not tune a new retry case.

## Frozen physical/numerical context

Use the exact FCI14 temporal-policy context:

- Reference process state captured from the existing FCI14 backend stubs;
- request interval `[10.0, 11.0]`;
- temporal policy tolerance `1.0`;
- mass tolerance `1.0e-12`;
- retry scale `0.5`;
- max retries `2`;
- same temporal-limit profile as FCI14:
  - h 0.01
  - theta 0.01
  - pond 0.01
  - gwl 0.10
  - volact 0.10
  - ldwet 0.10
  - spev 0.10
  - saev 0.10.

The existing FCI14 accepted retry route must first replay successfully in the D2 harness.

## Frozen D2 fault operator

Use a qualification-only observing model that extends the existing
`b1_10_reference_policy_candidate_model_t`.

The observing model delegates every physical advance to the unchanged parent Reference implementation. It does not alter physical state, solver inputs, forcing, temporal assessment or the canonical transaction result.

It additionally maintains a test-only **faulty accepted ledger**:

1. call 1 = full trial of first attempt;
2. calls 2 and 3 = first-attempt half1 and half2;
3. after successful call 3, the fault operator prematurely publishes the sum of half1 + half2 mass in/out into the test-only accepted ledger;
4. when call 4 begins, the transaction has entered the retry after the first temporal rejection; the test records whether the faulty accepted ledger is already nonzero;
5. after `execute_reference_interval` returns accepted, the normal accepted transaction totals are also added to that same faulty ledger.

Thus the fault exactly represents the preregistered D2 semantics: rejected-attempt accounting survives and the accepted retry is counted as well.

No production ledger or result object is mutated.

## Matched CLEAN and MUTANT

Run two otherwise identical FCI14 transactions.

### CLEAN

The observing side ledger is disabled. The canonical result and accepted state must match the established FCI14 retry authority.

### MUTANT

The test-only premature accepted-ledger publication is enabled as specified above. The physical model and canonical transaction result must remain identical to CLEAN.

## Frozen B1 observations

B1 is the strong conventional scientific-software baseline.

B1 checks after the transaction:

- transaction accepted;
- exactly one temporal rejection;
- exactly one retry/rollback;
- accepted endpoint matches CLEAN;
- canonical accepted mass residual remains within `1e-12`;
- canonical accepted mass result matches CLEAN;
- final **faulty published ledger** is checked against the accepted storage change.

B1 detects the mutant if the final faulty ledger fails accepted mass closure or differs from the clean accepted ledger.

B1 does not inspect the test-only accepted ledger during the rejected attempt or at retry entry.

## Frozen B2 transition-authority oracle

B2 adds one direct lifecycle assertion:

> At the start of a retry following a rejected attempt, the accepted scientific ledger must still contain zero contribution from that rejected attempt.

The observing model records the ledger state when physical call 4 begins. B2 detects the seeded fault if the premature ledger is already nonzero before retry physical work.

## Primary outcomes

Record for CLEAN and MUTANT:

- transaction status;
- temporal rejection count;
- retry and rollback counts;
- accepted endpoint;
- canonical accepted total in/out;
- canonical accepted mass residual;
- premature ledger in/out at retry entry;
- final test-only published ledger in/out;
- final mass closure using the test-only ledger;
- first detection layer.

## Interpretation

Allowed classifications:

- `EARLIER_DETECTION`: B2 detects nonzero accepted ledger at retry entry while B1 detects only after final accepted accounting;
- `UNIQUE_DETECTION`: B2 detects at retry entry and the complete frozen B1 checks do not;
- `NO_INCREMENTAL_VALUE`: B1 detects the defect at the same transition boundary without the B2 authority oracle;
- `STRUCTURAL_PREVENTION`: the admitted transaction surface makes the seeded early accepted-ledger publication unrepresentable and the observing fault cannot be instantiated without production mutation;
- `BLOCKED_REFERENCE_RETRY_AUTHORITY`: the unchanged FCI14 retry route no longer reproduces its established one-rejection/one-retry accepted behavior.

The result may reject the paper hypothesis.

## Hard exclusions

- no `src/**` mutation;
- no `reference/**` mutation;
- no changes to FCI14 physical/numerical settings;
- no changes to mass or temporal tolerances after observing results;
- no production accepted-ledger backdoor;
- no D3-D6 execution;
- no claim that retry, rollback or mass closure are novel;
- no claim that a qualification-only side ledger is an existing SWAP5 defect.

## Next permitted action

Implement the observing model and matched CLEAN/MUTANT test exactly as frozen above. Run under O0 and O2. If the FCI14 clean retry authority does not reproduce, stop with `BLOCKED_REFERENCE_RETRY_AUTHORITY` and do not tune the case.
