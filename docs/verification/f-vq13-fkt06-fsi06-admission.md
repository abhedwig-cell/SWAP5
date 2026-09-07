# F-VQ13 — F-KT06 / F-SI06 source-bound admission

## Decision

`QUALIFIED_FKT06_FSI06_SOURCE_BOUND_HISTORY_CONTINUATION_ALIGNMENT_ONLY`

F-VQ13 admits the exact qualified F-KT06 optional-process continuation lifecycle and the exact qualified F-SI06 HeadCalc history-isolation slice on its qualified serial common-reference route. It also qualifies their ownership alignment: physics-affecting continuation belongs in per-column transactional state; reporting-only history remains outside committed physical state; solver scratch remains worker/job-owned.

This is **not** a composed-runtime qualification. No single executable production postimage containing both development lines is qualified here.

## Exact basis

- F-VQ12 final qualification ancestor: `7cd06ba606429c891dab7f355a85b58ca56a3bca`.
- F-CI18 canonical closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`.
- F-KT06 tested postimage: `80a68dea3bfa45d7e8d533ec5a67fc89bdb786db`.
- F-KT06 final qualification head: `42872c266bc6f4fbf6815b1facbc3ed5d64df19a`.
- Stable F-KT06 optional-continuation contract blob: `64f285ac6ae89297ca221048c2ff55cc580e3492`.
- F-SI06 tested head: `dfed799dbc0930bdf5218e713934ea0f148e3872`.
- F-SI06 documented postimage: `2fa63c41a4d7248ab7f4b5af46f72caddfda4f29`.
- F-SI06 final qualification head: `d0f0cc0817f2e2b8ca55dd90752cfda2f7b0e6e8`.

F-SI06 observed the exact F-KT06 contract blob later carried unchanged into the qualified F-KT06 final lineage. The alignment is therefore source-bound rather than inferred only from prose.

## Qualification replay

Qualified tested F-VQ13 postimage: `adec037bc206e30cbd12d08aa2c2ba9b85328b8e`.

- F-VQ13 dedicated run `34129643680`, job `101766409437`: PASS.
- Exact F-KT06 focused O0/O2 gate plus selected F-CI regressions: PASS.
- Exact F-SI06 tested history-isolation gate: PASS.
- F-SI06 documented-postimage gate: PASS.
- Immutable F-VQ12 run `34129643459`, job `101766408878`: PASS.
- VQ-reference run `34129643451`: PASS.
- Documentation run `34129643466`: PASS.
- Immutable F-VQ11 run `34129643558`: PASS.
- Compiler: GNU Fortran 13.3.0.

The initial F-VQ13 attempt `34129443776` / job `101765762577` failed only because four result-report values used JSON-style `false` instead of Python `False`. Commit `adec037bc206e30cbd12d08aa2c2ba9b85328b8e` corrected only those literals. No qualification scope, production source, physics, numerical policy or mass policy changed.

## Ownership result

F-KT06 qualifies optional future-physics continuation through the existing opaque per-column transaction-state lifecycle. The kernel does not import F-SI types and does not hard-code `nstep`; inactive optional state can remain unallocated.

F-SI06 removes hidden HeadCalc SAVE ownership and makes warning/reporting history explicit. `flwarn` and `iwarn` are reporting-only history. `nstep` is explicitly **not** worker scratch: where it affects future accepted physics, it must be materialized in adapter-specific transactional state before that physical path is admitted.

This preserves the F-KT/F-SI authority boundary: transaction state and commit/rollback semantics remain F-KT-owned; solver scratch and solve-local history remain F-SI/worker-owned.

## Parallelism hold

F-SI06 does not qualify real HeadCalc 1/2/4/8 worker reentrancy. The common legacy adapter still translates request/candidate physical state through shared legacy module globals before and after HeadCalc, so concurrent real calls can interfere even with isolated workspaces and history objects.

## Mass conservation

Mass conservation remains absolute. F-KT06 preserves committed/checkpoint optional continuation on hard-mass rejection. F-SI06 retains its focused unrounded equation-residual identity, but F-VQ13 does **not** promote that result into full SWAP water-balance qualification.

## Still fail-closed

The following remain unqualified:

- one composed executable F-KT06 + F-SI06 production postimage;
- real HeadCalc parallel 1/2/4/8 worker reentrancy;
- macropore production admission and `nstep` transaction-state materialization;
- full unrounded SWAP water-balance identity;
- production B1.10 reference execution;
- production MultiSWAP runtime;
- implicit-conductivity, minimum-timestep and non-free-drainage bottom paths;
- interface tangent qualification;
- MODFLOW coupling qualification.

F-VQ13 changes no production source, reference source, physics, numerical policy, mass policy or production routing.
