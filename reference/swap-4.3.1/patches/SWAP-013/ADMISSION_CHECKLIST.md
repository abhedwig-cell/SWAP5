# SWAP-013 B1 admission checklist

| Gate | Status |
| --- | --- |
| Stable audit ID | PASS |
| Defect classified as implementation/input-domain bug | PASS |
| Minimal relational guard isolated | PASS |
| Canonical B0 `readswap.f90` SHA pinned | PASS |
| Ordered B1.7 preimage identity checked | PASS |
| Exact stored `fix.patch` SHA pinned | PASS |
| Corrected target SHA pinned | PASS |
| Guard located after H0/HA magnitude conversion | PASS |
| Guard restricted to PDI models 8–11 | PASS |
| Valid PDI values accepted in focused compiled gate | PASS |
| HA=0 rejected in focused compiled gate | PASS |
| HA=H0 rejected in focused compiled gate | PASS |
| HA>H0 rejected in focused compiled gate | PASS |
| Non-PDI controls unaffected by guard | PASS |
| Historical patch compile/hydraulic evidence retained | PASS |
| Expected-difference scope registered | PASS |
| New immutable B1 snapshot | PASS |
| Deterministic B1.8 source identity pinned | PASS |
| Fail-closed B1.8 CI identity/admission gate | REQUIRED BEFORE MERGE |

No physical equation, solver policy or mass tolerance is changed. The expected B1 difference is limited to earlier rejection of mathematically singular/invalid PDI input combinations.

Current conclusion: **SWAP-013 is admitted as the eighth corrected-reference patch in immutable snapshot B1.8.** This conclusion becomes integrated repository state only after the B1.8 pull request passes the fail-closed CI gates and is merged to `main`.
