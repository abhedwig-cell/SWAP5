# MC-MET01: typed RAINTB and guarded authentic production

Status: delegated bounded application decision before implementation; numerical
qualification and canonical admission pending. Baseline `c545077ab2d2839007a4ac202f7896575d0ad9ba`.
Owning roles: existing REGIE/PPA/RT with MC-MET01; MC-CROP01 contracts remain fixed.
User delegated implementation of the canonical pilot on 12 October 2026.

The optional `file_weather_swrain=1` profile accepts a validated immutable typed
RAINTB configuration (strictly increasing day-of-year knots, finite positive
cm/day intensities, constant endpoint extrapolation). Fully populated tables
only; historical partly filled sentinels and file grammar are not this input API.
Default mode0 remains the existing uniform-day profile. Mode1 is root-free only,
with the existing AIR/no-snow/default-MVG bottom7 weather envelope.

Authenticated B1.11 MOD_meteo lines643-644/657/677-686/694-696 determine mm→cm,
strict rain>1e-8mm, AFGEN day-of-year and pulse duration/rate. AFGEN arithmetic
and endpoint order are retained for valid finite full tables. Tiny rain at or
below threshold supplies zero, as the source event schedule does. Invalid table,
unrepresentable positive pulse endpoint or invalid intervals fail closed.

The existing guarded weather entry resolves pulse segments before calling its
incumbent physical interval body. Each segment has a positive interval entirely
within the authenticated day and one constant rain rate. A request spanning the
pulse boundary executes at most two segments; it returns one column-result per
attempted segment in chronological order in this opt-in profile. This additive
result-array meaning applies only to mode1. A failure of the second segment
retains the previously completed physical/weather prefix; the failed segment
publishes neither internally accepted partial physics nor accepted weather-window
progress. Overall status reports failure and segment results remain distinguishable.
Default mode0 output/result shape stays identical.

No externally set private active flag, second transaction/weather owner, new
time reset, zero interval, fabricated crop receipt or precipitation scalar that
pretends to be authentic input is permitted. Segment receipt and accepted-window
publication use the existing F-KT and weather-window owners. The derived schedule
has no independent mutable progress state; committed soil time plus immutable
record/table reconstruct the next segment. Existing joint continuation retains
the complete table in its configuration. Mode1 restore additionally requires an
expected table that matches all validated knots/values before any owner publishes;
wrong/missing table fails without initializing crop or application.

Qualification: independently compiled literal source/AFGEN oracle including
threshold, leap calendar, knots, capped pulse and invalid inputs; actual authentic
wet/dry/wet production, pulse/off/next-day, O0/O2 full vectors and restart inside
and at pulse boundaries; duplicate, foreign record, changed table, failed interval
and retained-prefix retry. Preserve incumbent uniform/crop/root/thermal trajectories,
complete affected highest frost and current Full Richards/F-CI owner gates with
unchanged assertions/tolerances. A new exact-source successor may recognize only
the independently qualified precise postimage; every unknown mutation fails closed.

Typed rainfall distribution within this bounded application is the admission
claim; parser, rooted rainfall, interception, detailed weather, broad seasonal
accuracy, external disk codec and full MC-MET01 remain outside it. Master disposition
can close only the exact claim it requires; otherwise record bounded reachability
and retain ACTIVE. All raw failures and immutable qualification lineage remain.

## Bounded source claim

The existing admitted Gregorian file-weather calendar is reused. The literal
oracle proves AFGEN and pulse arithmetic for supplied day-of-year, while decoded
leap/century/year fixtures prove the current calendar binding. This is not a new
claim of equivalence for the external legacy dtleap/date library. Fully populated
typed tables and the tested BASE/AIR profile are qualified separately from
legacy file grammar, partly filled sentinels and near-midnight event-array gap
coalescing. Those wider source envelopes remain explicit follow-up work; a
bounded production admission alone must not promote complete SWRAIN1 coverage.

## Proposed legacy partly filled table successor (2026-10-14)

This **candidate**, on `work/modular-migration-pilot-20261014` from canonical
`c591205c5e03f1c96c6488eb53c562265f749556`, adds
`construct_swap_raintb_legacy_table(flat, table, status)` to the existing weather
adapter. It closes one previously open input representation within the bounded
root-free RAINTB route; it does not claim full SWRAIN1 or legacy file parsing.
Recovery and measurements are in the existing `MC_MET01_STATUS.json`, field
`legacy_table_modular_pilot_20261014`. Existing admitted claims above are retained.

The even-length real64 array alternates day-of-year and intensity in cm/day.
As in authenticated B1.11 `functions.f90` AFGEN, the first descending abscissa
terminates the active prefix. Its ordinate and all following slots are ignored,
including unconsumed nonfinite data. Consumed abscissae must be finite; active
knots must be strictly increasing in 1..366 and active intensities finite and
positive. Duplicate active knots, odd/incomplete arrays and invalid active values
fail with an unready output. Prefix normalization calls the existing constructor;
all interpolation, threshold, pulse and weather physics remain its existing code.
No input mutation, new state, progress clock, restart format or numerical policy.
Equivalent full and partly filled arrays produce identical existing table identity,
so the admitted joint continuation comparison can use the existing owner.

The standalone Fortran driver has one production provider, plus itself, and calls
that real adapter and pulse resolver. A literal independently compiled B1.11
AFGEN excerpt and the three source rainfall statements supply the oracle.
Only CRLF and trailing whitespace are normalized in the derived test excerpt;
the archive bytes and member hashes remain fixed. An altered oracle is rejected
by the controller. Six table shapes over 366 days and seven rainfall boundaries
produce 15372 bitwise pulse comparisons per optimization; invalid consumed inputs,
ignored tails, input nonmutation and active-prefix identity are also checked.

The physical fixture uses authentic unchanged Andelst weather, real Full Richards
and the existing BASE/AIR application owner. The same executable consumes either
one populated legacy pair followed by a descending zero sentinel, or its existing
typed equivalent. O0/O2, continuous versus restored execution, pulse/off, next-day
progress, failed internal accepted prefix without outer publication, retry and
unchanged hard mass assertions pass. It produces identical full physical vectors
for all four representation/continuation combinations per optimization. Existing
fixture stubs establish geometry; they do not replace production physics.
The full application closure has 220 production providers plus one existing grid
fixture, with `headcalc`, generated independent source oracles and the real driver
compiled at link time. It is large because the application owns actual accepted
runtime/crop/thermal state, not because the direct table contract needs a solver.
No central dependency tooling or persistent buildcache is added or modified.

The first persisted functional candidate's modular O0/O2 pair took 0.959600 s
cold and 0.245393 s warm in the same Session. Cold: four file compilations and
two links; warm: zero compiler requests and fresh native tests. Build/native/identity
splits and subsequent formatting-check costs are retained in evidence. Integration
compiled providers once per optimization and reused them for all four executions:
442 provider compilations, two links, eight native programs. Wall time 124.278095 s;
provider compile 93.142763 s, final driver/oracle build plus link 12.029148 s,
native plus assertions/IO 5.481679 s. The two final compiler invocations each
also compile the driver, headcalc and seven source-oracle files: 460 Fortran
compilation units in total. Pure link time within those invocations is UNKNOWN.
The controller remainder includes extraction, Python/wrapper and comparison work;
exclusive categories and physics-only runtime are UNKNOWN. These are measurements
on one host, not a portable speed claim. There is no original baseline for this
previously missing legacy-array route; no before/after percentage is claimed.

**Canonical admission remains pending.** The original isolated pilot could not
inherit the changed adapter's exact owning evidence. The subsequently delegated
joint MC-MET01/HY/RT/F-KT successor now binds the three exact production postimages
and complete fresh V3 owning evidence: all original weather, independent demand/ET,
highest normal/OFF and low-air/OFF/ON, heat, F-KT and coupling assertions pass.
The original pilot and superseded V2 capsules remain immutable historical records.
Full current moving preservation now passes on a canonical-first merge before
admission. Current authority and terminal status are in
`docs/science/MC_MET01_LOW_AIR_JOINT_ADMISSION_20261014.md` and
`integration/audits/MC_MET01_LOW_AIR_JOINT_ADMISSION_20261014.json`.
The master owner PR #1072 receives the bounded receipt through this PR/status
record. Its ledger is not edited and full SW431-MET-RAIN1 remains ACTIVE_MIGRATION.
Reproduce with the qualified GNU Fortran 13.3.0 on PATH and fresh output paths:

```bash
python tests/mc-met01/run_raintb_legacy_pilot.py --output /tmp/swap5-raintb-module-new
python tests/mc-met01/run_raintb_legacy_pilot.py --integration --output /tmp/swap5-raintb-integration-new
```

The final persisted formatted module pair measured 0.849988 s cold, 0.225425 s
warm. Four feedback phases, including original smoke and formatting/persistence
checks, are retained with their 16 file compiles, eight links and 16 native calls.
Identical providers were not shared across independent Sessions; warm reuse is
confined to each controlled Session. Integration was built only once per O0/O2.
Initial donor-comment whitespace failure and clean-tree rejection of generated
Python bytecode are retained; only those generated/formatting inputs were repaired.
No native scientific test failed. The unchanged owning verifier rejects the new
production mutation, confirming that module/integration PASS cannot confer admission.

### Fresh incumbent owner composition (2026-10-14 follow-up)

The additional controller `run_raintb_legacy_owner_preservation.py` executes all
original authentic crop/weather neutral, dry and hydraulic cases, plus the
unchanged daily-demand and typed-RAINTB physical drivers. All20 O0/O2 native
programs pass, with exact optimization and continuous/restart output identity.
Their source assertions, native cases, flags and physical/reference data are
retained. Independent daily-demand960 and reference-ET1700 cases also pass O0/O2.
The bounded verifier `verify_raintb_legacy_owner_batch.py` checks current source,
actual flags, complete distinct case coverage and actual raw native log hashes.
Seven partial/duplicate/failed/O2/flags/manifest/compile negatives fail closed.
Its positive claim is expressly OWNER_COMPOSITION_ONLY_FULL_ADMISSION_PENDING.
An initial negative specimen with removed compiler events exposed shifted log
indices; checking coverage before logs repaired that verifier control, without
changing production, native output or scientific assertions.

One controlled build compiles221 providers, eight external/oracle files and three
drivers once per optimization, then links each driver separately and executes
all cases. Total464 compilation units, six links,20 native runs. Measured wall:
172.939391s; compile140.990688s; pure link0.573521s; native29.891388s. Exact original
three-shell compile plans would request1380 units;916 duplicate units are avoided.
This count comparison is derived from existing plans, not a measured independent
elapsed-time baseline. No timing speedup percentage is claimed. Different direct
source-oracle flags remain separate, with their1.052254s/0.478168s controller times
and unknown internal compilation/native split explicitly retained.

The new evidence capsule is separate from the original immutable pilot capsule:
`MC_MET01_LEGACY_RAINTB_OWNER_PRESERVATION_20261014.tar.xz.b64`. Its1025 selected
members roundtrip verify; exact SHA256, commands, source/compiler/artifact hashes,
raw native/compiler/negative logs, donor/fixture identities, measurements and
verified tested-code bundle are bound in the existing work-unit record.

LOW-AIR-10X is now published and was reconciled at `fea92beda1c544aecbd27851d7a563a558aef027`.
Its full highest same-host A/B is active; remaining O0/owning/preservation/admission
are not qualified. Its two numerical runtime edits do not overlap this pilot's
production adapter. Both branches update `tests/modularity/run_modular_tests.py`;
a retained clean three-way syntax-only prototype preserves the RAINTB and both
LOW-AIR registrations. It is not applied and is not scientific qualification.
No numerical candidate or active A/B result is borrowed into this PR.

The remaining explicit boundaries are the exact adapter successor authority,
complete affected highest frost and Full Richards/PPA/F-CI preservation, and
stable combined numerical-owner reconciliation. The completed targeted owner
batch strengthens the evidence but does not retire any of those mandatory gates.
Keep PR #1225 draft until they are completed; full SWRAIN1 remains ACTIVE.

```bash
python tests/mc-met01/run_raintb_legacy_owner_preservation.py --output /tmp/raintb-owner-new
python tests/mc-met01/verify_raintb_legacy_owner_batch.py /tmp/raintb-owner-new --negative-controls
```

### Proposed exact source-eligibility successor

`verify_raintb_legacy_source_eligibility.py` is an independently runnable proposed
source predicate. It does not replace the incumbent admission guard. The exact
baseline adapter `44b07cd1046632a38b36e9b1ed5608f67ca41fdd` may advance only to
`8ea1c1551c185112ad3f84db598eff8b823e0aeb`. Removing the exact added constructor
and its single public declaration reproduces every baseline adapter byte.
All other production files and the complete reference tree must remain unchanged;
dirty science/reference or any additional production mutation rejects.

The predicate verifies both sealed pilot/owner capsule hashes and every selected
raw member, current direct/owner source dependencies, four direct cold/warm O0/O2
results, eight real physical representation/continuation results and all20 native
owner cases with actual logs/flags. Seven negative checks reject unknown preimage,
unknown postimage, incumbent arithmetic change, prefix-law change, additional
runtime/solver mutation, changed references and corrupted evidence. Its claim is
PROPOSED_EXACT_SOURCE_ELIGIBLE_NOT_ADMITTED. No test or guard is weakened.

The concrete admission proposal is to adopt this precise predicate under the
existing MC-MET01/RT successor authority only after the required full preservation
and stable parallel numerical-owner reconciliation. There is no source wildcard,
no automatic allowance of the active LOW-AIR runtime edits and no new central
runner/dependency register. The current daily-demand/F-CI source guard remains
fail-closed on this candidate until its owning successor is actually adopted.
Neither this source proof nor earlier targeted owner PASS replaces complete
highest-frost/PPA/Full Richards/F-CI qualification.

```bash
python tests/mc-met01/verify_raintb_legacy_source_eligibility.py --negative-controls --output /tmp/raintb-source-proof.json
```
