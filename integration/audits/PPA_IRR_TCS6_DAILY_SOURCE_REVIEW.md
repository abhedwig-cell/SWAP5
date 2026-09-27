# TCS6 daily invocation source review

Status: source inspection, not runtime qualification. Baseline `fe2ac0d00`.

Read the nested `SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP` in the supplied release
archive without modifying it. Raw member SHA256:

- `SWAP/irrigation.f90`: `65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1`
  (exact match with the existing B1.11 irrigation oracle authority).
- `SWAP/swap.f90`: `39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a`
  (release member inspected for invocation context; no whole-snapshot replay claim).

## Observed ordering

`irrigation.f90:395-400` initializes dayfix to 366 under the crop initialization
condition. Task 3 first handles fixed irrigation (`419-435`), then scheduled
time eligibility (`437-449`). The combined gate at `451` requires sw_irrig=1,
schedule=1, no fixed event, crop emergence and the irrigation window. The weekly
increment/reset at `519-531` is inside that gate. Thus dayfix counts eligible
invocations, not every elapsed civil day. Days without a weekly threshold
trigger still reset at seven; ineligible days do not enter that increment.

The optional TCSFIX block at `551-562` subsequently modifies the same dayfix
and selected-event decision. The initial TCS6 runtime route must explicitly
exclude TCSFIX rather than claiming the weekly oracle covers its composition.

`swap.f90:362-385` calls task 3 at day start for sw_multi_swap=0. The other
branch calls task 4 at day start; `532-539` calls task 3 at day end for
sw_multi_swap=1. These are distinct timing contracts. The proposed first route
is explicit standalone day-start input only, not legacy multi-SWAP day-end
management semantics.

## Consequence for proposed ownership

Maintain a last-observed daily ordinal separately from dayfix, but inside the
same committed irrigation carrier. Every accepted explicit daily request,
including an ineligible day, consumes the ordinal once. Only eligible process
evaluation advances dayfix. This permits consecutive calendar validation without
counting ineligible days toward the weekly trigger. Duplicate ordinal suppresses
selection/counter advance; backward or skipped ordinals reject. First ordinal
is explicitly supplied; activation initializes 366. Pending continuation cannot
cause another weekly increment. Rejected hydraulics consume neither ordinal
nor counter. Crop-rotation reset remains a separate future explicit operation.

These are proposed restricted ingestion semantics, not assertions that the
source stores ordinals. Source stores dayfix; the ordinal prevents accidental
duplicate invocation across adaptive substeps and decoded restart in SWAP5.
