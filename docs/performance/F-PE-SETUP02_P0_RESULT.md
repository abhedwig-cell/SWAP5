# F-PE-SETUP02 P0 result — scalable tile/ledger identity validation

Date: 2026-09-27

Status: `P0_PARTIAL_GAIN_GATES_FAIL`

PR:
`#678 — F-PE-SETUP02: scalable tile/ledger identity uniqueness validation`

Measured head:
`541ae97e04b277d7f9d68b68661d58828fe12bfa`

Workflow run:
`36350646567`

## Candidate

The two cumulative production-bootstrap duplicate-ID prefix scans were replaced in a research-only source copy with deterministic O(N log N) validation:

- copy the int64 identifier vector;
- merge-sort the copy;
- reject adjacent duplicates.

The input configuration and production IDs were not reordered.

## Semantic guards

Duplicate tile-id and duplicate ledger-id rejection passed for both baseline and candidate at N=1,000.

No production source was changed.

## Performance

### N=1,000

- baseline app initialize: 0.005871337 s;
- candidate: 0.005200933 s;
- candidate/baseline ratio: 0.885817;
- speedup: 1.128901x;
- no-regression gate: PASS.

### N=10,000

- baseline: 0.190978857 s;
- candidate: 0.133454951 s;
- ratio: 0.698794;
- speedup: 1.431036x;
- frozen >=2x gate: FAIL.

### N=40,000

- baseline: 3.929356414 s;
- candidate: 2.612809551 s;
- ratio: 0.664946;
- speedup: 1.503882x;
- frozen >=5x gate: FAIL.

## Interpretation

The prefix uniqueness scans are a real large-N cost, but they are not the only superlinear bootstrap mechanism.

At N=40,000 the candidate removes about 1.32 s from app initialization, roughly one third of the measured baseline cost.

Inspection of `fmr_groundwater_participant_registry_t%bind` identifies another O(N^2) path during bootstrap:

- every bind scans all registry slots for duplicate tile_id;
- every bind scans from the beginning again to find the first unused slot.

These generic registry checks repeat uniqueness and free-slot work that the production bootstrap already knows globally.

## Decision

Do not production-admit SETUP02 alone because the preregistered performance gates fail.

Retain the positive evidence and advance:

`F-PE-SETUP03 — prevalidated sequential registry-bind qualification`

The successor must:
- retain the generic registry bind path unchanged for ordinary callers;
- add a bounded bootstrap-only or explicitly prevalidated bind path;
- require global tile-ID uniqueness before using that path;
- bind the known fresh registry sequentially without duplicate/full free-slot scans;
- preserve handles, slot ownership, participant identity and all fail-closed semantics.

