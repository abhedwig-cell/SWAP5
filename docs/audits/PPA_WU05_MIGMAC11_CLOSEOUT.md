# PPA-WU05-MIGMAC11 closeout

Status: CLOSED  
Qualified reconciliation postimage: `609cd5ee8964f0619d94bd396f53ed9fe8d8495e`  
Final admission head: `5747aa6911095c3f0a6c917c40871be6aa9c9116`  
Canonical admission merge: `8cd14e459913f77f412e12125ccda597a841e22d`  
Reconciliation PR: #1089  
Admission PR: #1084  
Final qualification run: `37613833352`

## Admitted capability

This closeout admits the bounded B1.11 surface-to-macropore donor composition implemented by MIGMAC11:

- residual-synchronous candidate macropore area;
- ponding threshold `PndmxMp`;
- dedicated `KsMpSs` surface-to-macropore conductance;
- pond-derived lateral inflow;
- runon in the shared surface donor;
- independent direct-atmospheric macropore source ownership;
- A9 capacity limiting, redistribution and returned surface water;
- shared surface/macropore water bookkeeping;
- transaction, replay and restart semantics.

The source authority is `reference/swap-4.3.1/b1_11_frost_source/SWAP/boundtop.f90`. Runon is not a separate direct macropore source. Candidate area does not by itself activate direct rain/irrigation/melt partitioning.

## Acceptance evidence

Run `37612249809` on the current-canonical merge postimage passed the production O0/O2 compile witness and the consolidated MIGMAC11 suite. The suite demonstrated active ponding, below-threshold zero transfer, runon composition, partial capacity return, changing candidate area, exact requested/accepted/returned identities, hard whole-column mass closure, retry/rollback/replay/restart behaviour and O0/O2 identity.

The same run passed the inherited MIGMAC01-09 source/runtime envelope and MIGMAC10 bounded composition gate. The immediately preceding focused workstream qualification, run `37603291412`, also passed before canonical reconciliation.

After the later LOW03 canonical composition changed the shared serialized backend, the full MIGMAC11 gate was repeated on final admission head `5747aa6911095c3f0a6c917c40871be6aa9c9116`. Run `37613833352` passed production O0/O2 compilation, the complete focused MIGMAC11 suite, MIGMAC01-09 preservation and MIGMAC10 bounded composition. PR #1084 then merged into `integration/f-ci-canonical` as `8cd14e459913f77f412e12125ccda597a841e22d`. The only tree delta between that qualified head and the admission merge is unrelated LOW03 status documentation, so the admitted production code is the qualified production postimage.

## Canonical reconciliation

The workstream had diverged from current canonical. Delta inspection found only one overlap on the recorded MIGMAC11 production dependency surface: `src/runtime/mod_fmr_serialized_reference_backend.f90`, where canonical had admitted MICRO/root-uptake additions. PR #1089 merged current canonical cleanly into the MIGMAC11 branch. The full focused and preservation qualification then passed on the resulting two-parent postimage.

## Claim ceiling

This closeout does not claim arbitrary future macropore combinations or unrelated surface-water functionality. It admits the source-faithful B1.11 donor chain and preservation surface actually exercised above. Reopen only if a later change intersects the recorded dependency surface or a concrete regression is demonstrated.
