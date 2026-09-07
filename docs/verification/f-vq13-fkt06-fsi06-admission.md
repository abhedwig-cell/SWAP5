# F-VQ13 — F-KT06 / F-SI06 source-bound admission

## Purpose

F-VQ13 independently assesses the qualified F-KT06 optional-process continuation lifecycle and the qualified F-SI06 HeadCalc history-isolation slice.

The intended positive scope is deliberately narrower than runtime composition. F-VQ13 may qualify the two source-bound lineages and their ownership alignment, but it does not create or qualify a joint F-KT06 + F-SI06 executable production postimage.

## Qualification basis

- F-VQ12 final head: `7cd06ba606429c891dab7f355a85b58ca56a3bca`.
- F-CI18 canonical closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`.
- F-KT06 tested postimage: `80a68dea3bfa45d7e8d533ec5a67fc89bdb786db`.
- F-KT06 final qualification head: `42872c266bc6f4fbf6815b1facbc3ed5d64df19a`.
- F-SI06 tested head: `dfed799dbc0930bdf5218e713934ea0f148e3872`.
- F-SI06 documented postimage: `2fa63c41a4d7248ab7f4b5af46f72caddfda4f29`.
- F-SI06 final qualification head: `d0f0cc0817f2e2b8ca55dd90752cfda2f7b0e6e8`.

## Ownership alignment under assessment

F-KT06 qualifies the existing opaque per-column transaction state as the canonical lifecycle carrier for optional future-physics continuation. It does not hard-code F-SI types or a macropore field, and inactive optional state may remain unallocated.

F-SI06 removes hidden HeadCalc SAVE ownership and separates reporting-only history (`flwarn`, `iwarn`) from physics-affecting continuation. Its `nstep` finding is explicitly not worker scratch: where it affects future physics it must be materialized in adapter-specific transactional continuation before the corresponding physical path can be admitted.

These decisions are architecturally aligned with the SWAP invariants: compact committed state, scratch per worker, transaction ownership in F-KT, and optional functionality scaling with use.

## Hard holds

The following are not admitted by F-VQ13:

- a composed executable F-KT06 + F-SI06 production postimage;
- real HeadCalc parallel 1/2/4/8 worker reentrancy;
- macropore production execution or `nstep` transaction-state materialization;
- full unrounded SWAP water-balance qualification;
- production B1.10 reference execution;
- production MultiSWAP runtime;
- implicit-conductivity, minimum-timestep and non-free-drainage bottom paths;
- interface tangent qualification;
- MODFLOW coupling qualification.

F-SI06 itself identifies shared legacy module-global request/candidate translation as the blocker for real parallel HeadCalc. F-VQ13 must preserve that blocker fail-closed.

No production source, reference source, physics, numerical policy, mass policy or production routing is changed by F-VQ13.

## Pre-test state

Status: `PENDING_FVQ13_CI`.

The qualification decision may only be promoted after an exact F-VQ13 gate, immutable F-KT06/F-SI06 replays, immutable F-VQ12 replay, VQ reference regression and documentation checks all pass on the same tested postimage.
