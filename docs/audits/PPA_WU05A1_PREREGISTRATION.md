# PPA-WU05-A1 preregistration — exact macropore source recovery and census

Date: 2026-09-30

Status: `PREREGISTERED / RESEARCH_ONLY / PRODUCTION_HELD`

Baseline: `integration/f-ci-canonical@68fcf6d384608c11ab5a34cf2eab9924f9788ecd`

Owning predecessor: `PPA-WU05-A Macropore source/state/mass/transaction authority`.

## Purpose

Close the exact-source blocker frozen by PPA-WU05-A before any production macropore migration.

This work unit must recover a byte-exact SWAP 4.3.1/B0 source authority for `macropore.f90` and `macrorate.f90`, derive the admitted B1.11 postimage through the canonical SWAP-001 correction, and perform a complete cross-call mutable-state and mass-transfer census.

No production source mutation is permitted in A1.

## Repository authority already frozen

PPA-WU05-A established:

- B1.11 `macropore.f90` SHA-256: `f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f`;
- B1.11 `macrorate.f90` SHA-256: `537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`;
- SWAP-001 is the only admitted B0-to-B1 correction touching `macropore.f90`;
- seven fields from F-PE16 are corroborated continuation-state candidates, not a final census;
- recomputable helper/rate workspace is worker/job scratch;
- rejected trials may publish neither macropore state nor mass receipts.

## Recovered evidence available at A1 start

Historical repository evidence remains:

- F-PE16: `work/f-pe16-s12-macropore-memory-recovery@f5e2a12f...`;
- F-PE15: `work/f-pe15-a23au-macropore-scratch-recovery@f475e0e...`;
- F-SI15: `work/f-si15-explicit-macropore-option@fe5e55d...`.

Project/Library retrieval also exposes retained artifacts including:

- `S12o_macropore_column_state.patch`;
- `S11_cumulative_from_pristine.patch`;
- `A23AU_REPORT.md`.

These artifacts corroborate prior findings but are not accepted as substitutes for the byte-exact source oracle.

The S12o artifact independently exposes the same seven candidate continuation fields:

`ICpBtDm`, `SorpDmCp`, `ThtSrpRefDmCp`, `TimAbsCumDmCp`, `VlMpDmCp`, `WaUnMpDmCp`, `VlMpDyCp`.

The A23AU report also records a distinct historical diagnostic finding: a bounds-checked reconstructed full-model run reached a pre-existing index-0 access involving `QExcMtxDmCp` in the MacroState path. This is not yet promoted to a present B1.11 defect claim.

## External-source rule

The official SWAP site currently exposes SWAP 4.3.1 as the June 2026 development release behind its registration/download page.

An unofficial public GitHub SWAP repository contains macropore sources, but those sources have undergone independent refactoring and documentation changes. They may be used only as orientation unless byte identity to the pinned source authority is proven. Similar filenames or model version labels are insufficient.

## A1 questions

1. Can the exact B0 source bytes be recovered and verified against repository-pinned archive/member identity?
2. Does deterministic SWAP-001 application reproduce the pinned B1.11 macropore hash?
3. Which variables survive across macropore calls/time steps and are therefore physical/history continuation state?
4. Which variables are trial-mutable and therefore require atomic candidate/rollback ownership?
5. Which arrays/scalars are strictly recomputable scratch?
6. Which transfers are internal matrix/macropore exchanges and which are externally owned water transfers?
7. Is the historical index-0 observation reproducible on the exact B1.11 oracle, and if so under which path and inputs?

## Gates

### A1-G1 source identity
PASS only if byte-exact B0 inputs are materialized and independently hash-verified.

### A1-G2 B1.11 derivation
PASS only if canonical SWAP-001 application yields the pinned B1.11 hash and no later admitted B1 patch touches the relevant semantics.

### A1-G3 state census
Enumerate every cross-call mutable variable with read/write sites and classify as committed/history, trial-only, configuration/derived immutable, output administration, or recomputable scratch.

### A1-G4 transaction census
For every trial-mutable physical/history field, prove required capture/restore semantics. Partial rollback is forbidden.

### A1-G5 mass census
Enumerate top inflow, bottom transfer, rapid drainage, matrix exchange, storage change and any root-related terms with sign and accepted owner. Internal transfers must cancel in whole-column mass.

### A1-G6 diagnostic characterization
Characterize the historical index-0 path only after exact-source recovery. Do not repair it in A1 unless a separate work unit is opened after proof.

## Stop conditions

A1 closes as one of:

- `QUALIFIED_EXACT_SOURCE_AND_CENSUS_COMPLETE`;
- `QUALIFIED_SOURCE_RECOVERY_COMPLETE_DIAGNOSTIC_FOLLOWON_REQUIRED`;
- `SOURCE_MATERIALIZATION_BLOCKED`;
- `SOURCE_IDENTITY_MISMATCH`.

A1 does not admit typed macropore production state or migrated equations. Those remain A2/A3 work.

## Next authorized action

Recover the exact SWAP 4.3.1 source archive or member bytes, hash them, reconstruct the B1.11 postimage, then perform the source-bound state/mass census.
