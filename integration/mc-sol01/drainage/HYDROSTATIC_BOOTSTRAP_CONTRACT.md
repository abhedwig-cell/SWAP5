# Original hydrostatic water initialization

HIST-INTEGRATION01 successor of a44c346216b67a2b9db4acbcfa18c229442648a9.
The programme owner requests several concrete next steps after scoped closure.
Select SWINCO2 source water initialization, existing numeric heat composition
and exact file restart. This does not reopen MC-NUT01/MC-SOL01 closure.

Original archived readswap reads GWLI [-10000,1000] cm. Original soilwater task1
sets GWL=GWLI, pond=max(GWL,0), h(i)=GWL-z(i). Except SWBOTB8 it rejects a
groundwater level within1e-4 cm of the column bottom. SWBOTB1 requires a time
table and is excluded. Bottom switches2..8 here select only initialization
checks, never native bottom/drainage orchestration. Explicit application forcing
and all chemistry exclusions remain. No solver equation or restart schema changes.

Extend the existing water input routine with optional source-pond output.
Existing five-argument SWINCO1 callers preserve exact old behavior. A SWINCO2
caller must receive the pond output so surface inventory cannot be lost.
The file caller refuses nonzero namelist pond overrides in SWINCO2, then takes
the source pond. Its solute surface stock remains explicit existing input.
SWINCO1 retains its existing unsaturated HTB and namelist pond contracts.
The source groundwater output also initializes the actual physical water state;
it must never retain the file application's old constant -2 cm. Actual file
stdout records this initialization, and each full/split/resumed run must match
the source GWLI exactly. SWINCO1 retains its original -2 cm state convention.

Original Andelst stores SWBOTB in a separate BBC file. A component caller may
pass that explicitly resolved original bottom mode through the optional input;
conflicting inline and supplied modes reject. No hidden companion-file read is
added to the existing file launcher. Thus the original SWP+BBC pair qualifies
component initialization, but external-BBC whole application staging remains
outside this change. Missing inline/resolved bottom mode fails closed.

The original SWP also contains KSATEXM, outside the existing water adapter's
hydraulic envelope. Its112-node source component test therefore reads original
grid/GWLI/porosity using TTUTIL and calls the same real hydrostatic initializer
as the adapter, followed by the real heat importer. It does not claim original
hydraulic parameter import. Full original importer rejection is retained.

The real fully saturated surface-level trial rejects at the unchanged water
owner (water status2). Do not change solver policy to admit it. The file adapter
therefore requires at least one unsaturated node for SWINCO2 and rejects a
fully saturated starting column before constructing accepted owners. Original
zero/positive GWLI and source pond are qualified as initialization components
only, not file executions. Retain this concrete failed trial as evidence.

Affected invariants2/3/7/13/21/23/25/29: conservative initial inventory,
rejected input before owner creation, rollback and exact whole-state restart.
Qualify original112-node Andelst water/heat input mapping, source arithmetic,
below/intersecting/surface/above-surface water levels, original bottom exception,
invalid input, actual water/heat/solute file execution and separate process restart.
Reuse unchanged providers from checked O0/O2 builds, rebuilding changed input
module and main. Expected total selected runtime<250s; fresh full FCI, highest
low-air, RossFast and full original macro/crop application are not selected.
Old thermal/source proofs retain dated identities; current SWINCO1 application
artifacts must match the exact prior executables. No cross-executable restart
compatibility is asserted by this work unit.
