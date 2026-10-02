# PPA-WU05-A29 preregistration: MultiSWAP-MODFLOW A28 system qualification

Date: 2026-10-02
Status: PREREGISTERED
Depends on: PPA-WU05-A28 Q1-Q4B

## Purpose
Determine whether opt-in A28_V1 has bounded hydrologic effects and useful performance in coupled MultiSWAP-MODFLOW.

## Coupling authority
Use current canonical groundwater coupling and the existing real multi-cell MODFLOW6 path. Preserve prepared-solve, predictor/corrector, preflight, publication and per-cell ledger semantics. Current canonical is authority.

## Phase 1 paired subset
Use a deterministic stratified production subset, not the full production population. Include RFM inactive columns, active dry columns, active columns that visit the 64/32 transition, and naturally occurring wet 16-panel occupancy if present. Do not manufacture wet occupancy.

Run identical populations with exact fixed-64 and A28_V1. Initial state, forcing, groundwater mapping, coupling schedule, worker configuration and MODFLOW settings must be identical.

## Required evidence
Persist policy version, 64/32/16 evaluation counts, per-column completion and nonlinear diagnostics, per-interval and cumulative groundwater exchange, checkpoint groundwater heads, storage, bottom flux, whole-system mass closure, SWAP wall time, total coupled wall time, worker count and deterministic population ordering.

Band occupancy counters are required before interpreting Phase 1.

## Numerical gates
No A28-only failed column or new mass-closure violation. Coupling publication and ledger semantics must be unchanged. Cumulative coupled exchange relative difference must be at most 0.5 percent, with no unexplained per-cell sign reversal. Use the already accepted groundwater-head tolerance of the selected canonical fixture and record it before execution. Report median, p95, p99 and maximum differences for storage, bottom flux and exchange.

## Performance gate
A28 must reduce measured numerical work and show positive end-to-end runtime benefit on the paired subset. Report panel work from band occupancy, SWAP runtime ratio and total coupled runtime ratio. No fixed speedup is preregistered. A result within timing noise is not demonstrated production value.

## Scaling
Only after Phase 1 passes, move to a larger population on the production parallel path. Production-scale population is the final stage, not the discovery stage.

## Decision boundary
Phase 1 passing permits scaling qualification only. A28 remains explicit opt-in and exact fixed-64 remains the reference/default.
