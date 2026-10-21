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


## Accepted-day binding successor

The new observation adapter receives before/after **committed** water and crop/soil
owners plus the real successful senescence joint receipt. It checks all nested
status codes, matching water/chemical clocks, advancing hydraulic revision and
one-day execution. Harvested/retired crop states are excluded. Before-state
pending root/leaf/stem residues are the saved previous-day diagnostic values;
storage-organ residue is zero in this bounded senescence route. Actual integrated
NH4/NO3 crop debits come from the completed soil-exchange receipt. Biological
fixation and new end-of-day mortality are not substituted for these terms.
The physical owners are intent-in; the existing observer publishes its own
state only on success. Rejected trials, stale clocks and replay must not advance
its totals, extrema or clock. A failed observation does not retroactively undo
physical publication; application orchestration must stage the observer with
physical state before external publication when enabling automatic output.

Explicit reconstruction validates all17 diagnostic continuation values before
publishing them. This is a same-platform value contract, not a new joint disk
format. Complete-file I/O, crash-safe joint physical/diagnostic generations and
native `.TRUE.` activation remain outside this successor.

Selection: fresh O0/O2 closure for the existing two-day actual Richards,
retained-residue/N driver with added accepted observer calls. Existing literal
chemistry, crop supply, balances, rejection, harvest and physical restart
assertions stay active. The full730-day matrix is not selected: no existing
physical provider changes. Expected closure cost under five minutes per opt;
measure actual compile/link/native costs. Retain failed executions.

## Complete CSV exporter

The POSIX exporter formats every supplied accepted row before touching disk,
then writes headers, final extrema and all rows to a new temporary file in the
same directory. A successful close precedes atomic rename over the destination.
Invalid rows, duplicate/nonincreasing date strings and missing directories
reject. It publishes a complete generation instead of appending tentative rows.
Date checking is the existing ten-character ISO syntax/lexical contract, not a
full calendar validator. The caller owns row-history identity and accepted-state
association. This adapter alone is not a combined physical restart generation,
does not guarantee durability after power loss, and does not enable native input.

The generated joint qualification driver explicitly uses64MiB stack space.
The first local8MiB execution failed with SIGSEGV before diagnostic output; the
same compiled O0 executable passed with64MiB. The successful compile prefix is
reused only through identical commands; the failed native event and raw streams
are retained separately. This is a test resource requirement, not evidence of
physical failure or a production memory bound. The earlier linker failure from
a relocated compiler missing libgomp.spec is also retained, not counted as PASS.

## Local qualification result

The successor passes actual GNU13.3 O0/O2 two-day Richards/crop/N execution,
original literal chemistry and crop/harvest/rollback assertions, and independent
process continuation of physical state and17 diagnostic values. A nonreport
first day carries actual soil uptake forward; the second day's report uses
previous-day root/leaf/stem residue values. Biological fixation is excluded.
Rejected receipts, unchanged physical state, partial days, repeated reports and
invalid continuation values do not modify diagnostic authority.

The complete CSV exporter passes direct O0/O2 checks and is additionally called
with the actual model-produced accepted row. Fresh-process and O0/O2 physical,
diagnostic and CSV endpoints match exactly. Physical endpoint bytes are equal
to the coupled observer proof before the CSV exporter was linked. All327 pinned
provider objects per optimization are hashed before and after the additive
CSV/driver relink. No production object is silently inherited without identity.

Measured successful closure costs: compilation221.99s, link0.70s, actual native
execution1.83s and accepted atmospheric trace0.004s across both optimizations.
The original8MiB failure and missing-libgomp relocation attempt remain failures.
Direct original-source output checks still pass2721 checks/216 rows per opt;
all9 deliberately changed components compile and fail native assertions.

This qualifies only the stated local observation/export composition. PR1358
remains draft. The fixture's separate diagnostic value file is deliberately
not claimed as a crash-safe joint checkpoint. Automatic historical `.TRUE.`
activation, complete run orchestration and atomic combined physical/diagnostic
restart publication remain open, as does full MC-NUT01 migration.
