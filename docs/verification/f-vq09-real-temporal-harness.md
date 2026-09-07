# F-VQ09 — Real B1.10 temporal harness and external asset bundle contract

F-VQ09 is qualification-only and starts from exact qualified F-VQ08 head `0be60f6da7e575eaf992eb049ce600a4a4b35b58`. It changes no production SWAP source, physics, solver policy, timestep policy, mass tolerance or production reference route.

## Goal

Turn the F-VQ08 readiness boundary into executable qualification infrastructure for a future real B1.10 `full_step` versus `two_half_step` characterization from one committed physical state.

This work unit separates two questions that must not be conflated:

1. Is the harness, source materialization and external-asset validation contract exact and fail-closed?
2. Have the exact externally licensed B0 distribution, TTUTIL tree and Hupsel qualification case actually been admitted and used in a real characterization run?

F-VQ09 may qualify the first question while the second remains blocked.

## Source materialization chain

The source chain is deterministic:

- exact external `SWAP_4.3.1.zip` distribution -> exact B1.10 via `tools/vq/b1_10_reconstruct.py`;
- exact B1.10 -> exact F-CI06 controlled source port via `tools/fci/fci06_apply_controlled_source_port.py`;
- exact F-CI06 -> exact F-CI11 interval/mass port via `tools/fci/fci11_apply_controlled_interval_mass_port.py`.

Each stage is pinned to previously qualified byte identities. A source archive with the wrong B0 hash fails closed.

## External TTUTIL and Hupsel assets

The existing real runners require TTUTIL and a Hupsel case directory. Their exact admitted directory hashes are not yet present in canonical Git. F-VQ09 therefore defines a deterministic recursive byte-manifest format and validator. Candidate manifests cannot self-admit an asset: a later admission must persist the expected manifest hash independently.

No external asset is accepted from a filename, directory name or human-readable case label alone.

## Temporal probe contract

The real probe must:

1. initialize the exact materialized B1.10/F-CI11 source against the exact external case;
2. advance to a committed qualification state;
3. capture the complete currently supported B1.10 process checkpoint;
4. create independent logical copies for `full_step` and `two_half_step`;
5. execute both paths from that same state to the same `t1` using the canonical physical interval executor/reference-model advance path;
6. retain raw endpoint differences for the eight F-VQ05 required water metrics and four lagged diagnostics;
7. record optional-process presence and allocation compatibility without falsely claiming complete optional-process comparison;
8. calculate an independent water-mass residual for each path.

## Hard mass rule

For each real admitted path:

`residual = storage(t0) + mass_in - mass_out - storage(t1)`

and `abs(residual) <= 1e-6 cm` is a separate absolute gate. It is never normalized into a temporal score and is never relaxed to make a temporal characterization pass.

## Current admission boundary

Until exact TTUTIL and Hupsel directory manifests are independently admitted and the exact licensed B0 distribution is supplied to the run:

- real F-VQ09 B1.10 temporal execution remains blocked;
- production temporal numeric limits remain null;
- production reference execution remains fail-closed;
- complete optional-process temporal scope remains unqualified.

The persist-first checkpoint deliberately records these boundaries before any compilation or long physical run.
