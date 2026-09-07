# F-MQ04d Canonical continuation interface

Status: `INTERFACE_NEEDED_CANONICAL_PHYSICAL_CONTINUATION`

## Scope

F-MQ04d determines whether the current canonical F-CI/F-KT line already exposes enough real SWAP5 continuation semantics to generate and admit the first B1.10 event-local physical fixture. It changes qualification infrastructure only. No SWAP production source, solver physics, numerical policy or production MultiSWAP runtime is changed.

## Canonical source examined

F-MQ04d pins the current canonical integration line exactly:

- branch: `integration/f-ci-canonical`;
- commit: `376b78e975b6d4130b9ffabd223c3f87d50a9251`;
- qualified reference snapshot: `B1.10`;
- source manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`.

The machine-readable status file also pins the exact Git blob identities of:

- `integration/f-ci/F-CI04_PHYSICAL_SEAM_CONTRACT.json`;
- `integration/f-ci/F-CI04_STATUS.json`;
- `src/runtime/mod_canonical_contracts.f90`;
- `src/runtime/mod_canonical_interval_runtime.f90`.

This prevents a later moving branch head from silently changing the conclusion of F-MQ04d.

## What F-CI04 already provides

The current canonical seam already materializes important architectural prerequisites:

1. generic real-valued `[t0,t1]` interval contracts;
2. externally atomic requested intervals;
3. private cloned working state for accepted internal substeps;
4. forcing, numerical configuration and result as explicit categories;
5. worker scratch excluded from persistent-state ownership by contract;
6. deterministic transaction diagnostics at the canonical runtime level.

These are directly useful to F-MQ and align with invariants 2, 3, 5, 7, 8, 9, 23 and 29.

## Blocking gaps

The current canonical line does **not** yet provide the real physical continuation seam required by F-MQ04b/F-MQ04c:

- no concrete B1.10 implementation of `canonical_physical_model_t`;
- no qualified capture of a real B1.10 committed continuation checkpoint;
- no qualified short real B1.10 continuation over generic non-calendar `[t0,t1]`;
- no deterministic real B1.10 endpoint replay evidence;
- no complete unrounded accepted-interval mass accounting;
- no boundary-term detail sufficient to build the F-MQ hard-mass fixture record.

The last point is intentional rather than accidental: `run_canonical_interval` currently leaves `result%mass%complete = .false.` because full physical accepted-flux accounting is not yet available and fabricated zero totals are forbidden.

Therefore a real event-local B1.10 fixture must remain blocked. Legacy rounded BAL/BLC output is not substituted for this missing interface.

## Required interface contract for F-CI/F-KT

The handoff contract is recorded in `tests/multiswap/fmq04d_canonical_interface_status.json`. In functional terms F-MQ requires:

- **physical adapter**: a concrete B1.10 physical model behind the canonical model interface, with no kernel file I/O and no integer-day projection;
- **committed state**: clone/checkpoint semantics that contain all and only physical continuation state and exclude worker scratch/reconstructible solver workspace;
- **forcing**: a canonical forcing view sufficient for a short continuation interval, outside legacy parsing;
- **result**: an accepted endpoint and attributable diagnostics that can be reproduced from the same committed state;
- **mass**: complete unrounded accepted-interval storage and signed external boundary accounting, sufficient for the hard mass gate;
- **transactionality**: rejected/incomplete trials cannot mutate externally committed state and successful completion commits exactly once;
- **generic time**: the real physical path must work for non-midnight and non-day intervals.

F-MQ does not prescribe the internal state layout or solver implementation used to satisfy this contract.

## Unblock sequence

F-MQ04d may be revisited only after F-CI/F-KT has materialized and qualified the missing physical seam. Then the intended sequence is:

1. pin the new exact canonical commit;
2. capture a qualified B1.10 committed checkpoint;
3. execute a short generic physical continuation;
4. capture endpoint, diagnostics and complete unrounded mass accounting;
5. generate the F-MQ04b reference-run record;
6. pass it through the F-MQ04c admission bridge;
7. build and validate the F-MQ03 event-local fixture;
8. only then mark the first real-physics F-MQ T1 properties executable.

## Gate evidence

Repository gate command:

`python3 tests/multiswap/run_fmq04d_gate.py`

During construction, an equivalent local execution of the exact status/test content produced:

- tests: 6;
- failures: 0;
- errors: 0.

This is construction-time local evidence, not a GitHub Actions CI claim.

## Architectural assessment

No production change is justified from F-MQ04d. The correct outcome is an explicit dependency on F-CI/F-KT. This preserves the qualification-only boundary of F-MQ and directly enforces invariants 2, 3, 4, 5, 7, 8, 9, 13, 23, 25, 29 and 30.
