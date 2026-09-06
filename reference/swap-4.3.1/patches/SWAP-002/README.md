# SWAP-002 — tillage start-event indexing

Status: **QUALIFIED CANDIDATE FOR B1.10**

Legacy `set_iTill` contains an impossible interval condition comparing `t1900` with the same lower and upper bound. Runs starting after the first tillage event can therefore retain `iTill=1` even though downstream code treats `iTill` as the next event still to execute.

The isolated correction defines `iTill` as the first event on or after the simulation start. When one or more tillage events precede the start, the parameters of the most recent previous event are loaded so consolidation can continue from the supplied initial bulk density.

Exact identity:

```text
B0 / ordered B1.9 SWAP/tillage.f90
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486

fix.patch
80e12cd4e9f47c192bd6c7d5ee7d460c473b3a2b29a5a553e8c35cf0b90b5c13

corrected target
eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3
```

This patch contains only SWAP-002. It deliberately excludes SWAP-003 (`PCLAY=0` validation) and SWAP-004 (tillage type indexing/allocation).

See `finding.md`, `qualification.md` and `ADMISSION_CHECKLIST.md`.
