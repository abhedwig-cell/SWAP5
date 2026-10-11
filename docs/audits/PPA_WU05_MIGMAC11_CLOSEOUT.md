# PPA-WU05-MIGMAC11 closeout

Status: CLOSED AND CANONICALLY ADMITTED  
Final qualified production postimage: `5747aa6911095c3f0a6c917c40871be6aa9c9116`  
Latest intersecting canonical parent: `d395ca3decf03e7149dbf8d65dc9ad8946826f3a`  
Canonical reconciliation PR: #1092  
Final qualification run: `37613833352`  
Admission PR: #1084  
Canonical admission commit: `8cd14e459913f77f412e12125ccda597a841e22d`

## Admitted capability

MIGMAC11 closes the bounded B1.11 surface-to-macropore donor chain:

- candidate macropore area is evaluated residual-synchronously;
- `PndmxMp` and dedicated `KsMpSs` govern pond-derived lateral inflow;
- runon remains part of the shared surface donor and is not a direct macropore source;
- direct rain, irrigation and melt are area-partitioned only when the independent direct macropore top source is actually active;
- A9 limits and redistributes the requested receipt and returns capacity-rejected water to the same surface donor;
- pond-specific requested, accepted and returned amounts are kept separate from external direct top inflow in the transaction ledger;
- accepted pond transfer is an internal surface-to-macropore redistribution, not a second external water input.

The source authority is `reference/swap-4.3.1/b1_11_frost_source/SWAP/boundtop.f90`.

## Final qualification

Run `37613833352` passed on `5747aa6911095c3f0a6c917c40871be6aa9c9116` after reconciliation with canonical LOW3 changes. All workflow stages passed:

- production runtime compilation at O0 and O2;
- active pond receipt above threshold;
- paired runon case, with runon increasing the shared pond donor without direct runon macropore booking;
- below-threshold/no-pond zero receipt;
- partial A9 capacity acceptance with positive returned surface water;
- expanding and shrinking candidate-area cases;
- `requested = accepted + returned`;
- net surface debit from pond transfer equals accepted pond-derived macropore inflow;
- hard whole-column mass closure;
- reject/smaller-retry identity;
- rollback/replay identity;
- restart continuation equivalence;
- MIGMAC01-09 source/runtime preservation;
- MIGMAC10 bounded Boesten/Rutter/macropore preservation;
- O0/O2 identity.

The preceding focused qualification run `37603291412` and first canonical-merge qualification run `37612249809` also passed and remain supporting evidence.

## Canonical admission

PR #1084 was admitted as canonical merge `8cd14e459913f77f412e12125ccda597a841e22d`.

The exact delta from the final qualified production head `5747aa6911095c3f0a6c917c40871be6aa9c9116` to that canonical admission consists only of `integration/audits/SW431_LOW3_EXPLICIT_STATUS.md`. No production file, test owner, or recorded MIGMAC11 dependency changed. The final qualification therefore transfers directly to the canonical admission postimage under the repository's dependency-aware preservation rule.\n\nAs an additional exact-postimage check, run `37615105739` reran the complete MIGMAC11 workflow directly on canonical admission commit `8cd14e459913f77f412e12125ccda597a841e22d`. Production compile, the focused MIGMAC11 suite, MIGMAC01-09 preservation and MIGMAC10 bounded composition all passed.

## Claim ceiling

This closure admits the source-faithful B1.11 surface/macropore donor chain and the preservation envelope explicitly exercised above. It does not widen unrelated macropore, surface-water or forcing capabilities.

Reopen MIGMAC11 only when a later canonical change intersects the recorded dependency surface or concrete regression evidence appears.
