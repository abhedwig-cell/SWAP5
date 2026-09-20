# CSR-04 closure proof obligations

Date: 2026-09-20

Status: **REVISED AFTER STORAGE-STATE AUTHORITY RECONSTRUCTION — PHASE-B EXPERIMENT NEXT**

## 1. Scope

Coupling closure has three different questions that must not be collapsed:
interface mass continuity, hydraulic compatibility, and storage/state authority.
The first two are unconditional coupling obligations. A combined physical
storage balance is conditional on the role assigned to native MODFLOW STO.

## 2. P1 — accepted interface mass continuity

For accepted window transfer `Q_i`:

`Q_i,SWAP + Q_i,MF = 0`

after the pinned sign, unit and area conversions.

Predictor `q_u` is not accepted mass. P1 applies to the converged/finalized
MODFLOW package transfer and corresponding accepted SWAP corrector transfer.

## 3. P2 — hydraulic compatibility

The general obligation is

`H_b,SWAP = T_H(H_MF, topology, datum, ...)`.

The present datum-aligned identity realization is the special case
`T_H(H)=H`. This does not identify MODFLOW regional head with the diagnostic
SWAP groundwater level.

## 4. P3a — component and ledger consistency (always required)

Each accepted component must close its own authoritative accounting surface:

- SWAP physical column mass/storage ledger closes;
- MODFLOW accepted component budget closes;
- the accepted interface ledger agrees with both sides;
- rejected trials do not enter accepted history.

P3a does **not** require adding SWAP storage and MODFLOW STO into one physical
reservoir total.

## 5. P3b — storage-state authority/equivalence (conditional)

Native MODFLOW STO must first be classified as one of:

- `PHYSICAL_INDEPENDENT_STORAGE`;
- `HEAD_STATE_CAPACITANCE`;
- `MIXED_EFFECTIVE_STORAGE`;
- `UNRESOLVED`.

Only `PHYSICAL_INDEPENDENT_STORAGE`, with explicit domain/process authority,
permits its water-volume term to be added to SWAP physical storage in a
combined physical balance.

For `HEAD_STATE_CAPACITANCE`, STO is part of the groundwater head evolution
or solve state and must not be counted as a second physical reservoir on top
of SWAP storage.

`MIXED_EFFECTIVE_STORAGE` requires an explicit partition/correction law
before physical additivity can be claimed.

`UNRESOLVED` remains scientifically unadmitted.

## 6. Why the previous unconditional P3 is withdrawn

The earlier proof obligation assumed that geometric overlap implied two
additive physical reservoirs. Historical shared-state coupling authority and
the reconstructed F-GC30/F-GC33 algebra show that this assumption is not
generally valid.

The assembled head equation contains distinct derivatives

`dR/dH = dR_regional/dH + C_g/DeltaT + A J_s`,

where `A J_s` is the condensed finite-window SWAP interface response and
`C_g/DeltaT` is native MODFLOW head memory. Their simultaneous presence does
not by itself say whether `C_g Delta H` is independent physical storage.

Accordingly the old statement

`Delta S_SWAP + Delta S_MF = external transfers`

is not an unconditional CSR-04 acceptance criterion.

## 7. Discriminating qualification

Phase A varies native MODFLOW STO with a fixed affine SWAP-side response. It
tests the MODFLOW state-space effect but does not establish production storage
authority.

Phase B composes the real FMR participant, existing F-GC30/F-GC33 response and
prepared MODFLOW solve over multiple windows. Use a forcing pulse and recovery
and continue native specific yield through

`0.30, 0.05, 1e-2, 1e-3, 1e-4, 1e-5`.

For every branch/window observe accepted MODFLOW head, SWAP lower-face head,
SWAP diagnostic groundwater level when available, accepted interface
transfer, SWAP storage start/end/change and residual, native MODFLOW STO,
`q_r`, `J_s`, and component/interface residuals.

The near-zero-STO trajectory is a diagnostic limit, not reference truth.

## 8. Decision rule

P1, P2 and P3a must pass for every numerically admitted case.

Then:

- if independent regional physical storage authority is demonstrated, test the
  corresponding P3b physical combined balance;
- if STO is head-state/shared-state capacitance, do not add it to SWAP
  physical storage;
- if mixed, require an explicit partition/correction before production
  admission;
- if unresolved, retain the scientific admission block.

No coupling-residual tuning or geometry-only declaration may substitute for
this authority decision.
