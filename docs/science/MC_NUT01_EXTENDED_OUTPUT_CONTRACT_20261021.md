# MC-NUT01 extended crop output component

Status: proposed bounded diagnostic component; no full MC-NUT01 admission.
Baseline: `48a59396d7e7745cf99ad4b1003cd84c946e3e3f`.
Owner: existing MC-NUT01-HIST-COMPLETE record.

The original B1.11 `management_soil.f90` task6 accumulates eight output
quantities in kg/ha, writes an interval row only for `floutput`, updates eight
concentration extrema, then clears the interval accumulator. NH4/NO3 uptake
arrives in kg/m2 and is multiplied by1e4. Root/leaf/stem/storage residue DM/N
arrives in kg/ha. P is exactly the historical0.1*N diagnostic, not phosphorus
physics. Surface residues sum leaf, stem and storage; bottom residues are root.
The original residue inputs are the saved `_1` values *before* task6 replaces
them with current interface values. They must not silently be replaced with
current-day mortality, pending incorporation or cumulative crop loss.

This component accepts those explicitly identified saved values and accepted
interval uptake. It does not derive them from current crop state or change the
historical ordering. Each observation covers one strictly consecutive `[t0,t1]`;
repeated, skipped and overlapping intervals reject atomically. The caller must
publish only after physical acceptance. The observer has no physical state,
process equations, water/soil/crop owner, file unit, global variable or automatic
hook. Value assignment checkpoints the complete diagnostic continuation.
A rejected physical trial must not be observed by the caller.

A report returns a row and clears only its interval totals. Extrema update only
on report and for the original DM threshold1e-6kg/ha. Initial minima1/maxima0
are preserved even if no residue reaches threshold. Initialization is explicit.
Inputs are bounded to finite nonnegative uptake/residue values <=1e6, with
N<=DM per organ; signed numerical noise is outside this component. Overflow
is excluded by a1e12 interval-total bound. This restriction is not a new
historical-domain acceptance rule. Rejected observer calls leave state unchanged.

The adapter formats the original three header lines, eight-value row and
final extrema line with the literal original edit descriptors. It does not own
file creation, complete-file final rewrite, durable crash publication or
coupled physical/diagnostic restart files. The native `.TRUE.` flag stays
rejected until those application seams and actual coupled saved-value timing
have been implemented and qualified. Full original multiyear trajectories,
active-crop donor allocation and snow/persistent surface remain open.

Selected validation: local GNU O0/O2, original source-extracted task6 arithmetic,
report/reset/minmax and exact formatted rows; delayed residue counterexample,
multiple report schedules, independent value-state continuation and atomic
invalid/replay/gap/overlap rejection. No shared provider changes; existing
source/evidence owners remain byte-identical. Full F-CI, low-air, RossFast and
hosted Actions are not selected for this isolated diagnostic component.
Invariants2,3,7,13,23: diagnostics observe; physical acceptance and mass do not change.
