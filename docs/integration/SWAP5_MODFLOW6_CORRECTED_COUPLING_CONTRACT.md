# Corrected SWAP5-MODFLOW6 coupling contract

Date: 2026-09-20

Status: **PROPOSED SEMANTIC AUTHORITY, IMPLEMENTATION REPAIR REQUIRED**

This contract is the result of the coupling-semantics reconciliation. It preserves the already qualified transaction and prepared-solve mechanisms but removes legacy SWBOTB configuration from application-level groundwater authority.

## 1. Ownership

### MODFLOW6 owns

- the accepted regional groundwater state and accepted hydraulic head;
- the current groundwater nonlinear iterate inside one prepared solve;
- groundwater-flow equations and MODFLOW-owned storage for the domain assigned to MODFLOW;
- MODFLOW-owned regional/lateral fluxes and any explicitly MODFLOW-owned drainage path.

### SWAP owns

- the committed one-dimensional soil-column state;
- unsaturated and SWAP-represented saturated water storage inside the SWAP column;
- Richards integration, atmospheric boundary processes and root water uptake;
- SWAP-owned drainage when that drainage path is assigned to SWAP;
- trial/candidate state and whole-window water balance for every SWAP replay.

### The coupling layer owns

- the mapping between SWAP tiles and MODFLOW cells;
- the coupling window;
- head datum and any head-transfer operator;
- the predictor response `u/q_u`;
- iteration/convergence policy;
- interface sign/unit conversion;
- accepted transfer ledger and provenance;
- the declaration that prevents overlapping storage and drainage ownership.

The coupling layer does not own either model's accepted physical state.

## 2. State variables are not interchangeable

The following must remain distinct:

- MODFLOW accepted node/cell head;
- MODFLOW current nonlinear iterate;
- SWAP diagnostic phreatic groundwater level;
- SWAP lower-face hydraulic head;
- SWAP lower-face pressure head;
- SWAP native `qbot`;
- predictor `q_u`;
- realized corrector whole-window bottom exchange;
- accepted coupled transfer.

No adapter may rename one of these into another without an explicit transform and authority statement.

## 3. Coupling plane and head transfer

The physical/computational coupling condition is applied at the fixed lower face of the SWAP column.

The current implementation uses the identity head-transfer law:

`H_SW,bottom = H_MF,node`.

This may be admitted for an application only when its vertical conceptualization justifies using the selected MODFLOW node head as the SWAP lower-face hydraulic condition.

A future application may instead require a transfer operator or resistance:

`H_SW,bottom = T_H(H_MF, geometry, resistance, ...)`.

The topology/application contract must own that choice. It must not be hidden in `bottom_mode`.

The SWAP diagnostic groundwater level remains a derived internal state and is not required to equal the MODFLOW node head.

## 4. Predictor contract

At an accepted coupling origin, SWAP may be driven by a prescribed lower-boundary flux to construct the finite-window response.

For each tile the predictor may return:

- predictor `qbot`;
- lower-face head at the end of the window;
- response derivative;
- dimensionless response/storage coefficient `u`;
- predictor exchange/source quantity `q_u`.

The currently admitted relation is:

`u = DeltaT / (dH_bottom/dqbot)`

and

`q_u = u (H_end-H_start)/DeltaT - qbot`

in the pinned native conventions.

These quantities are response information for the coupled groundwater solve. They are not accepted interface history.

## 5. Groundwater solve contract

F-GC33 converts the aggregated response to a head-dependent MODFLOW package term.

One MODFLOW prepared solve is used per coupling window:

- `XOLD` stays the accepted groundwater origin;
- `X` is the current iterate;
- the affine coupling term may be updated between MODFLOW iterations.

This ownership from F-GC38/F-GC39 remains valid.

## 6. SWAP corrector/finalization contract

A MODFLOW trial head may be used to run a same-origin SWAP corrector.

The SWAP participant receives a **coupled-interface trial head**, not an application-level legacy lower-boundary selector.

A concrete adapter may implement that trial by converting hydraulic head to a mode-5 lower-face pressure head. In that case:

- mode 5 is an internal realization;
- the adapter is hidden behind an explicit coupled-groundwater participant contract;
- the application does not need to declare itself a standalone SWBOTB=5 profile;
- production process admission must be governed by coupled-process capability, not by standalone mode-5 profile identity.

## 7. Realized exchange and convergence

For a trial head `H_k`, the SWAP corrector returns the whole-window bottom exchange `q_SWAP(H_k)`.

The MODFLOW package provides its current coupling flux `q_MF(H_k)`.

The outer residual is the difference under one documented sign convention. Coupled acceptance requires:

- MODFLOW nonlinear convergence;
- per-cell interface-flux closure within the governed coupling criterion;
- successful SWAP trial/candidate validation;
- complete component mass accounting.

If not converged, the SWAP candidate is discarded and the affine groundwater term may be re-anchored at the latest realized SWAP response without changing accepted history.

## 8. Accepted mass contract

Predictor `q_u` is not accepted mass merely because it was supplied to MODFLOW.

Only the converged/finalized coupling transfer is authoritative.

At coupled acceptance:

- the MODFLOW coupling-package transfer and SWAP realized whole-window lower-face transfer must agree within the accepted coupling criterion;
- the accepted interface ledger publishes that one transfer exactly once;
- rejected predictor/corrector work contributes zero authoritative transfer.

For the combined SWAP plus MODFLOW control volume, the accepted interface transfer is internal and cancels. It must not also be counted as an external system loss.

## 9. Root uptake

Root water uptake remains a SWAP process.

It affects SWAP storage and therefore can alter `qbot`, `u`, `q_u` and the head-driven corrector response.

Its presence is not a semantic reason to reject groundwater coupling. If the chosen response algorithm requires derivatives, derivative coverage or a whole-trajectory finite-difference route must be separately admitted.

## 10. Drainage

Every physical drainage path must have exactly one process owner.

Allowed conceptual choices include:

- **SWAP-owned drainage**: SWAP computes the drainage sink; the same drain is absent from MODFLOW/surface-water boundary packages. Its effect is naturally present in the SWAP predictor/corrector response.
- **MODFLOW-owned drainage**: MODFLOW or its surface-water coupling computes the drain discharge; the same path is disabled in SWAP.
- **explicit partitioned drainage**: only when an independently documented partition prevents overlap.

The coupling application topology must declare the choice. Legacy SWBOTB=5 does not decide it.

## 11. Storage partition and blocker

The SWAP-derived `u` is a head-response coefficient and enters the MODFLOW boundary slope as `u/DeltaT`. It is storage-like.

MODFLOW STO independently represents groundwater storage in its cells.

A realistic application must therefore declare a non-overlapping storage partition or a mathematically justified overlap correction. At minimum the contract must state:

- what vertical/physical storage volume contributes to SWAP-derived `u`;
- what storage volume is represented by MODFLOW STO;
- whether the two domains overlap;
- how overlap, if any, is removed from the assembled groundwater equation.

The current production topology and bootstrap do not contain this authority. The existing live tests with nonzero STO demonstrate numerical composition only.

**This is a real scientific/architectural authority blocker.** Broad production repair must not proceed by merely deleting the mode-5 guard while leaving storage ownership implicit.

## 12. Application configuration

A coupled application should select a semantic profile such as:

`groundwater_coupling = modflow6_two_way`

with explicit:

- tile-to-cell mapping;
- head datum and transfer law;
- storage partition;
- drainage ownership;
- process capability requirements;
- coupling-window policy.

Legacy `bottom_mode` may still exist inside a standalone SWAP configuration and inside a concrete internal materializer, but it is not the external groundwater authority.

## 13. Publication and durability

The admitted publication ordering and failure classes remain unchanged unless a separate transaction workunit changes them.

The audit does not reopen F-GC38/F-GC41/F-GC49 publication semantics.

## 14. Repair boundary

Implementation may proceed only in bounded slices:

1. detach coupled-groundwater application identity from `bottom_mode==5`;
2. retain mode-5 conversion behind an internal trial-head adapter;
3. add explicit head-transfer/datum authority to application topology;
4. establish storage-partition authority before realistic production admission;
5. establish drainage-owner authority before enabling authentic drainage;
6. admit root uptake/process coverage independently from legacy lower-boundary identity;
7. requalify affected F-GC and PUB-GC evidence.

No application-envelope widening is justified solely to make PUB-GC E7 pass.
