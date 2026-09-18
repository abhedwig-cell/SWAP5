# PUB-ME D1 comparator and mutation freeze

Status: **PREREGISTERED_BEFORE_FIRST_EXECUTION**

Publication owner: `PUB-ME`

Experiment: **D1 — rejected candidate mutates committed physical state**

Design authority: `work/pub-me-literature-pass2@b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`

Execution base: `integration/f-ci-canonical@7b864853ca22baa73141b2dec9ed2f3915ef520d`

Freeze date: 2026-09-18

## 1. Purpose

This file freezes the D1 comparator and exact fault model before the first experimental result is inspected.

The experiment does not test whether rollback or timestep rejection is novel. It tests whether explicit transition-authority protection detects or structurally contains a rejected-trial state-contamination fault earlier than a strong conventional scientific-software baseline.

## 2. Physical fixture

Reuse the admitted Reference/HeadCalc fixture already qualified by `PUB-P1E02`:

- four-node B1.10 Reference grid from the existing publication fixture;
- uniform initial pressure head `-75 cm`;
- no top or bottom water flux;
- requested interval `0.25 d`;
- `TX_TEMPORAL_EXTERNAL_FULL_HALF`;
- first attempt temporal tolerance exactly `0`;
- no transaction retry;
- real Reference/HeadCalc execution before rejection;
- mass tolerance `1e-12 cm`.

The clean full-stack authority for this physical rejection route is `docs/publication/P1_POSTSOLVER_ROLLBACK_RESULT.json`.

## 3. Exact D1 mutation

The only semantic mutation is committed as:

`tests/publication/mutants/d1_rejected_candidate_write_through.patch`

It changes only the qualification-build copy of `src/transaction/mod_transaction_reference.f90`.

For a transaction whose temporal tolerance is exactly zero, the full physical trial is deliberately advanced on the transaction layer's `committed` state rather than on the checkpoint clone. The resulting state is then cloned into `full_state` only for the normal mass/temporal assessment.

All half-step work, temporal assessment, rejection logic, physics, forcing, HeadCalc code and later non-zero-tolerance transactions remain unchanged.

This is a test-only write-through fault. It is never applied to repository production source.

## 4. Layered execution

### D1-A — operative transaction-layer fault

Run the real serialized Reference model directly through `execute_reference_interval` with the physical state passed as the transaction layer's authoritative `committed` state.

The zero-tolerance first transaction must:

1. execute real HeadCalc work;
2. be temporally rejected;
3. leave accepted mass publication empty;
4. under the mutant, nevertheless leave physical state changed.

Then execute the same interval again with a permissive non-zero temporal tolerance using the state left after the rejected attempt.

This second run measures the downstream scientific consequence without activating the mutation a second time.

### D1-B — full-stack containment

Compile and run the existing `PUB-P1E02` full kernel/FMR post-solver rejection test against the *same mutated transaction module*.

The canonical runtime and kernel each operate on private clones before accepted publication. Therefore the predeclared structural-containment hypothesis is:

> the transaction-layer write-through mutant is operative in D1-A but does not reach the kernel-committed state in D1-B.

This is an executable test of structural prevention, not an architecture-inspection claim.

## 5. Comparator membership

### B0

Successful accepted-trajectory/reference comparison after the rejected attempt.

D1 is B0-detected only if the later accepted physical endpoint differs between clean and mutant executions.

### B1

Strong conventional checks, excluding the transition-authority oracle under test:

- solver actually executed;
- rejected transaction reports no accepted mass transaction;
- rejected accepted-total-in/out remain zero;
- subsequent accepted transaction closes its normal mass gate;
- deterministic O0/O2 reproduction;
- downstream accepted endpoint comparison.

B1 may detect D1 downstream. That does not eliminate incremental value if contamination occurred earlier.

### B2

Adds the explicit transition-authority checks:

- physical committed state identity immediately before versus immediately after the rejected transaction;
- no accepted-state mutation is allowed at the rejection boundary;
- full-stack clone isolation must prevent the lower-layer mutant from reaching kernel-committed state.

## 6. Predeclared classifications

- `NO_INCREMENTAL_VALUE`: B1 detects/prevents the fault before accepted-state contamination at an equally protective boundary.
- `EARLIER_DETECTION`: B2 detects state contamination immediately after rejection while B1 detects only later downstream.
- `UNIQUE_DETECTION`: B2 detects contamination and B1 does not detect it within the bounded continuation.
- `STRUCTURAL_PREVENTION`: the higher admitted boundary prevents the operative lower-layer write-through from reaching authoritative kernel state.
- `INCONCLUSIVE`: the mutation is non-operative or the clean/mutant comparison cannot be made fairly.

D1 may legitimately produce both an operative-layer classification and a higher-layer `STRUCTURAL_PREVENTION` result.

## 7. Negative-result rules

Do not redesign the mutation after seeing the first result merely to increase B2 advantage.

If the zero-tolerance full trial does not mutate the transaction-layer committed state, record `MUTANT_NON_OPERATIVE`.

If the mutant breaks physical solver execution before the intended rejection boundary, record `INVALID_MUTANT`.

If clean and mutant later accepted endpoints are identical, do not manufacture a downstream consequence; report immediate contamination only.

No production source, physical equation, forcing or constitutive parameter may be altered to force a positive result.
