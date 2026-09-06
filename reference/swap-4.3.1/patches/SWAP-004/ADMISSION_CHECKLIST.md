# SWAP-004 B1 admission checklist

Status: **QUALIFIED CANDIDATE FOR B1.11; PENDING CI/MERGE**

## Defect and scope

- [x] Stable audit ID `SWAP-004`.
- [x] Legacy out-of-bounds defect reproduced with strict GNU Fortran bounds checking.
- [x] Correction isolated to tillage type-index mapping / input consistency.
- [x] SWAP-003 excluded.
- [x] No tillage physics, solver policy, timestep policy, water-balance equation or mass-balance tolerance change.

## Exact provenance

- [x] Canonical B0 `SWAP/tillage.f90` pinned: `731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486`.
- [x] Ordered B1.10 preimage pinned: `eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3`.
- [x] Actual stored `fix.patch` SHA-256: `0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818`.
- [x] Corrected target pinned: `41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede`.
- [x] Byte-safe ordered-preimage applicator stored in `apply_and_verify.py`.

## Focused qualification

- [x] B0 sparse-type reproducer fails by indexing `iTT2(3)` with extent 1.
- [x] Dense legacy-valid mapping remains unchanged.
- [x] Represented type code greater than `Ntill` is mapped safely.
- [x] Represented non-contiguous type codes are mapped safely.
- [x] Missing `ITYPE_TILLAGE` record is rejected explicitly.
- [x] Candidate harness: `4/4 PASS` under GNU Fortran 14.2.0 with `-fcheck=all`.
- [x] Repository-bound focused gate `tests/run_mapping_gate.py` binds patch/preimage/candidate identities.

## B1.11 integration preparation

- [x] Independently reconstructed prospective B1.11 from exact B1.10.
- [x] Prospective source identity: 63 members, 1,863,998 bytes, manifest `a0f4adc5d0a126e74bfb68b33c00ba665e80b91e926d8bf356adaf97a5d304d6`.
- [x] Immutable `reference/swap-4.3.1/snapshots/B1.11.yml` created.
- [x] Deterministic `tools/vq/b1_11_reconstruct.py` created.
- [x] `b1-manifest.yml` advanced with canonical B0 plus ordered B1.10 preimage identity.
- [x] Human and machine-readable expected-difference ledgers updated.
- [x] B2 handoff repinned to B1.11 while retaining fail-closed status.
- [x] `run_mapping_gate.py` wired into VQ CI with B1.10 predecessor identity and B1.11 admission gate.
- [x] Current `main` staging merge incorporated without changing candidate content.
- [ ] Documentation CI PASS.
- [ ] VQ reference qualification CI PASS.
- [ ] Merge only after both CI gates are green.

No full end-to-end tillage scenario is currently available in B0. B1.11 admission therefore remains a focused indexing/input-consistency qualification and must not be described as exhaustive tillage-module validation.
