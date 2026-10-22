# MC-NUT01 extended crop output component

Status: bounded explicit daily output/restart application canonically admitted
through PR1358; full MC-NUT01 remains open.
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

At this intermediate checkpoint only the observation/export composition was
qualified, and PR1358 was still draft. Its separate diagnostic file was not a
crash-safe joint checkpoint. The joint-generation successor below subsequently
closed that persistence seam and was canonically admitted. Native `.TRUE.`
activation and full historical orchestration remain open.

## Joint generation and automatic-day successor contract

Development baseline: PR1358 head28ace73b; concurrent canonicala737c605 adds only performance
research files, with every scientific provider and prior output proof unchanged.

A new same-platform POSIX envelope stores the existing validated physical
restart bytes, all17 diagnostic continuation values and all raw accepted
report rows/dates in one CRC32-protected generation. The existing physical
restart reader remains the identity/state authority; its format is unchanged.
Sizes, bounds, row formatting/order, diagnostic reconstruction and equal physical/
diagnostic clocks are checked before publication/restoration. Heat is excluded.
Reads stage all physical, diagnostic and reporting state, then publish together.
Writers create a new same-directory generation, close and fsync it before
rename. A process killed before rename leaves the old generation; after rename
it leaves the complete new generation. File replacement is serialized per path;
concurrent publishers to one path are outside this contract.

The explicit output-day application stages the existing actual senescence day,
observes its accepted candidate, stages reporting history, writes the complete
joint generation, and only then publishes caller memory. A failure before file
replacement leaves the original caller state and previous checkpoint unchanged.
A separate CSV is a reproducible view of the joint generation and is not part
of the checkpoint authority. A CSV-export failure does not invalidate a saved
model generation. Native `.TRUE.` project parsing and unqualified harvest/
rotation/negative-donor routes are outside this bounded explicit application.

Selected verification reuses only unchanged provider objects identified by the
preceding exact-source proof. New bundle/application providers and drivers compile
fresh O0/O2. Actual uninterrupted/fresh-process days, diagnostic and row history,
CRC/truncation/semantic/identity negatives, failed publication, and SIGKILL at
pre/post-rename boundaries govern the new claim. No unrelated physical campaign.

## Joint-generation local result

The final actual O0/O2 application passes two-day physical/diagnostic/reporting
continuation after both separate first-day files are removed. Its automatically
saved model bytes equal the original ordinary day; physical endpoints, complete
report history and CSV files remain exact across optimization and fresh process.
Four owned subprocesses are stopped by a test-only preload at the selected
rename, then killed with SIGKILL. Before rename the old generation reconstructs;
after rename the complete new generation reconstructs. The production adapters
contain no environment-controlled crash hook.

Fourteen invalid generations per optimization reject without changing an
already valid caller state. They include CRC, truncation, repaired-CRC malformed
metadata/values/date/history, and wrong crop identity. Report-derived extrema
must match the saved diagnostic extrema. Missing publication directories leave
all caller authority unchanged. A later CSV-only failure returns a distinct
VIEW_FAILED status while retaining the already saved and published model state;
the CSV can be regenerated from that checkpoint.

Raw failed development attempts are retained: initial restore passed a ready
inner target to the existing blank-target-only physical decoder; a following
attempt exposed a zero-length CHARACTER constructor. Both are corrected in the
final postimage, without changes to the original decoder or physical model.
Final measured costs across O0/O2: new providers4.53s, drivers24.95s, linking0.33s,
normal native2.39s and fresh native0.33s. Earlier successful327-provider object
closures are reused only with before/after identity checks.

The explicit application and joint persistence route are locally qualified for
the declared nonharvested heat-off daily scenario. The local source/evidence guard was initially an additional review artifact.
The later exact additive handoff below supersedes that admission limitation.
Native `.TRUE.` parsing remains unchanged; no full historical MC-NUT01 closure
is claimed.


## Exact preservation handoff

Current owning entrypoints delegate to the new bounded output owner through
additive hooks. Every preceding owner statement is retained byte-for-byte,
verified by exact source projection. The complete scientific delta is pinned
and foreign additions reject. Every executed old/new provider is source-bound.
The original current-canonical owner and neutral research entrypoints execute
unchanged at exact predecessora737c605: full owning qualification, all27 original
controls, research qualification and all13 research controls pass. The new
14-control source/evidence guard also passes through the current owning entrypoint.
The immutable predecessor receipt is versioned; it is not a substituted native
PASS for changed code. Model and physical application providers remain unchanged.

The bounded explicit heat-off/nonharvested daily application, complete generation
and CSV view are qualified for canonical admission. The existing native project
flag is still rejected because it promises a wider historical execution domain.
Full MC-NUT01 master dispositions remain open.


Actual admission: PR1358, canonical49bba843210b49c58c991a23f67f52888895582f.
The published/local qualified tree is identical. The actual merge additionally
retains the concurrent PR1360 performance-metadata receipt; every qualified
scientific source and evidence file is exact. Owning qualification and all14 new
controls pass on the actual merge. The versioned admission receipt records this
distinction and the inherited27/13 controls. No hosted numerical PASS is inferred
from the deliberately empty workflow lookup. All full master dispositions remain
unchanged; native `.TRUE.` activation and complete MC-NUT01 stay open.

## Coverage reconciliation,22 October2026

Existing master PR1072 receipt `32e76c66f2ca3b5cae95e89bb0b947f5d88a9f8a` records PR1358
in the nine existing MC-NUT01 rows and their active queue. The [reconciliation
proof](https://github.com/abhedwig-cell/SWAP5/blob/32e76c66f2ca3b5cae95e89bb0b947f5d88a9f8a/integration/audits/MC_NUT01_OUTPUT_MASTER_RECONCILIATION_20261022.json)
passes all nine original bounded-reachability checks, historical source/census
integrity and20 inheritance controls.234 other rows, all243 dispositions, the
summary, previous bounded receipts and all other queues are exact. Every full
NUT row stays ACTIVE_MIGRATION; no whole-master scientific PASS is asserted.

At canonical `46ad96ee2cc65fdee48a1f3b47e3290f86f7ffd6`, the original joint-output
capsule validates again, including14 invalids per optimization and four crash
boundaries. The current composed owner and21 corruption controls also pass.
These checks validate persisted evidence and dependency identity; no fresh
numerical execution or new hosted qualification is claimed. Documentation
source checks and strict MkDocs builds pass on both records.

## Explicit native startup successor,22 October2026

The [native startup contract](MC_NUT01_NATIVE_OUTPUT_START_20261022.md) qualifies
TRUE through a new explicit output-aware startup API, followed by this admitted
output-day/generation route. Default callers continue to reject TRUE. Fresh
O0/O2 native input, actual TRUE/FALSE physical equivalence, year-boundary reports
and independent-process joint continuation pass. This resolves that bounded
startup seam; general/default historical dispatch and heat/harvest/rotation
output are not added. Admission is recorded in the existing HIST-COMPLETE child.
