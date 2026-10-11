# F-TB13 reconciliation checkpoint

- phase: `RECONCILE -> QUALIFY`, pre-repository-CI checkpoint
- canonical/source branch at start: `integration/f-ci-canonical@289e64e1ba826aa7ebb42b8ae5c5a80575a223c4`
- work branch: `work/f-tb13-legacy-analytical-reference-preservation`
- corrected reference: B1.11 manifest SHA-256 `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`
- recovered framework ZIP SHA-256: `199f3d1d607255a813bb023c5741de17eacb173c2537a56bfa214ad2827b0fca`
- preserved analytical asset archive SHA-256: `57a75c64e1b057223fbd32ac3051a2c56938209f19b86912d7236f4f1d5fc069`
- fresh steady-state water replay: 12/12 PASS
- documented steady-state comparison: 12/12 PASS
- fresh Srivastava-Yeh replay: 12/12 PASS
- coarse-to-fine convergence: 4/4 PASS
- historical framework GNU vs fresh exact-B1.11 GNU preserved outputs: byte-identical
- mutations: testbank/evidence/workflow only
- exclusions: no `src/**`, no `reference/**`, no B1 mutation, no physics, solver/timestep/retry/mass-policy change
- next permitted action: open PR and require dedicated preservation CI plus repository documentation/reference CI before changing qualification state
