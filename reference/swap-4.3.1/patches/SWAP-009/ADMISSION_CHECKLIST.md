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
| Representative full PDI production-path regression | **PASS** |
| Hard water-balance evidence for production-path regression | **PASS** |
| Difference ledger promoted to `ADMITTED_B1` | **PENDING** |
| New immutable B1 snapshot created | **PENDING** |

The function-level PASS compiles and executes the actual PDI conductivity route from the canonical B0 module and exact corrected target.

The full-production PASS uses a reproducible two-day model-8 PDI case derived from the supplied official grass-growth case, with normal layer Ksat values, `SWVAPOR=1`, uniform `h=-1e5 cm`, zero bottom flux and `ETref=5 mm/d`. Both standard B0/candidate runs complete normally and follow the same 57 x 2-iteration Newton route. High-precision output-only diagnostics expose expected state/flux differences while leaving the solver route unchanged.

The predeclared unrounded legacy mass criterion is `1e-6 cm`. Maximum absolute combined ponding + profile residuals are `3.5598002490e-8 cm` for B0 and `3.5598034465e-8 cm` for the candidate; no `.dwb` deviation file is produced. This is adequate as the hard mass gate for this legacy B1 qualification case, but does not replace the future transaction-aware B2/VQ mass-accounting contract.

Reproducible assets and machine-readable evidence are under `tests/full-production/`.

Current conclusion: **the SWAP-009 technical, function-level, full-production and mass-balance gates pass; formal B1 admission remains blocked only on integration/acceptance of the repaired B1.5p1 VQ identity/reconstruction base and subsequent corrected-reference bookkeeping.**
