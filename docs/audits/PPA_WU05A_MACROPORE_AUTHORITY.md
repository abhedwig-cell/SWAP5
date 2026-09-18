# PPA-WU05-A Macropore source/state/mass/transaction authority

Date: 2026-09-18

Status: `PARTIAL_AUTHORITY_FROZEN / EXACT_SOURCE_MATERIALIZATION_REQUIRED`

Canonical reconcile base: `integration/f-ci-canonical@5db312c3845ccb0a00372b3ccf3e6a45f0be9a2b`.

## Purpose

PPA-WU05 selected macropore ownership as the first advanced-water follow-on because it has high application relevance and unblocks several later capabilities, but current canonical has no admitted typed macropore state, restart or production flow route.

PPA-WU05-A does not migrate macropore physics. It separates what is already repository-authoritative from what still requires the byte-exact B1.11 source.

## Exact B1.11 authority already available

The corrected reference remains B1.11 with member-manifest SHA-256:

`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

Relevant exact member identities are:

- `SWAP/macropore.f90 = f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f`;
- `SWAP/macrorate.f90 = 537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`;
- `SWAP/macroporeoutput.f90 = 39a0497cfff82540a7323cecceafc3a17d389eb4708014bbf99f6256b65a8b0a`.

SWAP-001 is the only admitted B0-to-B1 correction touching `macropore.f90`. It fixes the non-conformable `VlMpDm1Cp` whole-array assignment without changing the macropore equations. No later B1 patch changes macropore or macrorate semantics.

That establishes exact reference identity, but identity is not the same thing as a complete source-level state census.

## Historical repository evidence recovered

Three real repository branches were recovered and pinned.

### F-PE16

`work/f-pe16-s12-macropore-memory-recovery@f5e2a12fca96559645feb8d8cd591b600f765d8c`

This report records strong prior evidence for an active-sized `MacroporeColumnState` and identifies seven fields as committed physical/history candidates:

- `ICpBtDm`;
- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`;
- `VlMpDmCp`;
- `WaUnMpDmCp`;
- `VlMpDyCp`.

It also records that `SorpDmCp` and `ThtSrpRefDmCp` were trial-mutable under the historical line and that the historical rollback slice did not restore all such fields.

This is important ownership evidence. It is not promoted here to a definitive B1.11 field census because the exact S12 patch payload and the byte-exact B1.11 source are not retained in the current Git tree.

### F-PE15

`work/f-pe15-a23au-macropore-scratch-recovery@f475e0e050abdc885c016929c2d528fe1f8f0545`

This report shows that a subset of hidden `SAVE` workspace in `SATFLOW` and `ABSORPTION` could be extracted into explicit active-sized worker/job scratch while preserving qualified outputs and rollback behavior.

This supports the architectural rule that recomputable rate workspace must not be committed physical state. It does not establish complete macropore thread safety or the exact final scratch-field membership.

### F-SI15

`work/f-si15-explicit-macropore-option@fe5e55d5d5ebff42e8212cba8df15652e5f1a52b`

F-SI15 introduced an explicit macropore physical option in the solver request while keeping `macropore_active=true` fail-closed before HeadCalc on the typed route. The current serialized backend still rejects active macropores.

This is the current architecture precedent: option identity is explicit, but active production macropore execution is not admitted.

## State authority frozen by WU05-A

The following rules are authoritative after this review:

1. Macropore continuation state must be an explicit optional physical state topology.
2. Worker/rate scratch is not restart or checkpoint state.
3. Every source-traced trial-mutable physical/history field must be represented in candidate/rollback ownership.
4. Partial rollback of macropore continuation state is forbidden.
5. The seven F-PE16 fields are **corroborated candidates**, not yet the final B1.11 state schema.
6. Exact field membership remains held until byte-exact B1.11 source materialization and a complete cross-call mutable-field census.

This distinction prevents historical performance evidence from silently becoming a physics source oracle.

## Mass contract

PPA-WU05-A freezes the ownership invariants without inventing legacy variable names or signs.

- Matrix-to-macropore and macropore-to-matrix exchange are internal transfers and cancel from the whole-column accepted mass identity when booked consistently.
- Macropore storage change is physical storage and belongs in accepted mass reconciliation.
- External top, bottom, drainage and root-related water transfers must each have exactly one accepted owner.
- Gross partition terms and net terms may not both be booked as independent external fluxes.
- Rejected trials publish no accepted macropore mass receipt.
- No mass tolerance may be relaxed to admit macropore physics.

The exact B1.11 flux-name/sign map is still held for the source trace.

## Transaction contract

Target semantics are:

```text
accepted matrix + macropore checkpoint
        |
        +--> trial macropore candidate
        +--> worker-local disposable rate scratch
        +--> coupled Richards/macropore trial
        |
        +--> reject
        |      -> discard candidate
        |      -> discard mass receipts
        |      -> retain exact accepted checkpoint
        |
        +--> accept
               -> atomically publish matrix state
               -> atomically publish macropore state
               -> publish exactly-once external mass receipts
               -> internal transfers cancel in whole-column accounting
```

A retry with a smaller numerical span starts from the same accepted matrix plus macropore checkpoint. It may not inherit any rejected-trial macropore history.

## Restart contract

A production macropore route will require an explicit optional-state layout and reconstruction authority.

Restart may contain only source-proven physical/history continuation state. Recomputable rate scratch is excluded.

A field may be omitted only after source-bound proof that it is deterministic from accepted state and immutable configuration. The F-PE16 seven-field set is therefore a candidate restart surface, not the final schema.

## Source-materialization blocker

The canonical repository deliberately stores B1 as an ordered derivation rather than a full duplicated source tree. The exact B0 distribution is controlled by archive/member hashes, and SWAP-001 can deterministically produce the B1 macropore postimage from byte-exact B0 input.

The current Git tree, recovered F-PE15/F-PE16 branches and historical A23 branch do **not** contain the complete `macropore.f90` / `macrorate.f90` source bytes or the original retained S12 patch artifacts.

The Project Files surface was also queried for the previously uploaded SWAP 4.3.1 archive in this session, but no retrievable file handle was returned.

Therefore the exact cross-call source census cannot be completed honestly in this workunit.

This is a real source-materialization blocker, not a scientific ambiguity.

## Required materialization gate

Before production implementation:

1. materialize byte-exact B0 `SWAP/macropore.f90` and `SWAP/macrorate.f90`;
2. verify their B0 member hashes;
3. apply SWAP-001 with the canonical byte-preserving verifier;
4. verify B1.11 macropore SHA-256 `f44049c...f106f`;
5. prove that no later B1 patch affects the two routines;
6. enumerate every cross-call mutable field and every external/internal water transfer;
7. reconcile that census against the F-PE16/F-PE15 prior evidence;
8. freeze the exact restart schema and candidate/scratch split.

## Frozen follow-on slicing

### PPA-WU05-A1
Byte-exact B1.11 source materialization plus mutable-field and mass-transfer census.

### PPA-WU05-A2
Typed macropore committed/candidate/restart DTOs and rollback harness. No macropore flow equations.

### PPA-WU05-A3
Single-column macropore physics/rate migration against the exact source oracle.

### PPA-WU05-A4
Full serialized runtime composition with hard mass, restart and preservation of all existing non-macropore profiles.

### PPA-WU05-A5
Parallel MultiSWAP ownership and worker-scratch qualification.

No later slice may skip A1.

## Review verdict

`PARTIAL_AUTHORITY_FROZEN_SOURCE_MATERIALIZATION_REQUIRED`

WU05-A removes ambiguity about ownership, transaction and mass invariants and recovers real repository evidence that was unavailable to the first WU05 pass.

It does **not** claim that the exact B1.11 persistent-state field list or flux map has been recovered.

Production macropore implementation remains held until PPA-WU05-A1 closes.
