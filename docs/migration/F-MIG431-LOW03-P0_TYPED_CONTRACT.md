# LOW03-P0 typed resistive-bottom contract

Status: central design decision for bounded implementation, not production admission.
Baseline: 0d44f0195c94a9732c67b5e77f2148912df9bbc8. Sole issued LOW03-P0 branch only.

For bottom_mode=3, bottom_head is external total head in cm in the soil-profile vertical coordinate, bottom_flux is an independent upward-positive extra flux in cm/day. Add bottom_external_resistance_days (default0) and bottom_include_half_cell (default true) to the internal Fortran soil_water_boundary_conditions_t. Other modes require defaults for these new fields and keep previous head/flux semantics. No public C ABI change, serialization or external datum change. Inputs are immutable trial authority, not committed state. No new persistent hydraulic/restart state.

The solver evaluates native q=(bottom_head-hN-zN)/(d/Kb+R)+bottom_flux when half-cell=true, or denominator R alone otherwise. The positive bottom residual diagonal is reciprocal resistance at fixed K, matching B1.11. Reuse existing Richards solve, provider K, geometry and scratch. New scalar resistance and flag are explicit inputs, never legacy globals. Exact zero-R equivalence is bounded to common K and SWKIMPL0.

Validation: finite bounded head [-10000,1000], finite extra flux [-100,100], finite R [0,100000], strictly positive R when no half-cell, positive finite participating K, positive finite conductance/denominator, valid active geometry. Reject singular/nonfinite inputs without a candidate. Mode3 SWKIMPL1, macropores and interface sensitivity are deferred for this first slice. Ordinary/GW mode5 semantics and other admitted modes remain unchanged. No silent tolerance/controller changes.

Mode3 HeadCalc owns candidate qbot; unlike mode5, do not overwrite it using whole-storage closure, which would conceal physical flux errors. Publish native and integrated equation residual from the full active-node vector. Independently recompute storage versus top/bottom/source/sink amounts in tests. Base physical state remains immutable through solve failure/replay. Warm history is scratch only.

Scope is direct typed Reference solver only. Serialized production application/profile must keep rejecting3 until application forcing/proposal/transaction/restart ownership is separately implemented and qualified. P0 is not full SWBOTB3 migration. Date/sine laws and explicit3 are not implemented here. Production admission of this shared solver seam needs preserved existing2/4/5/6/7 and dependency-aware evidence at persisted postimage. Initial gates local; Actions only for persisted qualification when the complete declared gate set is ready.
