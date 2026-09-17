# Test bank authority

## Purpose

This page defines the canonical repository-level structure and traceability rules for the SWAP5 test bank.

The test bank is the versioned set of permanent tests, qualification tests, reference checks and supporting verification tooling used to protect scientific, numerical, architectural and execution claims. This page makes that structure navigable. It does not replace the scientific contracts, verification principles, reference-baseline authority or capability-specific qualification evidence.

The machine-readable inventory is `test-bank-catalog.yaml`.

## Authority boundaries

Use the owning authority for each question:

| Question | Authority |
| --- | --- |
| What must verification establish? | `docs/verification/principles.md` |
| Which B0, B1 and B2 reference is authoritative? | `docs/verification/reference-baselines.md` |
| Which current Status-A claims are admitted and preserved? | `docs/status-a/TRACEABILITY.md` and the named capability evidence |
| Which repository test surfaces exist and how must they be registered? | this page and `docs/verification/test-bank-catalog.yaml` |
| What does a specific test actually execute? | the test source and fixtures on the exact pinned commit |

A catalog entry is navigation and traceability metadata. It is not itself scientific evidence and cannot upgrade a regression test into a scientific qualification.

## Test bank versus qualification evidence

Keep four concepts separate.

**Permanent test** means executable, versioned test logic retained in the repository to protect a behaviour, contract or invariant across later changes.

**Qualification gate** means an acceptance procedure that may invoke permanent tests, reference models, compiled cases or dedicated runners to decide whether a bounded claim is admitted.

**Evidence** means the versioned result of a qualification or preservation run, including the tested postimage, scope, oracle, acceptance criterion and verdict.

**Benchmark** means a measurement workload. Performance evidence does not establish physical or numerical correctness unless a separate qualification contract explicitly says so.

`tests/` is the primary permanent SWAP5 test surface. `tools/vq/` contains verification and qualification tooling and its own unit tests. `reference/swap-4.3.1/patches/*/tests/` contains focused tests tied to corrected-reference work. Capability evidence and admission records remain outside the test bank itself.

## Classification

A test can belong to more than one class. Use the narrowest classes that describe what it actually proves:

| Class | Meaning |
| --- | --- |
| `unit` | Local logic or data transformation without claiming integrated model behaviour |
| `contract` | Interface, schema, ownership or API rule |
| `integration` | Composition across two or more components or execution layers |
| `regression` | Reproduction of a frozen expected result or previously admitted behaviour |
| `scientific-qualification` | Behaviour checked against an explicit scientific or numerical oracle |
| `conservation` | Mass or other accounting invariant checked with an explicit acceptance criterion |
| `transaction-restart` | Trial/commit, rollback, restart, determinism or state-ownership property |
| `performance` | Cost, repeatability, workload or execution-policy measurement |
| `static-process` | Repository, source, documentation, provenance or process invariant |

Passing a `regression` test proves consistency with its oracle. It does not by itself prove that the oracle is scientifically correct.

A `scientific-qualification` claim must identify an independent or explicitly accepted oracle, for example an analytical result, conservation law, corrected legacy reference, accepted benchmark, finite-difference check or separately qualified implementation. The scope and limitations of that oracle must be visible in the evidence.

## Minimum traceability contract

A test or bounded test subfamily is **fully registered** only when the following fields resolve on the pinned repository state:

| Field | Required meaning |
| --- | --- |
| Stable ID | Durable identifier that survives file moves where practical |
| Claim or invariant | The exact behaviour, contract or scientific property being protected |
| Test locator | Executable test path, test selector or bounded family path |
| Fixture/input | Input data, generated case, source snapshot or fixture identity |
| Oracle | Expected rule, reference result or comparison authority |
| Acceptance | Exact equality, tolerance, conservation threshold, schema rule or other decision criterion |
| Runner | Command, harness or workflow that executes the check |
| Baseline/provenance | Exact reference identity where the oracle depends on external or historical material |
| Evidence link | Qualification, admission or preservation record when the test supports an admitted claim |
| Registration status | `complete`, `partial` or `unregistered` |

`partial` means the executable test exists but one or more central traceability fields are not yet registered. It does not mean that the test is weak or failing. It means that an independent reviewer cannot reconstruct the complete claim-to-evidence chain from the central register alone.

## Current inventory status

The catalog enumerates every current top-level test surface under `tests/` on its stated inventory base, plus the two main qualification-support surfaces outside that directory.

The current capability and cross-cutting roots are registered at family level. Their central traceability status is intentionally `partial`: many tests already have local documentation or capability evidence, but the repository does not yet contain a complete per-test or bounded-subfamily mapping for every root.

This distinction is deliberate. F-TA01 closes the missing test-bank authority and inventory boundary. It does not retroactively assert complete scientific traceability for tests whose claim, fixture, oracle or evidence relation has not been centrally registered.

New or materially changed tests that support an admitted capability should not increase that debt. They should either add a complete catalog record or point from the relevant family record to a versioned local manifest containing the minimum traceability fields above.

## Baseline and oracle rules

`docs/verification/reference-baselines.md` remains the authority for the B0 -> B1 -> B2 chain. The test-bank catalog only records which tests consume that authority.

Do not change expected results merely to restore a green test. A baseline or oracle replacement requires:

1. the old and new oracle identities;
2. the reason for replacement;
3. the affected claims and tests;
4. classification of expected differences;
5. regenerated qualification or preservation evidence where the admitted claim depends on the changed oracle.

If provenance or the acceptance rule is missing, the result may still be useful as a development test, but it must not be presented as independent scientific qualification.

## Lifecycle

### Add

Register the test or bounded subfamily together with its claim, oracle and execution path. If it protects an admitted capability, link the corresponding evidence or preservation authority.

### Modify

Re-evaluate the claim, fixture, oracle and acceptance criterion. A change to test code is not automatically evidence that the protected behaviour remains qualified.

### Supersede

Keep the old stable ID visible when historical evidence refers to it. Record the successor and why the old test no longer owns the current claim.

### Retire

A test may be removed only after confirming that no current admitted claim depends solely on it. Removal of a test must not silently remove coverage from `docs/status-a/TRACEABILITY.md`.

### Dependency change

Immutable evidence remains reusable only while the dependencies that matter to its claim remain unchanged. If production semantics, the oracle, fixture, runner semantics or acceptance criterion changes materially, requalification is required for the affected claim.

## Status-A use

Status-A is not justified by test count or by a globally green test command. For each admitted claim, reviewers must be able to follow the owning contract through production implementation to qualification/admission evidence and the permanent preservation mechanism.

Use `docs/status-a/TRACEABILITY.md` for that claim-level chain. Use this test-bank authority to find and classify the permanent test surfaces involved in that chain.

A missing central registration is a documentation/traceability gap. A missing oracle or missing qualification evidence is a qualification gap. Do not collapse those two findings.

## Maintenance rule

Update `test-bank-catalog.yaml` when a top-level test surface is added, moved or retired. Update a detailed record or referenced local manifest when a test starts protecting a new admitted claim or when its oracle, fixture, runner or acceptance criterion materially changes.

The catalog should describe repository truth, including gaps. Never mark traceability `complete` merely because a directory exists or a test passes.