# TAB-HYD live production-handoff status — 2026-09-23

Status: **research closed for generated K0 representation; production implementation active elsewhere**

This note records live delta after the research closeout. It does not modify production authority.

## Current authorities

- current canonical: `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`;
- research branch: `research/tabulated-hydraulics-characterization`;
- production implementation branch: `work/f-tab02-generated-k0-provider`;
- production branch observed head: `a93eea45b4943c8188eac2f9d7e6ce7da936884e`.

## Research disposition remains unchanged

The research line supports a generated, immutable, raw-head400, MvG-equivalent constitutive provider for the admitted K0 / SWKIMPL=0 route.

It does not admit:

- legacy generic `SWSOPHY=1`;
- arbitrary user-supplied tables;
- SWKIMPL=1 production;
- a portable whole-model speedup percentage.

## Production handoff is now active

The production work unit `F-TAB02` exists and is separately owned.

Live status at the observed production head:

- F-TAB02 A: PASS;
- B: PASS;
- C: PASS;
- D: PASS;
- E: PASS;
- G dedicated qualification: PASS;
- G same-postimage sequential A→E→G preservation replay: PASS (run `35882579159`);
- F-TAB02-G is therefore ready to be formally bound by the production owner;
- preregistered F0 provider-selection/lifetime qualification is the next permitted production step.

Research must not duplicate or bypass those production gates.

## Exact whole-Hupsel asset blocker has changed

The historical research closeout recorded the exact SWAP 4.3.1 distribution bytes as unavailable.

That statement is now stale for live handoff purposes.

The production work unit reports that the exact authorized asset has been materialized and verified:

- archive name: `SWAP_4.3.1.zip`;
- SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- size: `8,959,314 bytes`.

The final whole-Hupsel gate is therefore no longer externally blocked on asset availability. The required same-postimage A→E→G preservation replay has now passed. The next production-internal prerequisite is the preregistered F-TAB02-F0 provider-selection/lifetime seam; after that, the exact M1-C3 whole-Hupsel gate becomes the legitimate final application qualification.

## Production performance versus research performance

Research-only typed raw-head provider evidence showed larger local reductions, including about 19% provider-only cost and roughly 28–39% in a small four-node Reference-Richards fixture.

The current production implementation has independently reproduced the **sign** of the acceleration with smaller and more realistic bounded percentages.

F-TAB02-E owner run `35824004715`:

- 30-node provider: `-4.36%`;
- Reference-Richards profiles: `-12.08%` to `-17.10%`;
- serialized runtime profiles: `-4.72%` to `-9.18%`.

Confirmation run `35824244178`:

- 30-node provider: `-5.66%`;
- Reference-Richards profiles: `-15.43%` to `-17.80%`;
- serialized runtime profiles: `-5.87%` to `-8.10%`.

Interpretation:

- the acceleration survives migration into production-style ownership and validation;
- the exact research percentages are not portable;
- production evidence, not the research microbenchmark, controls eventual performance claims.

## F-SI39 / KSATEXM handoff

The research KX05/KX06 pattern has a production analogue under F-TAB02-G.

The dedicated production G rerun passed:

- constitutive branch gates;
- three-regime Reference-Richards gates;
- upper/lower serialized gates;
- neighboring unsupported profile fail-closed checks.

Final G authority is still held pending sequential same-postimage replay.

## Independent 40-node scale gate

The supplemental scale gate is now closed.

Controlling run:

`35883123788`

Independent execution-equivalent repeat:

`35883189377`

Both pass all five 40-node Reference-Richards scenarios with:

- identical nonlinear iteration counts between analytical/generated routes;
- maximum head differences no larger than about `1.38e-5 cm`;
- mass-residual differences of order `1e-15 cm`;
- material generated-provider runtime reductions in every scenario.

Record:

`TYPED_REFERENCE_RICHARDS_SCALE40_RESULT.md`

Classification:

**SCALE_PASS**

This is supplemental research evidence only. It strengthens the handoff but does
not alter F-TAB02 production authority or justify a portable whole-SWAP speedup
percentage.

## K1

K1 remains outside the production handoff.

The broader K1 route is reference-runtime blocked on difficult analytical cases and is not needed for F-TAB02 K0 admission.

## Next safe research action

1. Read scale40 rerun `35882147418`.
2. If scientifically green, record scaling characterization only.
3. If scientifically red, diagnose scaling limits without reopening the qualified K0 representation automatically.
4. Do not implement production changes from this branch.
5. Track F-TAB02 only as an external consumer of the closed research authority.


## Live delta — same-postimage A→E→G closed

Production run `35882579159` on
`work/f-tab02-generated-k0-provider@43c63185fb0455e59292c9839e46668d67424794`
completed successfully with:

- `F_TAB02_AEG_A=PASS`;
- `F_TAB02_AEG_B=PASS`;
- `F_TAB02_AEG_C=PASS`;
- `F_TAB02_AEG_D=PASS`;
- `F_TAB02_AEG_E=PASS`;
- `F_TAB02_AEG_G=PASS`;
- `F_TAB02_AEG_SEQUENTIAL_PRESERVATION=PASS`.

Selected production-style performance characterization from the same replay:

- 30-node provider delta: `-13.44%`;
- Reference-Richards coarse/loam/clay deltas: `-16.12%`, `-18.75%`, `-21.13%`;
- serialized coarse/loam/clay deltas: `-8.02%`, `-11.69%`, `-7.11%`;
- generated-state initialization median: about `3.65 ms`;
- provider break-even estimate: about `11,816` 30-node vector evaluations.

These timings remain characterization, not portable speed gates.

Research disposition remains unchanged: production ownership stays on F-TAB02; this branch only records the closed handoff and supplemental scaling evidence.


## F0 readiness after G closure

The production preregistration
`integration/f-tab/F-TAB02_F0_PREREGISTRATION.json` names only one prerequisite:
F-TAB02-G PASS.

That prerequisite is now satisfied by same-postimage sequential replay
`35882579159`.

Therefore, from the research side:

- no additional constitutive research gate is required before F0;
- F0 may proceed under its own production ownership;
- F0 remains responsible for analytical-default preservation, explicit opt-in,
  one-time immutable generated-state lifetime, deterministic invalidation,
  fail-closed unsupported neighbors, and proving no generated numerical state is
  stored in committed/transaction state;
- only after F0_1..F0_5 PASS may the exact whole-Hupsel F gate execute.

This is a handoff/readiness statement only. It does not change F0 status or
production code from the research branch.


## Live delta — F0 unlocked on production branch

After the successful A→E→G preservation replay, the production branch advanced through:

- `33a448b97330b7730d5d888e7a0ab209a73e891d` — bind dedicated and sequential G qualification pass;
- `f92ea6073ad261252cae447455f7e6b3b38c65a0` — close G and unlock F0;
- `49be47d90e407f5888e4a6858e8918b0dc7089d0` — unlock F0 implementation after G qualification.

Therefore the production work unit is no longer waiting on research or G closure before F0.

Research remains evidence-only. The next production-owned sequence is unchanged:
F0_1..F0_5 → exact whole-Hupsel F gate.


## Production handoff state after scale closure

Latest observed production status:

`IMPLEMENTATION_QUALIFIED_A_THROUGH_G__F0_READY`

Production branch head observed:

`9ad311f09e8f97fe3c8a5054ec89e34f3ade87cf`

The branch now contains the F-TAB02-F0 standalone generated-provider
selection/lifetime seam implementation. Its qualification remains owned by the
production workstream.

Research action: none unless F0 or the exact M1-C3 whole-Hupsel gate reports a
new scientific discrepancy attributable to the generated constitutive
representation.
