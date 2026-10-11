# SWAP-012 B1 admission checklist

| Gate | Status |
| --- | --- |
| Stable audit ID | PASS |
| Defect classified as implementation/algorithm bug | PASS |
| SWAP-012 isolated from historical SWAP-011 content | PASS |
| Canonical B0 `MOD_MvG_functions.f90` SHA pinned | PASS |
| Ordered B1.8 preimage identity checked | PASS |
| Exact stored `fix.patch` SHA pinned | PASS |
| Corrected target SHA pinned | PASS |
| D2 broad 22,240-point inverse qualification retained | PASS |
| Fresh actual-source 600-point roundtrip gate retained | PASS |
| Model 4 analytical control unaffected | PASS |
| SWAP-011 `dhconduc` content excluded | PASS |
| Expected-difference scope registered | PASS IN B1.9 BOOKKEEPING |
| New immutable B1 snapshot | PASS: B1.9 |
| Deterministic B1.9 source identity pinned | PASS |
| Fail-closed B1.9 CI identity/admission gate | REQUIRED BEFORE MERGE |
| B2 handoff repinned without weakening admission contract | REQUIRED BEFORE MERGE |

No retention formula, conductivity formula, Richards residual/Jacobian, solver policy or mass tolerance is changed by SWAP-012. The admitted behaviour change is limited to `prhead` returning the inverse of the selected retention relation for models 3 and 5-12.

Current conclusion: **SWAP-012 is prepared for admission as the ninth corrected-reference patch in immutable snapshot B1.9.** It becomes integrated repository state only after the B1.9 pull request passes fail-closed CI and is merged to `main`.
