# F-TB10 runlog

## Purpose

F-TB10 attempted the bounded interaction catalogued as `SWAP5-TB09-DRAIN-BOTTOM-003-v1` without changing production source. The target was the admitted serialized positive single-level DIVDRA runtime combined with a current-canonical reference Full Richards column and a changing prescribed-head lower boundary.

The scientific target has **not** been qualified. F-TB10 closes fail-closed as a blocked assessment because the current admitted numerical-policy chain does not provide a governed temporal-acceptance policy/provenance for this genuine nonstationary standalone/integrated interaction.

## Frozen authorities

- current-canonical composition base: `eba90d79010b095b6556e93bd8b77a8c28d25560`
- F-TB09 catalog authority: `fe3545c4537b11cefd0186aa401048d4f4b10eb9`
- F-CI36 frozen admitted DIVDRA postimage: `8fa79a70a9faccaf8b63826df607a685eb75b046`
- independent F-VQ51 verifier authority: `716d0952c2a9580b213cd22d8c3c1dc824f53dff`

## Fixture correction 1: physically active bottom boundary

The first candidate inherited `bottom_mode=7` from the historical DIVDRA verifier. Live source inspection showed that `SWBOTB=7` is free drainage. Changing `bottom_head` or `bottom_flux` in that mode would therefore change metadata without proving interaction with a changing hydraulic lower boundary.

The F-TB10 fixture was corrected to `SWBOTB=5`, the prescribed-head route for which the current reference Richards binding uses bottom head as an active boundary condition and materializes the resulting `qbot` after a successful solve.

## Fixture correction 2: DIVDRA transient-forcing ownership

The first implementation also preallocated `forcing%drainage_flux_by_level`. The admitted DIVDRA composition is intentionally fail-closed when that target is already bound, because the wrapper itself owns the ephemeral drainage-forcing materialization and cleanup. The test fixture was corrected to leave the target unallocated before composition.

No production source was changed.

## Authority correction: frozen F-CI36 preservation

GitHub Actions run `34680041656` on head `886d048cd13ca7bf9fc38e5b401960f3e407e4ee` passed the exact-head and no-production-delta guards but failed when F-TB10 tried to compile the historical F-VQ51 verifier directly against a later generic runtime.

That was classified as an F-TB10 provenance error, not a production defect. Current canonical preserves F-CI36 by replaying its qualified gate on frozen postimage `8fa79a70...`; F-VQ51 is provenance for that frozen authority, not a moving-current integration program.

The F-TB10 runner was corrected to pin the frozen F-CI36/F-VQ51 chain and verify that the admitted DIVDRA production blobs are byte-identical on the F-TB10 canonical base.

## Real integrated execution

The corrected physical attempt ran in GitHub Actions `34680289804` on exact head `3a3017de9b71430deb053a141b7d9ce762346ebd`.

Before the physical failure, the runner established:

- no `src/**` change from the frozen canonical base;
- no `reference/**` change;
- F-TB09 case `SWAP5-TB09-DRAIN-BOTTOM-003-v1` pinned;
- frozen F-CI36/F-VQ51 authority pinned;
- current-canonical DIVDRA composition/runtime/process/binding blobs unchanged from admitted authority;
- prescribed-head `SWBOTB=5` route active;
- real DIVDRA composition and dispatch reached.

The first nonstationary interval was then not committed and the test stopped at:

`FTB10_TEST_FAIL first interval committed`

This failed run is negative evidence only. It does not, by itself, prove a production-physics defect or identify a unique rejecting sub-gate.

## Temporal-policy audit

The F-TB10 template does not activate numerical temporal-history continuation state. Its transaction policy therefore remains the standard external full-versus-two-half route. F-TB10 had `temporal_tolerance = 0`, so acceptance requires exact full/half identity.

The authority audit then established:

### F-VQ28

F-VQ28 explicitly closed fail-closed for the existing generic numeric full-half profile. It selected neither a production temporal metric nor a production temporal tolerance, did not admit a universal absolute tolerance, and requires a separate owner/runtime-policy workunit if nonstationary prescribed-head acceptance is needed.

Therefore F-TB10 may not simply choose a positive `temporal_tolerance`.

### F-VQ19

F-VQ19 qualifies exact zero-tolerance acceptance only for its restricted exact-identity fixture. It does not create a universal numerical temporal policy.

### F-VQ34 and F-CI21

F-VQ34 qualifies the normalized Richards certificate

`C_h = B_inf / H_budget`

and F-CI21 preserves that mechanism on current canonical. The certificate requires explicit finite positive application/runtime budget provenance. No default or universal numeric `H_budget` is qualified, and hard mass rejection has precedence.

### F-CI44 and F-CI46

F-CI44 admits the application-accuracy contract and F-CI46 its external adapter. Both explicitly transport already qualified `H_app` / `A_temporal` evidence and select no numeric policy themselves. Their hard holds include no numeric `H_app`, no numeric `A_temporal` and no project/real-project temporal head-error budget.

### F-GC22

A parallel workunit, F-GC22, closed on branch head `c50f3770ae8e4bee7c276a080be00156218944f1` as `Application and Temporal Accuracy Binding for Direct Groundwater Coupling`.

F-GC22 does not unblock F-TB10:

- it is explicitly restricted to groundwater-head QoI for direct groundwater coupling;
- its status says `canonical_admission: false` and `production_coupling_admission: false`;
- it selects no universal/project numeric `H_app`, temporal allocation or interface allocation;
- its new production module binds already externally qualified accuracy evidence rather than creating such evidence.

Importing F-GC22 as a standalone TB10 numeric policy would therefore be a scope violation and would still not provide a numeric application requirement.

## Blocked decision

The correct closeout is:

`NOT_QUALIFIED_TB09_003_NONSTATIONARY_TEMPORAL_POLICY_GAP`

with status:

`BLOCKED_OWNER_TEMPORAL_ACCEPTANCE_POLICY_REQUIRED`

This is deliberately narrower than claiming that the observed noncommit was caused uniquely by a temporal rejection. The evidence supports the stronger governance statement that, even before a positive TB09-003 scientific admission can be made, F-TB10 has no admitted numerical temporal-acceptance policy it is allowed to tune or invent for the genuine nonstationary workload.

## Owner handoff

`integration/f-tb/F-TB10_OWNER_HANDOFF.json` defines the required separate owner workunit. It must qualify an application-appropriate nonstationary temporal acceptance semantic/provenance, preserve hard mass precedence, keep physics separate from numerical policy, provide bounded retry/cost behavior and expose sufficient rejection diagnostics.

Forbidden shortcuts include:

- arbitrary positive `temporal_tolerance`;
- arbitrary `H_budget`;
- assuming temporal budget equals groundwater interface tolerance;
- using a coupling-only policy outside its qualified scope;
- adding a compensating source/sink that removes the intended drainage interaction;
- relaxing hard mass conservation.

## Architecture and source scope

No production source or reference corpus is modified by F-TB10. F-TB09 remains closed and unchanged. RB1 is not reopened. All 30 core architecture invariants are reconciled for the blocked outcome, with mass conservation hard and unchanged.

## Final closeout rule

F-TB10 is closed only when a dedicated exact-head CI run validates this blocked assessment, owner handoff, no-production/no-reference delta, F-TB09 authority, architecture audit and hard nonclaims on the exact live branch head.

A later commit requires a new exact-head blocked-closeout run. Scientific execution of TB09-003 may resume only after the separate owner gap is qualified and, where required, canonically admitted.
