# F-PE-ELASTIC65 — P2E05 admission reconciliation

Date: 2026-09-30

Status: PREREGISTERED_ADMISSION_RECONCILIATION

Candidate:
`work/f-pe-elastic65-mode7-csafe-binding@9a835873cafc4237c9237aca71f4a2d6412b6317`

Canonical authority:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

## Trigger

The central F-CI canonical qualification on PR #898 fails in
`tests/fci/run_fci_canonical_p2e05_moving_preservation.sh` before reaching any
ELASTIC65-owned source check.

The failure is:

`admitted dependency drift from a0fd7822...:
src/runtime/mod_a23bu_worker_execution_context.f90`.

ELASTIC65 does not change that file.

## Differential rule

Run the exact same current
`tests/fci/run_fci_canonical_p2e05_moving_preservation.sh` harness twice:

1. against the pinned current canonical production tree;
2. against the ELASTIC65 candidate production tree.

The harness itself may be copied into the canonical worktree so both trees are
judged by one identical script version.

Compare:
- exit status;
- all emitted `FCI_CANONICAL_*` and `FCI*_MOVING_*` markers;
- the terminal `FCI_CANONICAL_P2E05_PRESERVATION_FAIL` message.

Classification:

- canonical PASS, candidate FAIL: ELASTIC65 regression, admission blocked;
- canonical FAIL, candidate PASS: semantic drift, admission blocked pending
  attribution;
- both PASS with identical markers: preserved;
- both FAIL at the same dependency-drift assertion with identical markers:
  pre-existing current-canonical preservation failure, not introduced by
  ELASTIC65.

The last case does not qualify or repair P2E05 itself. It establishes only
no-regression across the ELASTIC65 production delta.

## Boundaries

This reconciliation may not:
- alter the P2E05 preservation script;
- update its frozen authorities;
- modify production source;
- weaken any dependency assertion;
- claim current-canonical P2E05 closure when canonical itself remains red.

A no-regression result may be used alongside ELASTIC65 owner qualification,
F-KT22 compile/runtime preservation, EB-I25 differential preservation and
documentation evidence when deciding bounded ELASTIC65 admission.
