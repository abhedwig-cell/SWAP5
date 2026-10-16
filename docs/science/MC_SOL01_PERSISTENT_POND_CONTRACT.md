# MC-SOL01 persistent surface successor

Status: implementation contract, not canonical admission. Baseline
`87bc1b1bc0e33d5df9cc460c56f7773209d40931`. Recovery remains the existing
`integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json`.

This extends the existing surface owner, rather than replacing its admitted
zero-pond application. Water remains owned by Richards. Surface solute owns one
mass pool (mg/cm2), also retained when water depth is zero. Its depth (cm) is a
read-only mirror of accepted hydraulic storage. Each consumed water substep must
provide exact time, begin/end pond storage and actual downward top flux. Require
`pond_end - pond_begin = (rain + irrigation + qtop) * dt` within the existing
absolute 1e-10 cm water budget. No inferred runoff or evaporation is permitted.

Reuse the immutable B1.11 `SWAP/solute.f90` lines346..355 and the existing
`evaluate_b111_pond_solute_exchange` operator. At qtop >= -1e-6 cm/day its historical
cutoff retains surface mass even if water enters soil; this is explicit source
semantics, not a claim of universal physical accuracy. Upward top flow is excluded.
Prescribed dry deposition (mg/cm2/day) adds mass before mixing, including on a dry
surface, and is separately booked as external input. This is an explicit new
forcing contract, not an invented legacy deposition formula or parser. Rain and
irrigation concentrations are mg/cm3, rates cm/day. All inputs are finite and
bounded before arithmetic; invalid trials leave committed state unchanged.

The persistent state carries clock and revision. Consumption is exactly once
through exact clock continuity, including after restart; a rejected substep cannot
advance either. Parameter/source identity must not be confused with state revision.
Depth, mass, clock and revision must all be retained with exact accepted bits.
The matrix owns dissolved/sorbed soil amounts; surface mass must have exactly one
owner and may never be dropped by the existing matrix-only codec. Joint restart
requires both owners and the existing hydraulic restart to reconstruct atomically.

The shared trace extension may add begin/end pond storage and availability, populated
only from the real request base and converged candidate. It changes observation
metadata only, not physical state, solver equations, fluxes or acceptance policy.
Existing consumers retain their current bounded eligibility. No caller may infer
availability from default zero fields or forge a pond trace from a final endpoint.

Affected invariants:3,4,7,9,13,21,22,25,27,29,30. Select real production O0/O2 leaf
drivers with independent literal source extraction; water/mass closure; dry/wet
retention, remobilization, source units, input nonmutation, replay, reject/retry and
malformed restart. Then actual Richards/matrix/pond composition and fresh-process
native restart. Reconcile shared trace and incumbent admission guards on a stable
candidate before merge. No full moving or unrelated solver gate follows merely
from new valid forcing values. Aquifer remains rejected. Runoff, evaporation,
macropores, nonlinear surface composition and default activation remain outside
this bounded contract; no full historical capability promotion is implied.
