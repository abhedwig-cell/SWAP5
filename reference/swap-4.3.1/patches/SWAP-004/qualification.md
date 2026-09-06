# SWAP-004 qualification evidence

Current B1 status: **QUALIFIED CANDIDATE; NOT ADMITTED**

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

The ordered preimage differs from canonical B0 only because SWAP-002 is already admitted in B1.10. The SWAP-004 block itself is otherwise the historical isolated indexing hunk.

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

The corrected mapping logic was then checked with four focused cases:

| Case | Expected | Result |
| --- | --- | --- |
| dense represented types within `Ntill` | mapping identical to legacy | PASS |
| represented type code greater than `Ntill` | safe lookup by type code | PASS |
| represented non-contiguous type codes | safe mapping | PASS |
| event type missing from `ITYPE_TILLAGE` | explicit rejection | PASS |

```text
SWAP-004_CANDIDATE_HARNESS PASS 4/4
```

The dense-valid control explicitly compares old and corrected lookup positions and shows no mapping change for that legacy-valid domain.

## Qualification scope

This evidence qualifies the type-index/data-consistency correction itself. B0 supplies no standard complete tillage scenario, so no claim is made here for exhaustive tillage-module end-to-end coverage. Any later full tillage case must still satisfy the unchanged mass-conservation requirements.

SWAP-003 remains unqualified and excluded. The candidate does not alter physical tillage equations, solver policy, timestep logic or mass tolerance.

## Admission still pending

Before immutable B1 admission, the candidate still needs a repository-bound reproducible gate, independent next-snapshot source reconstruction/identity, expected-difference registration, B2 repin and green VQ/Documentation CI.
