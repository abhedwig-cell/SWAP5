# F-PE19 — B1.11 CI reconciliation

Date: 2026-09-16

Status: `RECONCILE_PASS / CI_GATE_UPDATE_APPLIED`

## Trigger

PR #159 correctly advances the current corrected reference from B1.10 to B1.11. The existing `VQ reference qualification` workflow still invoked `tools/vq/b1_10_admission_gate.py`, whose contract requires `b1-manifest.yml` itself to remain current at B1.10. On a valid B1.11 admission that historical-current-state assertion becomes false by construction.

The failed workflow run `35096488461` therefore does **not** contradict the SWAP-011 qualification or the exact B0 -> B1.11 replay. Its failing checks were the expected stale-current-state assertions: current manifest snapshot/definition, current manifest patch order/identity, and current manifest source-tree identity for B1.10. The pinned immutable B1.10 snapshot identity itself still passed.

## Reconciliation decision

Keep `b1_10_admission_gate.py` as the historical B1.10 admission gate. Do not weaken or reinterpret its original contract.

The current-reference workflow now:

1. verifies immutable B1.10 directly with `b1_snapshot_identity.py --pin tools/vq/cases/b1-10-reference-pin.json`;
2. verifies the new current B1.11 decision surface with `b1_11_admission_gate.py`;
3. retains the SWAP-012 inverse regression, SWAP-002 compiled tillage regression and existing VQ unit tests;
4. syntax-checks the B1.11 reconstructor and byte-safe SWAP-011 applicator.

The B1.11 static gate is fail-closed over the exact ordered patch SHA, canonical B0 and ordered target identities, frozen 63-member source manifest, full-replay evidence, expected-difference registry, human ledger and reconstruction/applicator pins. It does not pretend to rerun the external full-distribution replay in CI.

## Scope

This is verification/governance infrastructure only. It changes no SWAP5 production source, scientific formulation, solver policy, time-step policy or mass tolerance.

Next permitted action: run PR CI. Merge and issue #12 closure remain prohibited unless the updated current-reference gate and canonical qualification checks pass.
