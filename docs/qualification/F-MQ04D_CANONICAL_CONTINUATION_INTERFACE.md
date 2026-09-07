# F-MQ04d Canonical continuation interface

Status: `INTERFACE_NEEDED_CANONICAL_PHYSICAL_CONTINUATION`

## Scope

F-MQ04d determines whether the current canonical F-CI/F-KT line already exposes enough real SWAP5 continuation semantics to generate and admit the first B1.10 event-local physical fixture. It changes qualification infrastructure only. No SWAP production source, solver physics, numerical policy or production MultiSWAP runtime is changed.

## Canonical source examined

F-MQ04d pins the current canonical integration line exactly:

- branch: `integration/f-ci-canonical`;
- commit: `539b8c1b942d5c2dc8f97b8b7f400b2c3a1da0aa`;
- latest work unit at that pin: `F-CI05`;
- qualified reference snapshot: `B1.10`;
- B1.10 source manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`.

The machine-readable status file pins the exact Git blob identities of the F-CI04 runtime contract, F-CI05 physical-preimage evidence and the canonical runtime source files. This prevents a later moving branch head from silently changing the conclusion of F-MQ04d.

## What F-CI04/F-CI05 already provide

The current canonical line now materializes two distinct layers of useful evidence.

F-CI04 provides:

1. generic real-valued `[t0,t1]` interval contracts;
2. externally atomic requested intervals;
3. private cloned working state for accepted internal substeps;
4. forcing, numerical configuration and result as explicit categories;
5. worker scratch excluded from persistent-state ownership by contract;
6. deterministic transaction diagnostics at the canonical runtime level.

F-CI05 additionally provides:

7. an exact admitted B1.10 physical source preimage;
8. an archive-capable admission gate for that source;
9. exact seam-file hashes for the legacy physical source;
10. evidence that the qualified B1.10 patch chain does not alter those seam files.

This is a meaningful advance: the physical source to be ported is now exact and reproducible. It is still a preimage, not yet a canonical continuation adapter.

## Blocking gaps

F-CI05 explicitly keeps `canonical_b1_10_physical_adapter = false` and `adapter_admission = BLOCKED`. The remaining blockers include legacy module-global continuation state, HeadCalc saved numerical scratch/history, trial-time output side effects, legacy forcing coupled to meteo/file state, a single-day DLL weather path, missing accepted unrounded physical mass totals, and unqualified scheduled-irrigation/crop continuation for generic intervals.

Therefore the current canonical line still does **not** provide the real physical continuation seam required by F-MQ04b/F-MQ04c:

- no concrete B1.10 implementation of `canonical_physical_model_t`;
- no qualified capture of a real B1.10 committed continuation checkpoint;
- no qualified short real B1.10 continuation over generic non-calendar `[t0,t1]`;
- no deterministic real B1.10 endpoint replay evidence;
- no complete unrounded accepted-interval mass accounting;
- no boundary-term detail sufficient to build the F-MQ hard-mass fixture record.

The mass gap is intentional rather than accidental: the F-CI04 runtime leaves `result%mass%complete = .false.` instead of fabricating physical totals that the seam cannot yet provide.

Therefore a real event-local B1.10 fixture must remain blocked. Legacy rounded BAL/BLC output is not substituted for this missing interface.

## Required interface contract for F-CI/F-KT

The handoff contract is recorded in `tests/multiswap/fmq04d_canonical_interface_status.json`. In functional terms F-MQ requires:

- **physical adapter**: a concrete B1.10 physical model behind the canonical model interface, built from the F-CI05 qualified preimage, with no kernel file I/O and no integer-day projection;
- **committed state**: clone/checkpoint semantics that contain all and only physical continuation state and exclude worker scratch/reconstructible solver workspace;
- **forcing**: a canonical forcing view sufficient for a short continuation interval, outside legacy parsing;
- **result**: an accepted endpoint and attributable diagnostics that can be reproduced from the same committed state;
- **mass**: complete unrounded accepted-interval storage and signed external boundary accounting, sufficient for the hard mass gate;
- **transactionality**: rejected/incomplete trials cannot mutate externally committed state and successful completion commits exactly once;
- **generic time**: the real physical path must work for non-midnight and non-day intervals.

F-MQ does not prescribe the internal state layout or solver implementation used to satisfy this contract.

## Unblock sequence

F-MQ04d may be revisited only after F-CI/F-KT has completed a controlled source port from the F-CI05 preimage and qualified the missing physical seam. Then the intended sequence is:

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

The gate validates the exact F-CI05 pin, the admitted preimage capability and the fail-closed rule that any missing critical physical capability keeps fixture admission disabled.

Construction-time execution of the refreshed status/test content produced:

- tests: 6;
- failures: 0;
- errors: 0.

This is construction-time local evidence, not a GitHub Actions CI claim.

## Architectural assessment

No production change is justified from F-MQ04d. The correct outcome remains an explicit dependency on F-CI/F-KT, but the dependency is now narrower: source identity is solved by F-CI05; the controlled physical source port, state ownership and unrounded accepted mass seam remain open. This preserves the qualification-only boundary of F-MQ and directly enforces invariants 2, 3, 4, 5, 7, 8, 9, 13, 23, 25, 29 and 30.
