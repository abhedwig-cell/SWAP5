# B1 corrected-reference snapshots

B1 is an ordered sequence of corrected SWAP 4.3.1 reference definitions. Each snapshot starts from the same byte-identified B0 source and adds only admitted, qualified bug fixes. Published snapshots are immutable.

## Snapshot history

| Snapshot | Admitted patches | Exact-oracle status | Meaning |
| --- | --- | --- | --- |
| `B1.0-bootstrap` | none | historical | exact B0, no corrections |
| `B1.1` | `SWAP-001` | historical | first corrected reference |
| `B1.2` | + `SWAP-005` | **do not use as exact oracle** | provenance mismatch found by VQ-1c |
| `B1.3` | + `SWAP-006` | **do not use as exact oracle** | provenance mismatch |
| `B1.4` | + `SWAP-007` | **do not use as exact oracle** | provenance mismatch |
| `B1.5` | + `SWAP-008` | **do not use as exact oracle** | provenance mismatch |
| `B1.5p1` | same five intended corrections | qualified predecessor | provenance repaired and targeted gates PASS |
| `B1.6` | + `SWAP-009` | qualified predecessor | PDI Kelvin-sign correction |
| `B1.7` | + `SWAP-010` | qualified predecessor | model-7 capacity-derivative correction |
| `B1.8` | + `SWAP-013` | qualified predecessor | PDI `HA/H0` input-domain guard |
| `B1.9` | + `SWAP-012` | qualified predecessor | `prhead` inverse corrected for models 3 and 5-12 |
| `B1.10` | + `SWAP-002` | qualified predecessor | tillage start-event pointer/history initialization corrected |
| `B1.11` | + `SWAP-004` | **current qualified corrected reference** | tillage type-index mapping/input consistency corrected |

The exact definitions live under `reference/swap-4.3.1/snapshots/`.

## B1.10 -> B1.11: SWAP-004

`SWAP-004` fixes an indexing/input-consistency defect in `Read_Tillage`. Legacy SWAP allocates `iTT1/iTT2` by `Ntill`, although these lookup arrays are indexed by `TYPE_TILLAGE`. A valid represented type code can therefore be greater than the number of events and index outside the arrays.

B1.11 allocates and constructs the lookup over the accepted type-code domain `1:tmax` and rejects an event type that has no corresponding `ITYPE_TILLAGE` record. The dense legacy-valid mapping remains unchanged. SWAP-003 is explicitly excluded.

Focused strict qualification:

```text
B0 sparse case: Ntill=1, TYPE_TILLAGE=[3]
result under -fcheck=all: bounds failure as expected

candidate mapping cases
  dense legacy-valid mapping unchanged        PASS
  represented type code > Ntill               PASS
  represented non-contiguous type codes       PASS
  missing ITYPE_TILLAGE record rejected       PASS
  total                                       4/4 PASS
```

Exact ordered identity:

```text
canonical B0 tillage.f90
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486

ordered B1.10 tillage.f90
 eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3

SWAP-004 fix.patch
0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818

B1.11 tillage.f90
41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede
```

Deterministic B1.11 source identity:

```text
members          63
source bytes      1,863,998
manifest SHA-256  a0f4adc5d0a126e74bfb68b33c00ba665e80b91e926d8bf356adaf97a5d304d6
```

The admitted difference is limited to tillage type-index mapping and invalid mapping rejection. No tillage constitutive equation, event timing rule, solver policy, timestep policy, water-balance equation or mass tolerance is changed. B0 supplies no standard complete tillage scenario, so B1.11 is a focused indexing/input-consistency qualification, not an exhaustive tillage-module validation.

## Current use rule

`reference/swap-4.3.1/b1-manifest.yml` points to `B1.11`. Historical B1.2-B1.5 remain audit records only; B1.5p1 through B1.10 remain immutable qualified predecessors. SWAP-003 remains unadmitted. SWAP-011 remains `PATCH_PAYLOAD_PENDING` and is not part of B1.11.
