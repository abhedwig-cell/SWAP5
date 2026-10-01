# OxygenStress source-recovery provenance

Recovered: 2026-10-01

Purpose: durable source-bearing reconstruction asset for PPA-WU05-C3R/C3Q.

## Source-bearing baseline

Repository: `SWAP-model/SWAP`
Path: `src/crop/oxygenstress.f90`
Recovered blob SHA: `f617570c550ed3fe8bd21f31386590ab24493efc`

The recovered file belongs to the same historical Bartholomeus oxygenstress implementation family visible in the retained SWAP 4.3.1 B1.11 patch context. It is NOT declared byte-identical to pinned SWAP 4.3.1.

## 4.3.1 authority overlays already retained

The local SWAP5 evidence establishes at least:
- SWAP-007 corrected Newton quotient guard in `oxygenstress.f90:849`;
- six immutable oxygen precompute arrays and their algebra;
- current `d_soil` expression;
- water-film call contract;
- corrected/reference output regressions;
- September exact-preserving performance evidence.

## Governance classification

`SOURCE_RECOVERY_BASELINE_WITH_431_OVERLAYS`

This asset exists to prevent repeated dependence on user uploads and to support exact formula reconciliation. It may not be cited as the pinned B1.11 oracle until every relevant formula block has been reconciled against source-bearing 4.3.1 evidence.

The pinned B0/B1.11 identity manifests remain repository authority for identity.
