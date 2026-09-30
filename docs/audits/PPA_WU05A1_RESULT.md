# PPA-WU05-A1 result — exact source recovery and rollback-surface census

Date: 2026-09-30

Status: `QUALIFIED_SOURCE_RECOVERY / STATE_CENSUS_PARTIAL_COMPLETE / MASS_CENSUS_IN_PROGRESS`

Baseline: `integration/f-ci-canonical@68fcf6d384608c11ab5a34cf2eab9924f9788ecd`

Research branch: `research/ppa-wu05-a1-source-census-recovery`

## Exact source recovery

The previously uploaded SWAP 4.3.1 distribution was recovered from the user's Library and materialized byte-for-byte.

Recovered file:

`SWAP_4.3.1.zip`, 8,959,314 bytes.

SHA-256:

`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`

This exactly matches the repository-pinned canonical B0 outer-distribution identity.

The nested source archive was extracted at:

`SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP`

SHA-256:

`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`

This exactly matches the repository-pinned B0 source archive.

Therefore PPA-WU05-A's `EXACT_SOURCE_MATERIALIZATION_REQUIRED` blocker is closed.

## Exact macropore source identities

B0:

- `SWAP/macropore.f90`: 88,138 bytes, SHA-256 `1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b`;
- `SWAP/macrorate.f90`: 111,863 bytes, SHA-256 `537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`.

The B0 `macrorate.f90` is byte-identical to the B1.11 pinned identity.

Canonical SWAP-001 was applied byte-safely to B0 `macropore.f90` using its exact repository-defined one-sequence transformation:

`VlMpDm1Cp= VlMpDmCp(1,1:numnod)`

becomes

`VlMpDm1Cp = 0.0d0`

plus active-range assignment

`VlMpDm1Cp(1:numnod) = VlMpDmCp(1,1:numnod)`.

The resulting `macropore.f90` is 88,174 bytes with SHA-256:

`f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f`

which exactly equals the pinned B1.11 identity.

For the two A1 owning source files, the exact B1.11 oracle is therefore recovered.

## Exact legacy transaction path

The B1.11 call chain establishes:

1. `soilwater(2)` calls `MacroStateVar(1)` before `headcalc`;
2. `headcalc` calls `MACROPORE(2)` during nonlinear evaluation;
3. `MACROPORE(2)` calls `MACRORATE(1)`;
4. `MACRORATE(1)` calls `MPVOLUME(1)`, which mutates dynamic macropore geometry from the current nonlinear iterate;
5. if the step is reduced/rejected, `swap.f90` calls `MacroStateVar(2)`;
6. after acceptance, `soilwater(3)` calls `macropore(4)`, which calls `MACROSTATE` and `MACROINTEGRAL`.

This is sufficient to classify any source field changed in the rate/nonlinear path and used later as trial-mutable unless it is deterministically recomputed before every subsequent read.

## Legacy rollback surface is incomplete

`MacroStateVar` saves/restores exactly three arrays:

- `ICpBtDm`;
- `VlMpDmCp`;
- `WaUnMpDmCp`.

Exact-source inspection confirms that this is not the complete mutable continuation/history surface.

### Confirmed additional trial-mutated history

`MACRORATE` reads/writes sorptivity-event state:

- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`.

These values influence later absorption calculations and are not included in `MacroStateVar` rollback.

Therefore a rejected nonlinear/time-step attempt can mutate sorptivity history that survives the legacy three-array rollback.

This upgrades the F-PE16 prior finding from corroborated historical evidence to exact B1.11 source-bound evidence.

### Confirmed additional trial-mutated geometry/history

`MACRORATE(1)` calls `MPVOLUME(1)` on the current nonlinear iterate.

`MPVOLUME(1)` mutates, among others:

- `VlMpDyCp`;
- `ICpBtDm`;
- `VlMpDmCp`;
- `VlMpDm`;
- `VlMp`;
- `ZBtDm`;
- `ArMpTp` / `ArMpTpDm` and associated derived geometry.

Only `ICpBtDm` and `VlMpDmCp` are explicitly restored by `MacroStateVar(2)`.

`VlMpDyCp` is read on the next `MPVOLUME(1)` call to choose the wetting/drying crack-state branch:

`Theta(ic) > ThetM1(ic)-1e-8 AND (VlMpDyCp(ic)>0 OR neighbour VlMpDyCp>0)`.

Hence `VlMpDyCp` cannot be classified as disposable rate scratch. It carries physical hysteretic geometry/history across calls and must belong to atomic candidate/rollback ownership unless a future reformulation removes that dependence.

This also upgrades the seventh F-PE16 candidate field to exact-source-confirmed continuation state.

## Current exact continuation-state minimum

The source-bound minimum transaction surface now includes at least the seven F-PE16 candidates:

- `ICpBtDm`;
- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`;
- `VlMpDmCp`;
- `WaUnMpDmCp`;
- `VlMpDyCp`.

The census is not yet declared final. Additional fields are being classified before A1 close, particularly previous-step mirrors, wet-wall history and aggregate storage/geometry fields.

## Previous-state mirrors

B1.11 contains explicit previous-state mirrors:

- `ICpBtDmM1`;
- `VlMpDmCpM1`;
- `WaUnMpDmCpM1`.

These are written by `MacroStateVar(1)` and used during state/rate calculations. They are transaction bookkeeping/checkpoint representation in the legacy scheme, not independent physical degrees of freedom. A typed SWAP5 state should not blindly duplicate them if candidate state can be represented structurally.

## Historical index-0 observation

The earlier A23AU report recorded a bounds-checked index-0 access involving `QExcMtxDmCp` in the MacroState path.

Exact B1.11 source is now available, so this diagnostic is no longer blocked by source provenance. It remains a separate A1 characterization item and is not yet declared a confirmed production defect in this result.

## A1 conclusion so far

`SOURCE_MATERIALIZATION_BLOCKER_CLOSED`

and

`LEGACY_MACROPORE_ROLLBACK_SURFACE_PROVEN_INCOMPLETE`.

No production source has been changed.

The immediate next step is to finish:

1. the complete cross-call field classification;
2. the exact internal/external mass-transfer sign and ownership map;
3. source-bound characterization of the historical index-0 path.

Only after those close should PPA-WU05-A2 define typed committed/candidate/restart DTOs.


## Exact mass-transfer ownership map

The B1.11 rate path separates gross matrix/macropore exchange from external column transfers.

### External into the macropore domain

- `QInTopVrtDm`: vertical surface input into macropores, partitioned from rainfall/irrigation/melt through the active macropore surface area;
- `QInTopLatDm`: lateral surface/ponding input into macropores, originating from `QMpLatSs`.

These are external to the soil matrix/macropore internal exchange system, but remain part of the whole-column top-boundary water accounting and must not be counted independently in both matrix and macropore receipts.

### External out of the whole soil column

- `QOutDrRapCp`, aggregated as `QRapDra`: rapid macropore drainage to the drainage/surface-water system.

`QRapDra` is consumed by the surface-water module and is therefore an external accepted transfer with one owner.

### Internal matrix/macropore transfers

The following are gross internal transfers:

- `QInIntSatDmCp`;
- `QInMtxSatDmCp`;
- `QOutMtxSatDmCp`;
- `QOutMtxUnsDmCp`.

They are combined into the signed net exchange

`QExcMtxDmCp = QOutMtxSatDmCp + QOutMtxUnsDmCp - (QInIntSatDmCp + QInMtxSatDmCp)`.

The domain sum becomes `QExcMpMtx`, and the column sum becomes `QMaPo`.

`QExcMpMtx` enters the Richards residual with the opposite ownership to the macropore balance. Therefore this is an internal matrix/macropore transfer and cancels from whole-column accepted mass when booked once on each side.

`QMaPo` is a diagnostic/net aggregate of that internal exchange. It must not be booked as an additional external flux.

### Storage

`WaUnMpDmCp` / domain and aggregate macropore storage are physical storage. Their accepted change belongs in whole-column storage reconciliation.

### Root-related transfers

No direct root-water extraction term is produced by `macropore.f90` or `macrorate.f90`. Root extraction remains on the matrix/soil-water side of the B1.11 source path. A future SWAP5 macropore DTO should therefore not invent a separate root-related macropore external receipt without an explicit new physical contract.

### Mass ownership conclusion

The A1 source-bound mass map supports the predecessor invariant:

- surface macropore inflow is a partition of the top boundary, not a second independent precipitation/irrigation source;
- rapid drainage is an external outflow;
- matrix/macropore exchange is internal and cancels in whole-column mass;
- storage change is physical;
- rejected trials must publish none of these accepted receipts.
