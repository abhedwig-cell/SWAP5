# SWAP-004 — tillage type-index mapping

Status: **QUALIFIED CANDIDATE; NOT ADMITTED TO B1**

`TYPE_TILLAGE` is used as an index into `iTT1/iTT2`. Legacy SWAP 4.3.1 sizes those arrays by the number of tillage events (`Ntill`) rather than the maximum accepted type code (`tmax`). A legal input shape can therefore index outside the arrays.

The isolated candidate allocates the lookup arrays by `tmax`, constructs mappings over all accepted type codes, and rejects an event type for which no corresponding `ITYPE_TILLAGE` row exists.

This patch is ordered after B1.10 because `tillage.f90` is already changed there by SWAP-002.

Exact candidate identity:

```text
canonical B0 tillage.f90
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486

ordered B1.10 preimage
eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3

fix.patch
0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818

candidate target
41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede
```

SWAP-003 is explicitly excluded. No tillage physics, solver policy, time integration or mass-balance tolerance is changed.

See `finding.md`, `qualification.md` and `tests/`.
