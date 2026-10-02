# PPA-WU05-A26 result — bounded live RFM Reference runtime

Date: 2026-10-01
Status: QUALIFIED_ADMISSION_CANDIDATE

Reconciled canonical baseline: e2d18564383e1350b0b9a68af0eaf668dac784af
Qualified source postimage: 2a77a36411ecedf3840566de1f5130322dc417fe
Equivalent no-source-change branch head after qualification: 44f4225b512fde778558b8bac7395346d6eea250
Qualification run: 36922167441
Qualification job: 110570615817
Conclusion: SUCCESS

## Qualified production envelope

The serialized Reference backend now composes the bounded RFM runtime only for:
- explicit valid RFM configuration and forcing;
- unponded, runoff-free B1.10 flux-controlled surface operation;
- Reference Richards;
- no simultaneous standard SWAP macropore execution;
- no numerical-continuation layout;
- accepted-state-frozen first-order split.

The route is:

accepted matrix/RFM state
-> B1.10 preflight
-> A13 event age
-> A11/A12 activation
-> A15 effective surface receipt
-> A17 routing
-> A26H wall hydraulic binding
-> A26J/A26K IC stored-water geometry and hydrostatic head
-> terminating IC wall release
-> A24 internal matrix source
-> Reference Richards candidate
-> RFM candidate + distinct MB deep receipt
-> A23 whole-column ledger
-> transaction owner accept/reject.

Leading fast-through MB passage has no lateral wall exchange. Its water is published as distinct deep receipt. A22B remains a standalone primitive but is not the leading production owner.

## Qualification evidence

Run 36922167441 passed:
- live-trial preparer;
- timestep-refinement oracle;
- accepted-state immutability and deterministic replay;
- unsupported head-controlled regime fail-closed;
- serialized backend O0/O2 compile/preservation;
- real Reference Richards source binding and mass-balance oracle.

Earlier failures during reconciliation were compile-harness dependency-order defects introduced by newer canonical PERCH/macropore modules. No physics parameter was changed to obtain a pass.

## Admission decision

A20's unconditional RFM NOT_ADMITTED guard is replaced only in the same postimage that invokes the qualified live preparer and A24 source seam. Unsupported combinations remain rejected.

This is an explicit first-order operator split. It is not claimed as monolithic nonlinear RFM/Richards coupling.
