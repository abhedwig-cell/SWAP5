# Native SNM definition labels and event positions

Status: implementation candidate; no full HIST or mastercoverage promotion.
Baseline: `88df92436b84e693dfd4c0801bfb2fc19ac0de08`.

The pinned original management_soil lines120 and130 read material definition
labels through rdainr with bounds1..20, then overwrite the same MatNum array
with iMat event row positions. Original amendments uses that position directly.
Definition labels are not lookup keys and need not be contiguous or unique.
Native normalization validates each original label in1..20, then emits its row
position into the existing bounded export parser. Event iMat stays untouched.
The modern export contract retains contiguous IDs and its negative tests.
No second parser, inventory or physical owner is introduced.

Selected gates: original unmodified TTUTIL overwrite/row-selection witness;
current native suite plus noncontiguous, duplicate, reversed and invalid labels
with physical error lines and atomic rejection; unchanged modern export suite;
fresh actual124-day and three730-day production profiles O0/O2 with all existing
transition restarts and rollback, byte comparison against admitted endpoints.
Expected direct cost under1minute; full selected production closure about10minutes.
Only the native lexical-to-existing-table seam changes. Soil-N physics, retained
state, thermals, TCS6, solver and restart implementation are unchanged. Their
existing qualifications remain applicable after exact dependency inspection;
this is not permission to ignore source-bound guard checks.

The admitted original archive must remain immutable. A registered supplemental
receipt must identify the exact old input file, exact current postimage, fresh
parser/original/production executions and original endpoint bytes before an
owning guard can inherit retained evidence whose compile inventory included the
old parser. Missing receipt, unregistered drift, failed runs or old fixture
changes reject admission. No general source projection is permitted.

## Physical boundary remains separate

The admitted surface solute owner uses its matrix companion pond_mass. The
aggregate Soil-N owner used by WOFOST has NH4/NO3 and organic inventories but
no qualified dissolved surface-N inventory. Surface age stores carry cm day,
not nitrogen; they cannot be reused as a nitrogen store. Existing persistent
solute/surface contracts explicitly exclude simultaneous N companions. Thus
source-faithful labels do not resolve the gross/net counterexample. The
[executed carrier witness](MC_NUT01_HIST_GROSS_NET_BLOCKER_20261018.md) remains
an independent scientific completion limit, not a parser regression.

The reviewed alternatives for a next physical contract are literal historical
gross loading of aggregate Soil-N, including the original ponding ambiguity,
or a corrected B1 surface-N control volume inside existing ownership. The
corrected route would retain separate surface NH4/NO3, move only infiltrated
N to soil, export runoff N, retain solute on evaporation and serialize the
remaining inventory. No such new physical semantics are admitted by this label
patch. Full historical migration and its mastercoverage are still false.
