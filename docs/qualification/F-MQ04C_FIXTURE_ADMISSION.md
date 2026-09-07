# F-MQ04c Fixture admission bridge

Status: `PASS_ADMISSION_BRIDGE / PHYSICAL_FIXTURE_STILL_BLOCKED`

## Scope

F-MQ04c connects the fail-closed F-MQ04b reference candidate to the F-MQ03 event-fixture builder. It changes qualification infrastructure only. No SWAP production source, solver physics, numerical policy or production MultiSWAP runtime is changed.

## Admission order

`tests/multiswap/fixture_admission_bridge.py` deliberately performs qualification in this order:

1. assess the machine-readable reference candidate;
2. reject immediately when `admission_allowed` is false;
3. require the reference record to identify a real `reference_run`;
4. require `reference_run_checkpoint` extraction mode;
5. require exact equality of source commit;
6. require exact equality of qualified reference snapshot;
7. require exact equality of the source-tree manifest SHA-256;
8. only then call the existing F-MQ03 `build_fixture_from_reference_record()` builder.

This ordering is important: structural validity of a hand-created record cannot bypass the missing physical provenance of F-MQ04b.

## Current B1.10 result

The current candidate `b1.10-quiet-soil-water` remains `BLOCKED_REFERENCE_RUN_CHECKPOINT_MISSING`. Therefore the admission bridge refuses to invoke the F-MQ03 fixture builder for it.

F-MQ04c does not turn a blocked reference candidate into a qualified physical fixture and does not relax any mass, provenance or state requirement.

## Gate evidence

Local gate command:

`python3 tests/multiswap/run_fmq04c_gate.py`

Observed during construction:

- tests: 6;
- failures: 0;
- errors: 0.

The tests cover blocked-before-builder behaviour, an admitted matching shape, commit mismatch, snapshot mismatch, source-manifest mismatch and rejection of non-checkpoint extraction.

This is local qualification evidence, not a GitHub Actions CI claim.

## Architectural effect

The bridge protects the separation between:

- source qualification by VQ;
- event/run evidence acquisition;
- fixture construction and comparison by F-MQ;
- future canonical production continuation through F-CI/F-KT;
- future MultiSWAP runtime qualification through F-MR.

It directly supports invariants 2, 3, 4, 5, 7, 8, 9, 13, 23, 25, 29 and 30.

## Boundary to F-MQ04d

F-MQ04d must determine whether an exact canonical SWAP5 continuation interface is already available from F-CI/F-KT. If it is not, F-MQ04d records the required interface contract as `INTERFACE_NEEDED` rather than modifying production code from the F-MQ workstream.
