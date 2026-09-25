# F-PE-ZERO-WASTE01 H09 — indexed receipt routing preregistration

Date: 2026-09-25

Status: `IMPLEMENTED_PENDING_QUALIFICATION`

## Observation

The current serialized MultiSWAP receipt path performs two separate repeated searches:

1. receipt request validation checks each requested receipt id against the full column-id vector and pairwise against later receipt ids;
2. during execution every column performs a linear scan of the receipt-id vector to find its receipt slot.

The dispatch microbenchmark at branch head `3a04f982cd4fa907133d5584a87ef359dd8aa947` measured for N=R=10,000 on the shared GitHub runner:

- receipt validation: about 44.68 ms/dispatch, structural work count 149,995,000;
- receipt lookup: about 37.77 ms/dispatch, structural work count 50,005,000.

These times are runner-specific and are not portable speed claims. The quadratic operation counts are the main evidence.

## Hypothesis H09

Build one temporary column-id index at dispatch preparation, validate the sparse receipt request against that index, and simultaneously construct:

`receipt_slot_by_column(column_index) -> requested_receipt_slot or 0`

The physical dispatch loop can then read the receipt slot directly instead of rescanning all requested receipt ids.

Expected structural complexity is approximately O(N+R) at normal hash occupancy instead of the current O(N*R + R^2).

## Semantics that must remain exact

- receipt requests remain optional;
- `receipt_column_ids` and `commit_receipts` must still be present together;
- requested ids must be positive;
- every requested id must correspond to a column id;
- duplicate requested ids must fail before backend initialization or any physical trial;
- a valid request preserves caller receipt order in `commit_receipts`;
- unrequested columns execute without an exported receipt;
- invalid registry structure remains rejected by the existing registry/execution-plan gate;
- no physics, solver, transaction, commit or mass-accounting semantics may change.

The index is dispatch-local. No persistent cache or new invalidation contract is introduced in H09.

## Implementation

Candidate implementation replaces `receipt_request_valid` plus per-column `find_receipt_slot` with a single `build_receipt_slot_map` preparation.

The index uses positive column ids as keys and open addressing with zero as the empty sentinel. Duplicate column ids are deliberately not reclassified here; registry validity remains owned by the existing registry/execution-plan validation stage.

## Qualification gates

Q1. Compile the actual serialized MultiSWAP runtime.

Q2. Existing FMR18 MultiSWAP receipt integration gate PASS unchanged, covering accepted receipt behavior and invalid request semantics.

Q3. F-PE dispatch-overhead benchmark PASS and emit both legacy structural measurements and the new `receipt_indexed` measurement for N=100, 1,000 and 10,000.

Q4. For N=R=10,000 the indexed work count must be linear in N+R, not quadratic.

Q5. No output, transaction, physical-state or mass-accounting oracle is relaxed.

Q6. Canonical admission remains separate; H09 may be qualified on the work branch without claiming canonical closure.

## Failure rules

- Any changed receipt ordering or changed rejection semantics invalidates H09.
- Any physical trial before an invalid receipt request is rejected invalidates H09.
- Hash/index failure must fail closed; it may not silently drop a requested receipt.
- Shared-runner elapsed time is supporting evidence only; the structural operation-count reduction is the portable claim.
