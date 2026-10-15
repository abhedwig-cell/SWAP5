# Bounded reactive soil to WOFOST81 daily nitrogen supply

Bounded work unit MC-NUT01-CROP-SUPPLY, baseline canonical
26ddf94e58133acd413c2b2738b873a92f43f1da (merged PR1232). No restart of prior migration.

The accepted WOFOST81 prepare/apply interface already computes crop N demand,
fixation, translocation, organ allocation and senescence. Its old production
transaction satisfies the complete soil request (N unlimited). The B1.11 donor
crop owner uses different fixation semantics and is not a replacement authority.
This successor composes the unchanged WOFOST81 candidate with the accepted
reactive Soil-N owner and actual accepted Full Richards daily trace.

One private coupled state contains one existing reactive soil inventory, one
existing WOFOST81 crop owner and immutable crop configuration/identity. The soil
clock/revision is authoritative for the whole daily event. No second N inventory
or derived persistent Nminer is added. Read-only snapshot copies are tentative.

Order: run real water trial; validate and aggregate its complete carrier; prepare
real WOFOST81 candidate using actual accepted root water and declared potential
transpiration; pass its soil request (kg/ha/day -> kg/m2/day) to the literal B1.11
NH4/NO3 analytical exchange; apply the actual supply to WOFOST81; require identical
soil debit and crop receipt; check whole soil+crop N including external fixation,
gaseous loss, boundary transfers and crop senescence loss; commit water, soil and
crop together. Any failure leaves every committed owner unchanged. No clipping
of an unmatched soil debit or silently unlimited supply is allowed.

The additive optional crop-demand seam in advance_reactive_day leaves its absent
argument operation byte-equivalent. The prior disabled mode remains unchanged;
requesting crop coupling with disabled soil reactions fails closed. WOFOST81 and
B1.11 process formulas, reference MC-NUT01-R1, numerical tolerances and accepted
WOFOST81 fixation remain unchanged.

Bounded configuration: active emerged crop, one complete explicit column, exactly
one day, full prescribed root depth, existing top/pond/macro/SSDI/no-opposing-flow
reactive carrier profile. Prescribed soil temperature remains isothermal. Weather
and root forcing are explicit inputs; no automatic weather/bootstrap, root sink
recalculation from new crop, sow/harvest/rotation, residue return or combined
matrix-plus-N promotion. Senesced crop N is an explicit output pending residue
routing. The juvenile uptake source branch may only publish when actual soil
supply equals the crop receipt within the existing hard budget.

Private existing crop parameter tables have no lossless public snapshot. The new
configuration accepts bounded raw knots/scalars, constructs the unchanged existing
parameter types, and retains exact knots for complete restart identity. It does
not add a second interpolation or crop-rate implementation. Opaque and bounded
same-platform CRC disk restart retain crop cohorts, N ledger, evolution/history,
reference carryover, soil inventories/configuration and real water temporal history.
Wrong clock, identity, configuration, truncated/corrupt/nonfinite/unbalanced input
must publish none of the owners.

Qualification: smallest real soil/crop driver O0/O2 first; literal B1.11 full
exchange oracle and unchanged WOFOST81 request/apply source authority; actual
Richards plus real daily crop growth, limited/ample/exhausted supply, zero root
water, nonzero fixation, boundary inflow/outflow, senescence, rollback/retry,
replay and fresh-process/opaque continuation. Original reactive and mineral
physical drivers execute fresh on a controlled shared build with exact old valid
endpoints. Measure compile/link/native costs; expected crop-only feedback under
15s, full physical composition build about120s plus native UNKNOWN. Select one
full local moving gate (expected1423s) on the stable candidate because the shared
reactive owner and admission dispatch change, under the existing four-level
boundary. Highest low-air remains NOT_SELECTED_POLICY. One PR only.
