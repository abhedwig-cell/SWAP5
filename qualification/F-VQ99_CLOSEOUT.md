# F-VQ99 closeout — SWAP 4.3.1 ↔ SWAP5 Status-A scientific equivalence

Date: 2026-09-16
Protocol: `RECONCILE -> QUALIFY -> CLOSE`
Workunit type: verification/evidence only

## Authorities

- SWAP5 Status-A authority used by the campaign: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- SWAP5 scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- SWAP5 scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- qualification branch: `qualification/f-vq99-swap431-swap5-status-a-equivalence`
- repaired qualification postimage: `b6c2e8aea50677ea87fc9a64b3d35dfb34adb1fa`
- successful qualification workflow: run `35042471677`
- workflow evidence artifact: `f-vq99-equivalence-evidence`, artifact `10426355111`, digest `sha256:d572b5384e65b027a32184786b4d5af3b0c92c6897a1f4d6180d5c81de2e3a6e`

The later documentation-only canonical merge `523da7aa6032c12c3431b1180950ff0d15186be9` does not replace the scientific production authority above. Its admitted delta contains no production or reference source change.

## RECONCILE

The authoritative reference interpretation is triangular:

`B0 immutable SWAP 4.3.1 -> B1.10 qualified corrected reference -> SWAP5 Status-A scientific production baseline`.

B0 to B1.10 differences are explanatory only where an admitted patch authority establishes them. An unexplained B1.10 to SWAP5 difference remains a qualification failure.

The bounded comparison matrix and predefined tolerances are recorded in `qualification/F-VQ99_RECONCILE_CHECKPOINT.json`. Dedicated WOFOST 8.1 comparison, EB, ROSS/RossFast, new physics, production optimization and API/IO redesign are excluded from this campaign.

A parallel branch, `qualification/f-vq99-swap431-swap5-status-a-scientific-equivalence`, was found during reconciliation. Its workflow run `35041280139` failed and it is not used as F-VQ99 qualification authority. No third replacement branch was created.

## QUALIFY

The first green workflow postimage was inspected adversarially rather than accepted from CI colour alone. The artifact from run `35041241754` exposed a fatal Fortran compilation error in the Richards replay while the wrapper still returned zero. That run is therefore not accepted as scientific evidence.

The qualification harness was then repaired on commit `b6c2e8aea50677ea87fc9a64b3d35dfb34adb1fa` by closing the current-tree compile dependency surface without changing SWAP5 production or reference source. Run `35042471677` succeeded and its artifact was inspected.

### EQ-RICHARDS-15

The repaired evidence records:

- exact scientific production commit/tree identity;
- the frozen B1.10-derived 15-case matrix;
- all 15 cases PASS under `-O0`;
- all 15 cases PASS under `-O2`;
- `FCI21_SI25_O0_O2_IDENTITY=PASS`;
- `FCI21_SI25_OWNER_REPLAY_CASES=15`;
- `FCI21_SI25_OWNER_REPLAY_MAX_ABS_DIFF=0.00000000000000000e+00` for the compared owner/production defect metrics;
- `FCI21_SI25_OWNER_REPLAY=PASS`;
- `FCI21_SI25_SCIENTIFIC_REPLAY PASS`.

Verdict for this bounded seam: **equivalence established for the compared Richards oracle metrics and cases**. This is not a claim of whole-model trajectory identity.

### EQ-ET-DEMAND

The repaired evidence records PASS for:

- protected owner/source locks;
- process boundary and statelessness;
- O0 and O2 executions;
- O0/O2 output identity;
- B1.10 reference ET equations;
- surface-demand `vcover` semantics;
- inactive-crop dependency semantics;
- boundary cases;
- fail-closed invalid inputs;
- stateless A-B-A identity.

Verdict for this bounded seam: **equivalence established within the admitted reference ET-demand contract exercised by the frozen gate**.

### Broad end-to-end trajectory

`EQ-FULL-HUPSEL-LONG` remains blocked. The qualification runner reports:

- exact B0 source archive bytes: absent at `reference/swap-4.3.1/b0/SWAP_4.3.1.zip`;
- authoritative Hupsel case directory: absent at `reference/swap-4.3.1/cases/Hupsel`;
- B1.10 deterministic reconstructor: present.

The campaign therefore does not substitute reconstructed, guessed or non-authoritative external assets and does not manufacture a global equivalence verdict from process-level seams.

### Restart continuation

`EQ-RESTART-CONTINUATION` remains blocked because a directly comparable B1.10 persisted-state fixture with equivalent restart semantics has not been established. SWAP5 lifecycle/restart additions are not silently mapped onto a non-equivalent SWAP 4.3.1 restart representation.

## Scientific claim boundary

What is established:

- selected repository-resident B1.10-derived Richards reference-seam equivalence on the frozen 15-case matrix;
- selected B1.10 reference ET-demand equivalence within the frozen process contract;
- exact authority/provenance binding to the Status-A scientific production tree.

What is not established by F-VQ99:

- whole-model SWAP 4.3.1 ↔ SWAP5 trajectory equivalence;
- long Hupsel trajectory equivalence;
- cross-model restart equivalence;
- dedicated WOFOST 8.1 potential-production equivalence;
- equivalence for excluded future capabilities.

The dedicated WOFOST potential-production workstream remains separate from F-VQ99 and must be cited on its own evidence, not folded into this verdict.

## Mutations

- SWAP5 production source: **NONE**
- SWAP 4.3.1 source: **NONE**
- reference physics: **NONE**
- qualification harness/evidence only: **YES**

## CLOSE verdict

`SWAP431_SWAP5_STATUS_A_EQUIVALENCE_NOT_YET_ESTABLISHED`

This is a fail-closed global verdict, not a negative scientific finding. The available evidence establishes strong bounded equivalence at the qualified Richards and ET-demand seams, but the campaign lacks the exact immutable assets needed for the declared broad end-to-end trajectory comparison and lacks a semantically comparable legacy restart fixture.

## Next permitted action

Only one of the following materially advances the global verdict:

1. supply or repository-pin the exact immutable B0 distribution/source archive and authoritative Hupsel fixture already identity-defined by the campaign, then execute the frozen long-trajectory comparison without changing tolerances; or
2. establish an immutable B1.10 restart/persisted-state fixture with demonstrably equivalent semantics, then run the bounded restart comparison.

Do not modify production source merely to obtain agreement. Do not widen tolerances after observing results. Do not reopen unrelated Status-A capabilities without dependency evidence.