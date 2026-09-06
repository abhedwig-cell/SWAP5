# SWAP-004 B1 admission checklist

Status: **QUALIFIED CANDIDATE; NOT ADMITTED**

## Defect and scope

- [x] Stable audit ID `SWAP-004`.
- [x] Legacy out-of-bounds defect reproduced with strict GNU Fortran bounds checking.
- [x] Correction isolated to tillage type-index mapping / input consistency.
- [x] SWAP-003 excluded.
- [x] No tillage physics, solver policy, timestep policy or mass-balance tolerance change.

## Exact provenance

- [x] Canonical B0 `SWAP/tillage.f90` pinned: `731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486`.
- [x] Ordered B1.10 preimage pinned: `eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3`.
- [x] Actual stored `fix.patch` SHA-256 remeasured from Git bytes: `0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818`.
- [x] Corrected target pinned: `41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede`.
- [x] Byte-safe ordered-preimage applicator stored in `apply_and_verify.py`.

## Focused qualification

- [x] B0 sparse-type reproducer fails by indexing `iTT2(3)` with extent 1.
- [x] Dense legacy-valid mapping remains unchanged.
- [x] Represented type code greater than `Ntill` is mapped safely.
- [x] Represented non-contiguous type codes are mapped safely.
- [x] Missing `ITYPE_TILLAGE` record is rejected explicitly.
- [x] Candidate harness: `4/4 PASS` under GNU Fortran 14.2.0 with `-fcheck=all`.
- [x] Repository-bound focused gate exists as `tests/run_mapping_gate.py` and binds patch/preimage/candidate identities.

## Remaining before immutable B1 admission

- [ ] Independently reconstruct prospective next corrected-reference source tree from exact B1.10 and record member count, total bytes and source-manifest SHA-256.
- [ ] Create immutable next snapshot definition only after reconstruction passes.
- [ ] Update `b1-manifest.yml` with ordered B1.10 preimage and exact stored patch identity.
- [ ] Register the narrow expected-difference envelope in both human and machine-readable ledgers.
- [ ] Repin B2 handoff to the new snapshot while retaining fail-closed status.
- [ ] Wire `run_mapping_gate.py` into VQ CI together with predecessor identity checks.
- [ ] Documentation CI PASS.
- [ ] VQ reference qualification CI PASS.
- [ ] Merge only after all gates above are green.

No full end-to-end tillage scenario is currently available in B0. Admission, if completed, therefore remains a focused indexing/input-consistency qualification and must not be described as exhaustive tillage-module validation.
