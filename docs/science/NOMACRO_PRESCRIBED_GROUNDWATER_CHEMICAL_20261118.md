# Original prescribed groundwater with chemical transport

**Source reconciliation / not implemented or admitted.** Baseline is actual
canonicala787476a0f3db2490e75ff18afea097b82476332 after PR1731/1732. Its source
and metadata merge parents, full qualified trees and detached owners pass.
Historical closure stays PARTIAL, whole science NOT_QUALIFIED, fixed RC3 unchanged.

## Actual source blocker and independent boundary contract

`experimental_project.py` rejects SWSOLU1/SWBOTB1 because the independent trial
boundary receipt is missing. `hybrid_step_budget.f90` explicitly excludes mode1;
the existing immutable `lower_boundary_receipt.py` covers modes5/8 only. Removing
the selector refusal alone is invalid and would hit the unsupported trial path.

Original HeadCalc samples actual prescribed `gwlinp`, chooses its actual active
NN and imposes a saturated tail. With groundwater below the profile it computes
the same actual Darcy bottom gradient as its fixed-head branch. With groundwater
inside the profile the actual Darcy interface is at NN+1 and the known saturated
tail contributes its prescribed storage change and original drain/root/direct
source rates. Original HeadCalc later constructs its complete qv/qbot from the
whole storage recurrence. That reconstructed whole-column value cannot serve as
an independent unsaturated trial input.

Reconcile a read-only constraint-reaction receipt from the actual original Darcy
interface and prescribed tail, without changing original equations or the
accepted Full Richards solver. The trial stock must use the prescribed tail
before original assignment, without mutating a rejected state. The special
fully prescribed/no-unsaturated-node branch needs an explicit source contract;
do not silently accept an unvalidated branch. Preserve signed exchanges and
actual concentration input, all complete native state, chronology and source
input identity. Inspect original groundwater table/cold validation as well.

First target ordinary analytical no-macro chemical profiles with prescribed
levels and at least one unsaturated node, no snow/frost and original drainage.
Other combinations remain separate unless source dependencies and executions
support them. Inspect actual CDE native/receipt consistency before extending
external candidates; a demonstrated shared defect must be repaired explicitly,
not presumed or hidden by a new boundary. Preserve every inactive route by
literal source delegation and immutable qualified evidence.

## Execution contract

Persist before compiling. Use a small real production reaction component with
explicit signed flux/storage inputs and measured closure, then actual O0/O2
below/within-profile and node-crossing/signed chemical pilots. Never calculate
the trial boundary by closing the same candidate total water residual. Require
unchanged1e-10cm water and1e-10mg/cm2 chemical guards, native/rollback/input refusal,
full/year/cold/terminal contexts and independent public commands on Windows and
Ubuntu. Use actual original or preceding-canonical controls and distinguish
legacy defects from new physics. Bind production, raw artifacts and semantics
in a registered successor owner; admit only actual canonical parents/full tree
and detached owner, including metadata admission, then continue the inventory.
No general MODFLOW, alternative solver or active-macro work is authorized here.

Affected invariants:3,4,7,13,21,23,30. No tolerance relaxation or implicit fallback.
