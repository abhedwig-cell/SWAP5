# SWAP-009 B1 admission checklist

The candidate dossier may be integrated before this checklist is complete. Formal B1 admission occurs only after every mandatory gate is satisfied and SWAP-009 is added to a new immutable snapshot.

| Gate | Status |
| --- | --- |
| Stable audit ID | PASS |
| B0 defect classified as implementation bug | PASS |
| Intended Kelvin sign convention established | PASS |
| Minimal four-call-site correction isolated | PASS |
| Canonical B0 target SHA pinned | PASS |
| Exact stored `fix.patch` SHA measured after upload | PASS |
| Corrected target SHA pinned | PASS |
| Existing hydraulic/theory qualification recorded | PASS |
| Exact-candidate strict Fortran PDI hydraulic function-level gate | **PASS** |
| Current repaired B1 base passes independent VQ identity/reconstruction gate | **PENDING INTEGRATION** |
| Representative full PDI production-path regression | **PENDING** |
| Hard water-balance evidence for production-path regression | **PENDING** |
| Difference ledger promoted to `ADMITTED_B1` | **PENDING** |
| New immutable B1 snapshot created | **PENDING** |

The function-level PASS is supported by the reproducible assets and machine-readable evidence under `tests/`. It compiles and executes the actual PDI conductivity route from the canonical B0 module and exact corrected target. It is not a substitute for the remaining full SWAP production-path and water-balance gates.

Current conclusion: **technically B1-eligible with targeted Fortran hydraulic gate passed, but not yet admitted**.
