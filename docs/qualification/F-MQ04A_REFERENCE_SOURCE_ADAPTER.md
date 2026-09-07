# F-MQ04a Qualified reference source adapter

Status: `PASS_QUALIFICATION_ADAPTER / NO_PHYSICAL_FIXTURE_CREATED`

## Scope

F-MQ04a binds the F-MQ fixture machinery to an already-qualified VQ reference identity without duplicating the VQ admission gate and without changing production source code.

The currently consumed VQ identity is:

- repository: `abhedwig-cell/SWAP5`;
- snapshot: `B1.10`;
- VQ integration commit: `0e5c58134b225014426c75e240f0b668affbb4a1`;
- snapshot path: `reference/swap-4.3.1/snapshots/B1.10.yml`;
- snapshot Git blob: `8d768f00d47224a663941f79bb2d35eacc66d16b`;
- source-tree manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`;
- VQ reference pin: `tools/vq/cases/b1-10-reference-pin.json`;
- VQ reference-pin Git blob: `2422c3ec518afb1d9b7fbd55e869a806842161c9`;
- oracle status required by F-MQ: `QUALIFIED_NUMERICAL_BEHAVIOURAL`.

These values identify the corrected legacy reference source. They do not make B1.10 the SWAP5 production baseline. F-CI remains the authority for the canonical production baseline.

## Adapter rule

`tests/multiswap/reference_source_adapter.py` translates a VQ reference pin into the narrower source-identity fragment required by F-MQ fixtures. It intentionally does not reconstruct B1.10 and does not reimplement `b1_10_admission_gate.py`.

The adapter fails closed when:

- the VQ schema/workstream is not recognized;
- an exact 40-character commit is absent;
- the snapshot path does not match the declared snapshot;
- source or blob hashes are malformed;
- the oracle status is not qualified;
- an explicitly declared VQ boolean qualification is false;
- an explicitly declared VQ `*_gate` is not `PASS`.

The resulting fixture provenance records the source commit, snapshot, snapshot blob, source manifest, VQ pin and a canonical hash of the adapted identity.

## Qualification evidence

Local gate command:

`python3 tests/multiswap/run_fmq04a_gate.py`

Observed during construction:

- tests: 10;
- failures: 0;
- errors: 0.

This is local qualification evidence, not a GitHub Actions CI claim.

## Boundary to F-MQ04b

F-MQ04a proves that F-MQ can consume an exact qualified B1.10 source identity. It does **not** prove that a B1.10 run exists with a machine-readable committed checkpoint, short forcing continuation, unrounded mass accounting and endpoint state suitable for the F-MQ03 fixture contract.

F-MQ04b must search for and, if possible, extract exactly such a reference-run record. If that record does not exist in the qualified repository evidence, F-MQ04b must stop as `BLOCKED_REFERENCE_RUN_CHECKPOINT_MISSING` rather than manufacturing a physical fixture.

## Architecture invariants

F-MQ04a directly supports invariants 2, 3, 9, 13, 23, 25, 29 and 30. It creates qualification infrastructure only.
