# Original prescribed groundwater with chemical transport

**Source reconciliation / confirmed shared CDE receipt defect / not admitted.** Baseline is actual
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
before original assignment, without mutating a rejected state. Original ReadSwap rejects any GWLEVEL above zbotcp(5), explicitly requiring
five unsaturated compartments. The fully prescribed/no-unsaturated-node
HeadCalc branch is therefore outside this original valid-input domain; retain
the original refusal rather than inventing broader support. Preserve signed exchanges and
actual concentration input, all complete native state, chronology and source
input identity. Inspect original groundwater table/cold validation as well.

First target ordinary analytical no-macro chemical profiles with prescribed
levels, the original minimum of five unsaturated compartments, no snow/frost
and original drainage.
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


## Actual shared CDE native/receipt defect

The persisted probe uses an actual current ordinary original-output CDE build,
input and day4checkpoint. Its normal private proposal reports55.46075109597839
mg/cm2 and the actual native SAMPRO is exactly the same. Changing only the
reported total stock and reported rain input by1mg/cm2 returns a private
prepared proposal reporting56.46075109597839mg/cm2, while native SAMPRO remains
55.46075109597839. The reported mass residual is8.167772014289199e-14mg/cm2,
so the unchanged mass guard alone cannot reject this mutually fabricated report.
The accepted external day stays4, the source checkpoint is unchanged, and no
external accepted state is published. Failed/private diagnostic artifacts remain
separate; existing qualified data are not edited or rebound.

`daily_coupling.py` checks the native codec, prefix shape/nonnegative domain and
manifest/receipt identity. Aquifer candidates additionally compare their actual
seven fields and soil stock, but ordinary CDE candidates lack that final native
stock comparison. This is an inherited SWAP5 coupling defect, not an original
SWAP equation defect. Add a source-bound read-only native total-stock check for
all explicit no-macro CDE candidates before returning prepare and again before
acceptance/publication. Keep the existing aquifer validator literal. Read the
actual stored SAMPRO at48+8*(actual_nodes+1); do not reconstruct it by summing
CMSY, whose internal soil-volume representation requires original geometry.
The physical wire, providers, equations and valid trajectories remain unchanged.
Fresh bundles must bind the new consistency policy; no old metadata is rebound.

## Persisted component and initial actual executions

Production1eb1e896a adds a pure stateless reaction component. Its real two-source
compile/link closure passes39 checks under O0/O2 (0.36/0.45seconds compilation,
0.10/0.09seconds execution). Changes to unsaturated trial storage do not change
the reaction; prescribed-tail trial values do not replace prescribed saturation.
Signed tail rates and falling/rising tail storage, below-profile exchange and
invalid shapes/nonfinite inputs are checked. Invalid calls leave outputs intact.

The all-CDE native stock component passes19 actual-wire refusals. Fresh35day
Snow/CDE source pilots pass O0/O2 with four complete cold windows each; the
actual forged receipt is now refused before external prepare in both fresh
builds. No old BUILD or diagnostic checkpoint was rebound.

Production9308430ad actual ten-day within-profile and below-profile CDE pilots
pass on O0/O2 with two complete exact native/user-output cold windows each.
The crossing-level trajectories pass the unchanged water/chemical guards, but
the7to9cold window differs by5.55e-16cm in one bottom-flux receipt on day8;
the final day9 physical rows coincide. Preserve these failed comparisons.
Cold initialization reconstructs hydraulic carry from stored heads. That is
insufficient for exact prescribed-tail inventory/flux continuation, even with
SWHYST0. The successor stores actual h,theta,k,kmean,dimoca,gwl,volact in a
separate typed72byte paired domain plus5*N+4doubles, before optional calendar.
This observes complete original state, adds no process equation or physical
store, preserves the48byte CDE prefix and gives output/on-off distinct codecs.
Validate the entire pending carry before assigning it. Requalify fresh crossing
and fixed-level trajectories; the initial failed reports remain immutable.

Initial pre-compilation failures exposed the public builder's mode1 budget
exclusion and an ambiguous outer/inner HeadCalc declaration anchor; both are
explicitly corrected, with original failed reports retained. Original mode5/8
receipt and all prior source providers remain literal through delegation.
