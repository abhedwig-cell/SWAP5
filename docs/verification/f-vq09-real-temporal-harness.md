# F-VQ09 — Real B1.10 temporal harness and external asset bundle contract

F-VQ09 is qualification-only and starts from exact qualified F-VQ08 head `0be60f6da7e575eaf992eb049ce600a4a4b35b58`. Persist-first checkpoint: `5445fc6f5bd1d1df9ae0e8ca1ef02c7a2a61a55b`. It changes no production SWAP source, physics, solver policy, timestep policy, mass tolerance or production reference route.

## Goal

Turn the F-VQ08 readiness boundary into executable qualification infrastructure for a future real B1.10 `full_step` versus `two_half_step` characterization from one committed physical state.

This work unit separates two questions that must not be conflated:

1. Is the harness, source materialization and external-asset validation contract exact and fail-closed?
2. Have the exact externally licensed B0 distribution, TTUTIL tree and Hupsel qualification case actually been admitted and used in a real characterization run?

F-VQ09 may qualify the first question while the second remains blocked.

## Qualified production-source lineage

F-CI18 identifies `da5026d8b87ad2f3c7912360891839a120ecccb6` as the qualified production-source head. F-VQ09 therefore refuses to run its real materializer if the current `src/` tree differs from that head.

The legacy physical source is reconstructed deterministically as:

- exact external `SWAP_4.3.1.zip` -> exact B1.10 via `tools/vq/b1_10_reconstruct.py`;
- exact B1.10 -> exact F-CI06 controlled source port via `tools/fci/fci06_apply_controlled_source_port.py`;
- exact F-CI06 -> exact F-CI11 generic-interval/unrounded-mass port via `tools/fci/fci11_apply_controlled_interval_mass_port.py`;
- exact F-CI11 `swap.f90` -> exact F-CI13 canonical-trial terminal-status postimage by adding only the previously qualified minimum-dt terminal-status guard.

The F-CI13 overlay is accepted only if removing that one exact guard reproduces the F-CI11 `swap.f90` byte content after line-ending normalization. F-CI14 adds the temporal policy contract in the qualified production source, but F-VQ09 deliberately does not use an F-CI14 numerical profile because no real B1.10 limits are qualified.

## External TTUTIL and Hupsel assets

The real runner requires TTUTIL and the Hupsel qualification case. Their exact admitted directory hashes are not yet present in canonical Git. F-VQ09 therefore defines a deterministic recursive byte-manifest format and validator. Candidate manifests cannot self-admit an asset: a later admission must persist the expected manifest hash and file count independently.

No external asset is accepted from a filename, directory name or human-readable case label alone. Symlinks and non-regular files are rejected. The exact B0 distribution must independently match the immutable size and SHA-256 already recorded for B0.

## Real temporal probe contract

When—and only when—the external bundle is independently admitted, the runner must:

1. validate B0, TTUTIL and Hupsel identities before source materialization or compilation;
2. materialize the exact B1.10 -> F-CI06 -> F-CI11 -> F-CI13 physical source lineage;
3. compile the real physical path at `-O0` and `-O2` against the exact qualified adapter/runtime tree;
4. initialize the real Hupsel model and reach a committed qualification state;
5. capture the current B1.10 process checkpoint plus the separate legacy trial-only capsule;
6. make independent full-step and split-step logical copies of the same captured physical state;
7. restore the same trial-only capsule before the full path and before the first split half;
8. run the full path `[t0,t1]` and the split path `[t0,tmid] + [tmid,t1]` using the F-CI13 recoverable reference-model path;
9. compare both paths at exactly the same `t1` using the canonical raw temporal characterization;
10. persist a raw observation containing exact provenance, endpoint differences, lagged diagnostics, separate mass balances and process-scope flags.

The characterization start is derived from the observed legacy `t1900` committed time; the harness does not assume midnight, one-day coupling windows or calendar-day-only execution.

## Hard mass rule

For each real admitted path:

`residual = storage(t0) + mass_in - mass_out - storage(t1)`

and `abs(residual) <= 1e-6 cm` is a separate absolute gate. It is never normalized into a temporal score and is never relaxed to make a characterization pass.

## Optional-process boundary

The qualified Hupsel profile has crop, fixed irrigation, heat and solute active. The current canonical temporal comparator records the eight water endpoint metrics plus four lagged water diagnostics and flags optional-process presence/allocation compatibility. It does **not** compare every active crop, WOFOST, irrigation, heat or solute state variable. F-VQ09 therefore requires `optional_process_state_present=true` and keeps `process_scope_complete=false`; it must not promote water-domain observations to complete optional-process qualification.

## Current admission boundary

Until exact TTUTIL and Hupsel directory manifests are independently admitted and the exact licensed B0 distribution is supplied to the run:

- real F-VQ09 B1.10 temporal execution remains blocked;
- production temporal numeric limits remain null;
- production reference execution remains fail-closed;
- complete optional-process temporal scope remains unqualified.

A green F-VQ09 CI run can qualify the **harness and fail-closed external-asset contract only**. It cannot by itself qualify any real temporal observation or production temporal acceptance profile.
