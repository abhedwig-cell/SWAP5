# PPA-WU05-MIGMAC11 closeout

Status: CLOSED  
Admitted canonical postimage: `8cd14e459913f77f412e12125ccda597a841e22d`  
Final canonical qualification run: `37615105739`  
Admission PR: #1084  
Canonical reconciliation PR: #1089

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

Run `37615105739` executed the complete MIGMAC11 workflow on the admitted canonical commit `8cd14e459913f77f412e12125ccda597a841e22d`. All four required gates passed:

- production O0/O2 compile witness;
- consolidated MIGMAC11 focused qualification suite;
- MIGMAC01-09 source/runtime preservation;
- MIGMAC10 bounded composition preservation.

The focused suite covers active ponding, below-threshold zero transfer, runon composition, partial A9 capacity acceptance and return, expanding and shrinking candidate area, requested/accepted/returned identities, exact surface debit versus accepted pond-derived inflow, hard whole-column mass closure, reject/smaller-retry, rollback/replay, restart continuation and O0/O2 identity.

Earlier run `37612249809` passed the same gate set on merge-postimage `609cd5ee8964f0619d94bd396f53ed9fe8d8495e`; run `37603291412` passed the focused workstream qualification before canonical reconciliation.

## Final canonical reconciliation

The original closeout recorded `609cd5ee8964f0619d94bd396f53ed9fe8d8495e` as the qualified canonical merge postimage. Before PR #1084 was finally admitted, later composition work entered the workstream lineage and changed `src/runtime/mod_fmr_serialized_reference_backend.f90` and `src/runtime/mod_fmr_production_application_bootstrap.f90`. The serialized backend is part of the recorded MIGMAC11 dependency surface, so inheritance of the earlier qualification was not sufficient.

The lean qualification branch was therefore fast-forwarded to the exact admitted canonical commit `8cd14e459913f77f412e12125ccda597a841e22d`. Run `37615105739` then reran the full production compile, focused MIGMAC11 suite and MIGMAC01-10 preservation gates successfully. This is the controlling closure evidence.

The earlier F-CI96/FROSS22 dependency-hash failure is not used as MIGMAC11 physics evidence. MIGMAC11 closure rests on the dedicated current-canonical workflow above.

## Claim ceiling

This closeout does not claim arbitrary future macropore combinations or unrelated surface-water functionality. It admits the source-faithful B1.11 donor chain and preservation surface actually exercised above. Reopen only if a later change intersects the recorded dependency surface or a concrete regression is demonstrated.
