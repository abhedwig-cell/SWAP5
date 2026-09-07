# F-MQ22 — F-KT06 optional-state P14 admission

## Purpose

F-MQ22 admits the exact qualified F-KT06 optional-process continuation lifecycle as MultiSWAP qualification evidence and closes the remaining synthetic qualification gap for P14, provided the F-MQ-specific two-column paired module-off/on gate passes on the exact F-KT06 tested postimage.

## Exact basis

- F-MQ21 parent: `ae843506cd0d5ed54a550ef75aaf9c322959d1d3`
- F-KT06 qualification head: `42872c266bc6f4fbf6815b1facbc3ed5d64df19a`
- F-KT06 tested postimage: `80a68dea3bfa45d7e8d533ec5a67fc89bdb786db`
- F-KT06 qualification blob: `75cc6d399facdb6bb8303ca905ac8056aeda3b2c`
- F-KT06 optional-continuation contract blob: `64f285ac6ae89297ca221048c2ff55cc580e3492`
- corrected legacy oracle: B1.10

## P14 qualification

The canonical MQ matrix requires P14 to show that two logical columns can use a paired module-off/on layout with one worker, where the module-off state contains no module-specific continuation payload and immutable parameters remain shared/referenced.

F-KT06 already qualifies that inactive optional continuation remains unallocated through checkpoint, trial, candidate and commit, while active continuation is deep-cloned, replayable, rollback-safe and mass-rejection-safe. F-MQ22 adds a two-column qualification-only gate that checks:

- exactly two logical committed column states;
- one inactive and one active optional continuation layout;
- zero dynamic optional payload bytes for the inactive column;
- exactly one optional payload object for the active column;
- identical shared immutable parameter reference for both columns;
- committed and checkpoint state layout identity;
- O0/O2 deterministic output.

If these checks and the exact upstream F-KT06 gate pass, P14 may move from interface-needed to synthetic executable. Synthetic coverage therefore moves from 27/35 to 28/35.

## Explicit nonclaims

F-MQ22 does **not** qualify real B1.10 P14 physics, macropore production admission, full SWAP mass identity, parallel real HeadCalc reentrancy or production MultiSWAP runtime. F-SI07, F-MR01 and F-VQ13 are observed only as pending context and are not consumed as evidence.

No production source is modified by F-MQ22.
