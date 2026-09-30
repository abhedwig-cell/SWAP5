# PPA-WU05-A1 source recovery result

Date: 2026-09-30

Status: `EXACT_SOURCE_RECOVERED / B1.11_MACROPORE_ORACLE_RECONSTRUCTED / CENSUS_IN_PROGRESS`

Baseline: `integration/f-ci-canonical@68fcf6d384608c11ab5a34cf2eab9924f9788ecd`

Research branch: `research/ppa-wu05-a1-source-census-recovery`

## Recovery

The prior PPA-WU05-A blocker stated that the exact SWAP 4.3.1 source bytes were not materialized in the active work session. That blocker has now been removed.

A raw Library copy of `SWAP_4.3.1.zip` was materialized and verified byte-for-byte.

Outer distribution:

```text
SHA-256  2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
bytes     8,959,314
```

This exactly matches `reference/swap-4.3.1/b0/SOURCE_IDENTITY.md`.

Nested archive:

```text
path      SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP
SHA-256   1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151
bytes     411,215
```

This exactly matches the canonical B0 source-archive identity.

Relevant B0 members:

```text
SWAP/macropore.f90
bytes      88,138
SHA-256    1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b

SWAP/macrorate.f90
bytes      111,863
SHA-256    537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7
```

Both values reproduce the canonical B0 per-member manifest.

## B1.11 reconstruction

`macrorate.f90` is unchanged from B0 through B1.11 and already reproduces the frozen B1.11 hash.

For `macropore.f90`, the repository-authoritative SWAP-001 byte transform was applied:

```text
B0
1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b

SWAP-001 target occurrences
1

B1.11 macropore postimage
bytes      88,174
SHA-256    f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f
```

The postimage exactly reproduces the frozen B1.11 identity.

No later admitted B1 patch changes macropore or macrorate semantics. Therefore the exact B1.11 source oracle required by PPA-WU05-A1 is now available for both routines.

## Correction to prior recovery assumption

The source archive was not absent from the user's retained project material. Metadata-level Library enumeration located multiple retained copies of `SWAP_4.3.1.zip` / numbered duplicates across prior project contexts. Earlier semantic/title search failed because ZIP contents are not reliably indexed and some Project-backed copies were not raw-materializable.

The successful recovery used the raw Library object rather than search-indexed text.

## First exact-source observations

The exact B1.11 `macropore.f90` contains explicit task semantics:

- task 1: initialize geometry, initial state and reset accumulators;
- task 2: compute macropore rates;
- task 3: compute rate derivatives;
- task 4: update macropore state and integrate cumulative/intermediate values;
- task 5: reset intermediate fluxes;
- task 6: reset cumulative fluxes.

The exact source confirms that task 4 mutates physical/history fields including:

- `WaUnMpDmCp`;
- `FrMpWalWet`;
- `ZWaLevDm`;
- `TimAbsCumDmCp`;
- `SorpDmCp`;
- `ThtSrpRefDmCp`.

It also confirms explicit previous-state arrays:

- `ICpBtDmM1`;
- `VlMpDmCpM1`;
- `WaUnMpDmCpM1`.

`MACROSTATEVAR` copies the current values into these M1 arrays for one operation and restores only `ICpBtDm`, `VlMpDmCp` and `WaUnMpDmCp` for the opposite operation.

This exact-source finding strengthens the earlier F-PE16 warning: the historical rollback surface is narrower than the full set of trial-mutated macropore history. In particular, `SorpDmCp`, `ThtSrpRefDmCp` and `TimAbsCumDmCp` are mutated during state update but are not restored by `MACROSTATEVAR`.

The exact source also shows `FrMpWalWetOld` being advanced by `MACROINTEGRAL`. Its transaction/restart role must therefore be classified explicitly rather than inferred from the earlier seven-field candidate list.

## Mass-census anchors

The exact `MACROSTATE` update exposes the principal macropore water identity per domain:

```text
storage change
= top lateral inflow
+ top vertical inflow
- matrix exchange
- rapid drainage (domain 1)
```

with source terms:

- `QInTopLatDm`;
- `QInTopVrtDm`;
- `QExcMtxDmCp`;
- `QOutDrRapCp`;
- `WaUnMpDmCp` / `WaSrMpDm` storage.

The detailed sign/owner census remains open. These terms are source anchors, not yet the final accepted mass-receipt schema.

## A1 gate state

- A1-G1 exact B0 source identity: **PASS**.
- A1-G2 B1.11 derivation for macropore/macrorate: **PASS**.
- A1-G3 complete state census: **IN PROGRESS**.
- A1-G4 complete transaction census: **IN PROGRESS**.
- A1-G5 complete mass census: **IN PROGRESS**.
- A1-G6 historical index-0 characterization: **NOT YET RUN ON EXACT ORACLE**.

Production implementation remains held until G3-G6 are resolved.
