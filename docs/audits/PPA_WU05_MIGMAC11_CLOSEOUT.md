# PPA-WU05-MIGMAC11 closeout

Status: CLOSED  
Qualified postimage: `5747aa6911095c3f0a6c917c40871be6aa9c9116`  
Canonical parent: `d395ca3decf03e7149dbf8d65dc9ad8946826f3a`  
Reconciliation PR: #1089  
Latest qualification run: `37613833352`

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

Run `37613833352` on the latest current-canonical merge postimage passed the production O0/O2 compile witness and the consolidated MIGMAC11 suite. The suite demonstrated active ponding, below-threshold zero transfer, runon composition, partial capacity return, changing candidate area, exact requested/accepted/returned identities, hard whole-column mass closure, retry/rollback/replay/restart behaviour and O0/O2 identity.

The same run passed the inherited MIGMAC01-09 source/runtime envelope and MIGMAC10 bounded composition gate. Earlier successful gates include focused workstream run `37603291412` and canonical-postimage run `37612673865`; the latest run supersedes them for current-head closure.

## Canonical reconciliation

The workstream had diverged from current canonical. Delta inspection found only one overlap on the recorded MIGMAC11 production dependency surface: `src/runtime/mod_fmr_serialized_reference_backend.f90`, where canonical had admitted MICRO/root-uptake additions. PR #1089 merged current canonical cleanly into the MIGMAC11 branch. A later canonical LOW03/Cauchy admission again intersected the shared serialized backend; that newer canonical was reconciled into the branch at `5747aa6911095c3f0a6c917c40871be6aa9c9116`. The full focused and preservation qualification then passed again on run `37613833352`.

## Claim ceiling

This closeout does not claim arbitrary future macropore combinations or unrelated surface-water functionality. It admits the source-faithful B1.11 donor chain and preservation surface actually exercised above. Reopen only if a later change intersects the recorded dependency surface or a concrete regression is demonstrated.
