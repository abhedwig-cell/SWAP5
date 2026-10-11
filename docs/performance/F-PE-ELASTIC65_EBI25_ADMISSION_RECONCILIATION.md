# F-PE-ELASTIC65 — EB-I25 admission reconciliation

Date: 2026-09-30

Status: PREREGISTERED_ADMISSION_RECONCILIATION

Candidate:
`work/f-pe-elastic65-mode7-csafe-binding@9d4db7243f6f43e2ebf5ffeff91384882f184b13`

Canonical authority:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

## Trigger

The F-KT22 current-canonical EB-I25 preservation gate became executable after
closing its transitive compile dependencies. It then failed at the assertion:

`external full-half outflow fixture rejected before commit`.

The preceding EB-I25 markers passed.

This failure occurs in an EB-I25 fixture configured with
`TX_TEMPORAL_EXTERNAL_FULL_HALF`.

ELASTIC65 changes only the mode-7 normalization used by the
`TX_TEMPORAL_MODEL_CERTIFICATE` path. It does not change the external
full-half controller contract.

Therefore this gate must be classified by same-harness baseline comparison
before it can be used as ELASTIC65 regression evidence.

## Differential rule

Run the exact same repaired
`tests/fkt/run_fkt22_eb_i25_preservation_gate.sh` twice:

1. against the pinned canonical production tree;
2. against the ELASTIC65 candidate production tree.

The repaired harness itself may be copied into the canonical worktree so both
runs use the same compile dependency closure. No canonical production source is
modified.

Compare:
- process exit status;
- all emitted `EB_I25_*` semantic markers.

Classification:

- canonical PASS, candidate FAIL: ELASTIC65 regression, admission blocked;
- canonical FAIL, candidate PASS: semantic drift, admission blocked pending
  explicit attribution;
- both PASS with identical semantic markers: preserved;
- both FAIL with identical semantic markers and identical failure assertion:
  pre-existing current-canonical preservation failure, not introduced by
  ELASTIC65.

The last case does not qualify EB-I25 itself. It only establishes
no-regression across the ELASTIC65 production delta.

## Boundaries

This reconciliation may not:
- weaken or remove the EB-I25 test assertion;
- edit production source;
- alter temporal or mass tolerances;
- reinterpret an external full-half test as a mode-7 certificate test;
- claim EB-I25 closure if canonical itself remains red.

A green differential permits ELASTIC65 admission only if its own qualification,
F-KT22 production compile/runtime/canonical-boundary gates, documentation, and
other directly relevant owner gates remain green.
