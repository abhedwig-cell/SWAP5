# SWAP-004 qualification evidence

Current B1 status: **QUALIFIED CANDIDATE FOR B1.11; PENDING CI/MERGE**

## Audit basis

The central issue register records SWAP-004 as a high-certainty/high-severity indexing defect: accepted `TYPE_TILLAGE` combinations can address `iTT1/iTT2` outside arrays allocated by `Ntill`. The historical technical patch allocates on `tmax` and validates that every event type has corresponding `ITYPE_TILLAGE` rows.

## Exact ordered provenance

```text
canonical B0 tillage.f90 SHA-256
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486

ordered B1.10 tillage.f90 SHA-256
eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3

stored fix.patch SHA-256
0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818

candidate tillage.f90 SHA-256
41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede
```

The ordered preimage differs from canonical B0 because SWAP-002 is already admitted in B1.10. The SWAP-004 block itself is the isolated historical indexing hunk rebased after that predecessor.

## Fresh strict qualification

GNU Fortran 14.2.0 with `-fcheck=all` reproduces the legacy defect for:

```text
Ntill = 1
TYPE_TILLAGE = [3]
ITYPE_TILLAGE = [3,3]
```

Legacy result:

```text
Fortran runtime error: Index '3' of dimension 1 of array 'itt2' above upper bound of 1
```

The corrected mapping logic was checked with four focused cases:

| Case | Expected | Result |
| --- | --- | --- |
| dense represented types within `Ntill` | mapping identical to legacy | PASS |
| represented type code greater than `Ntill` | safe lookup by type code | PASS |
| represented non-contiguous type codes | safe mapping | PASS |
| event type missing from `ITYPE_TILLAGE` | explicit rejection | PASS |

```text
SWAP-004_CANDIDATE_HARNESS PASS 4/4
SWAP-004_B0_SPARSE_BOUNDS_REPRODUCER PASS_EXPECTED_FAILURE
```

`tests/run_mapping_gate.py` binds the compilation tests to the exact stored patch SHA, canonical B0 target, ordered B1.10 preimage and candidate target hash. The dense-valid control explicitly compares old and corrected lookup positions and demonstrates unchanged mapping in that legacy-valid domain.

## Prospective B1.11 reconstruction

An independent ordered reconstruction from exact B0 through B1.10, followed by only SWAP-004, gives:

```text
members          63
source bytes      1,863,998
manifest SHA-256  a0f4adc5d0a126e74bfb68b33c00ba665e80b91e926d8bf356adaf97a5d304d6
```

The immutable prospective snapshot is `reference/swap-4.3.1/snapshots/B1.11.yml`; deterministic reconstruction is implemented in `tools/vq/b1_11_reconstruct.py`. The B1 manifest, expected-difference ledgers and fail-closed B2 handoff are repinned to B1.11 on the admission branch.

## Qualification scope

This evidence qualifies the type-index/data-consistency correction itself. B0 supplies no standard complete tillage scenario, so no claim is made for exhaustive tillage-module end-to-end coverage. Any later full tillage case must still satisfy the unchanged mass-conservation requirements.

SWAP-003 remains unqualified and excluded. The candidate does not alter physical tillage equations, event timing, solver policy, timestep logic, water-balance equations or mass tolerance.

## Remaining admission condition

The source defect, isolated correction, ordered provenance, focused compiled gate, B1.11 reconstruction, expected-difference registration, B2 repin and VQ workflow wiring are complete on the branch. Admission remains pending until both VQ reference qualification and Documentation CI pass on the pull request; merge is prohibited before both are green.
